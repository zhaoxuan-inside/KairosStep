// 画像引导渲染器（Phase 6.5 数据驱动化）：题目/分层/剪枝反馈全部来自
// L7 onboarding.json + ProfileEngine——本文件只负责渲染与答案收集。
// 原则（ADR-009）：引导即剪枝、未答不剪、先粗后细；required 题仅作重点引导，
// 不拦截完成——任何时刻都能开启，绝不阻止用户使用（未答的题不参与剪枝）。
//
// 状态机制（Phase 8 重写）：答案只存「选择态」（题目 → 已选选项值 + 滑块合成
// patch），草稿画像一律由选择态按题目顺序重放（replay）得出——重答/取消即改
// 选择态，展示选中态直接读选择态。不再从画像反推选中态，杜绝重答残留与
// 空 patch 选项（无/与家人同住/以上都不是）永久高亮的展示错位。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../domain/profile_engine.dart';
import '../../models/advice.dart';
import '../../models/user.dart';
import '../../models/topic_tree.dart';
import '../../state/app_store.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    this.onComplete,
    this.isReconfiguring = false,
    this.initialProfile,
  });

  final VoidCallback? onComplete;

  /// 「我的-画像」补全入口：true 时完成即返回（而非替换首页路由）。
  final bool isReconfiguring;

  /// 起始画像（重配置入口传当前画像，选择态由此推断；null = 全新引导从默认画像起步）。
  final UserProfile? initialProfile;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

/// 引导三段：隐私告知 → 卡牌流问答（一次一屏一题）→ 成形完成。
enum _OnbStage { privacy, cards, deep }

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  final Set<String> _answered = {};

  // ── 选择态（唯一事实源）：qid → 已选选项 value（保序）──
  final Map<String, Set<String>> _selected = {};

  // ── 滑块题合成 patch（birth_year/height_weight 无选项，滑块值落在这里）──
  final Map<String, Map<String, dynamic>> _sliderPatches = {};

  // ── 预编译缓存（build 路径零引擎调用）──
  // 问题树按父答案动态展开；根节点先行，分支内保持配置顺序。
  // _state：activeCount/candidates 等仅在离散作答时经 _recompute 重算。
  OnboardingState? _state;

  UserProfile _draft = ProfileEngine.onboardingBaseline;
  int _page = 0;

  // 首次进入的隐私告知页（不联网 / 仅本地 / 卸载即除）；重配置入口不再展示。
  // 隐私告知 ↔ 卡牌流问答（一次一屏一题）↔ 成形完成：三段状态机。
  _OnbStage _stage = _OnbStage.privacy;
  int _cardIdx = 0; // 卡牌流当前题下标（== 题目数时为成形摘要）
  int _cardDir = 1; // 切换方向：1 前进 / -1 后退

  @override
  void initState() {
    super.initState();
    if (widget.isReconfiguring) _stage = _OnbStage.deep;
  }

  AppStore get _store => storeOf(context);
  ProfileEngine get _engine => _store.profileEngine;

  // 分层配置直接取自目录内已解析的 L7 onboarding（Catalog.load 装配时已就绪），
  // 不再在 initState 二次 rootBundle 异步解析——启动少一次重复解码，
  // 测试环境的 FakeAsync 区也无需等待异步资产。
  OnboardingConfig get _config => _engine.onboarding;
  List<OnboardingLayer> get _layers => _config.layers;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 由既有画像推断初始选择态（重配置入口）：选项 patch 的全部效果均已体现在
  /// 画像中即视为已选；单选取首个命中，多选取全部命中。
  void _inferSelections(UserProfile p) {
    if (p.heightCm != null && p.weightKg != null) {
      _sliderPatches['height_weight'] = {
        'heightCm': p.heightCm,
        'weightKg': p.weightKg,
      };
    }
    _selected.addAll({
      for (final e in p.onboardingAnswers.entries) e.key: e.value.toSet(),
    });
    // Migrate old profiles by positive facts only; defaults are not evidence of
    // an explicitly answered macro question.
    _selected.putIfAbsent(
      'family_context',
      () => {
        if (p.relationshipStatus != 'single') 'partner',
        if (p.hasChildren) 'children',
        if (p.hasAgingParents) 'elderly',
        if (p.healthConcerns.contains('残疾照护') || p.roles.contains('残障人士'))
          'disability',
        if (p.hasPets) 'pets',
      },
    );
    _selected.putIfAbsent(
      'health_context',
      () => {
        if (p.hasHypertension ||
            p.hasDiabetes ||
            p.hasGout ||
            p.hasKidneyStones ||
            p.hasCrisisOrMentalStress)
          'chronic',
        if (p.medications.isNotEmpty) 'medications',
        if (p.hasWeightLossGoal || p.heightCm != null || p.weightKg != null)
          'weight',
        if (p.hasGastroAcidOrStomach) 'digestive',
        if (p.hasFrequentPainOrAnalgesic) 'pain',
      },
    );
    if (p.focusTopics.isNotEmpty) {
      _selected['focus_topics'] = p.focusTopics.toSet();
      _sliderPatches['focus_topics'] = {'focusTopics': p.focusTopics};
    }
    for (final q in _engine.onboarding.questions) {
      if (_selected[q.id]?.isNotEmpty == true) continue;
      final hits = [
        for (final o in q.options)
          if (o.profilePatch.isNotEmpty && _matchesProfile(p, o.profilePatch))
            o.value,
      ];
      if (hits.isEmpty) continue;
      _selected[q.id] = q.kind == 'multi_choice'
          ? Set<String>.from(hits)
          : {hits.first};
    }
  }

  /// 选项 patch 是否已完整生效于画像（仅用于初始选择态推断）。
  static bool _matchesProfile(UserProfile p, Map<String, dynamic> patch) {
    for (final e in patch.entries) {
      final append = e.key.endsWith('+');
      final remove = e.key.endsWith('-');
      final key = append || remove
          ? e.key.substring(0, e.key.length - 1)
          : e.key;
      final list = switch (key) {
        'roles' => p.roles,
        'livingConditions' => p.livingConditions,
        'healthConcerns' => p.healthConcerns,
        'focusDomains' => p.focusDomains,
        'focusTopics' => p.focusTopics,
        'medications' => p.medications,
        _ => null,
      };
      if (list != null) {
        final expected = (e.value as List).cast<String>();
        if (remove
            ? expected.any(list.contains)
            : !expected.every(list.contains)) {
          return false;
        }
        if (!append && !remove && list.length != expected.length) return false;
        continue;
      }
      switch (key) {
        case 'gender':
          if (p.gender != e.value) return false;
        case 'relationshipStatus':
          if (p.relationshipStatus != e.value) return false;
        case 'childAgeStage':
          if (p.childAgeStage != e.value) return false;
        default:
          if (e.value is bool) {
            final current = switch (key) {
              'hasChildren' => p.hasChildren,
              'hasAgingParents' => p.hasAgingParents,
              'hasPets' => p.hasPets,
              'hasPipedGas' => p.hasPipedGas,
              'hasMortgage' => p.hasMortgage,
              'isTenant' => p.isTenant,
              'hasCar' => p.hasCar,
              'hasTwowheeler' => p.hasTwowheeler,
              'isSmoker' => p.isSmoker,
              'isProgrammer' => p.isProgrammer,
              'isEntrepreneur' => p.isEntrepreneur,
              'hasAbroadTravelOrStudy' => p.hasAbroadTravelOrStudy,
              'hasWeightLossGoal' => p.hasWeightLossGoal,
              'hasGastroAcidOrStomach' => p.hasGastroAcidOrStomach,
              'hasFrequentPainOrAnalgesic' => p.hasFrequentPainOrAnalgesic,
              'hasHypertension' => p.hasHypertension,
              'hasDiabetes' => p.hasDiabetes,
              'hasKidneyStones' => p.hasKidneyStones,
              'hasGout' => p.hasGout,
              'hasCrisisOrMentalStress' => p.hasCrisisOrMentalStress,
              'livingAlone' => p.livingAlone,
              _ => null,
            };
            if (current != e.value) return false;
          }
      }
    }
    return true;
  }

  /// 由选择态重放草稿画像（重答/取消即改选择态，无残留）。
  UserProfile _computeDraft() => _engine.replayDraft(
    _selected,
    base: widget.initialProfile ?? ProfileEngine.onboardingBaseline,
    sliderPatches: _sliderPatches,
  );

  /// 重算引导状态（离散作答时调用；build 内首次惰性触发）。
  /// 编译门禁下全量重算为纯字段判定（亚毫秒级）。
  void _recompute() {
    final visible = _config
        .visibleQuestions(_selected)
        .map((q) => q.id)
        .toSet();
    _selected.removeWhere((id, _) => !visible.contains(id));
    _sliderPatches.removeWhere((id, _) => !visible.contains(id));
    _answered.removeWhere((id) => !visible.contains(id));
    _draft = _computeDraft();
    _state = _engine.onboardingState(_draft, _answered);
  }

  bool _emptyPatchOption(OnboardingQuestion q, String value) {
    for (final o in q.options) {
      if (o.value == value) return o.exclusive;
    }
    return false;
  }

  void _applyOption(OnboardingQuestion q, OnboardingOption o) {
    HapticFeedback.selectionClick();
    setState(() {
      final selected = _selected.putIfAbsent(q.id, () => <String>{});
      if (q.kind == 'multi_choice') {
        if (selected.contains(o.value)) {
          // 再点取消（「无」这类空 patch 独占项不参与取消）
          if (!o.exclusive) selected.remove(o.value);
        } else if (o.exclusive) {
          // 「无」独占：清除本题其他选择
          selected
            ..clear()
            ..add(o.value);
        } else {
          selected
            ..removeWhere((v) => _emptyPatchOption(q, v))
            ..add(o.value);
        }
      } else {
        // 单选：整题替换（重答即撤销旧选项全部影响，无残留）
        selected
          ..clear()
          ..add(o.value);
      }
      if (selected.isEmpty) {
        for (final option in q.options) {
          if (option.exclusive && option.value == 'none') {
            selected.add(option.value);
            break;
          }
        }
      }
      _answered.add(q.id);
      _recompute();
    });
  }

  bool _isOptionActive(OnboardingQuestion q, OnboardingOption o) =>
      _selected[q.id]?.contains(o.value) ?? false;

  void _complete() {
    HapticFeedback.heavyImpact();
    _store.completeOnboarding(_draft);
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_page < _lastIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      // 任何时刻都允许完成：未答的题目不参与剪枝（未答不剪，ADR-009），
      // 必答校验只会把用户挡在门外，与「不阻止使用」原则冲突。
      _complete();
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int get _layerCount => _layers.length;
  int get _lastIndex => _layerCount - 1;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final config = _config;
    if (_state == null) {
      // 首帧：重配置入口推断初始选择态 + 冻结题序 + 初次计算（此后仅离散作答重算）
      if (widget.initialProfile != null) {
        _inferSelections(widget.initialProfile!);
        _draft = widget.initialProfile!;
      }
      _recompute();
    }
    // 隐私告知 ↔ 引导主体：淡入 + 轻微上移过渡，替代生硬的整页跳切
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: switch (_stage) {
        _OnbStage.privacy when !widget.isReconfiguring => KeyedSubtree(
          key: const ValueKey('privacy-intro'),
          child: _privacyIntro(p),
        ),
        _OnbStage.cards => KeyedSubtree(
          key: const ValueKey('question-cards'),
          child: _cardFlowScreen(p, config),
        ),
        _ => KeyedSubtree(
          key: const ValueKey('onboarding-body'),
          child: _onboardingScaffold(p, config),
        ),
      },
    );
  }

  Widget _onboardingScaffold(AppPalettes p, OnboardingConfig config) {
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _header(p, config),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _layerCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) {
                    // 视差 + 边缘渐隐：页内容随滑动错位滑行并淡入淡出，
                    // 弱化默认逐像素硬平移的机械感
                    final page = _pageController.hasClients
                        ? (_pageController.page ?? _page.toDouble())
                        : _page.toDouble();
                    final delta = (page - i).clamp(-1.0, 1.0).toDouble();
                    return Opacity(
                      opacity: (1.0 - delta.abs() * 0.4).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(delta * 32, 0),
                        child: _layerPage(context, p, config, _layers[i]),
                      ),
                    );
                  },
                ),
              ),
            ),
            _footer(p, config),
          ],
        ),
      ),
    );
  }

  // ── 首次进入前的隐私告知：不联网 / 仅本地 / 卸载即除 ──

  Widget _privacyIntro(AppPalettes p) {
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.action.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 30,
                  color: p.action,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '在开始之前',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '你的时光，只属于你。\n'
                '从这里开始的一切——\n'
                '画像、待办与每一次打卡，\n'
                '都不会走向云端。\n'
                '这是一座不联网的岛屿：\n'
                '没有上传，没有同步，也没有旁观者；\n'
                '所有数据只安放于这台设备，\n'
                '与你朝夕相处。\n'
                '哪怕某天卸载而去，它们也悄然离席——\n'
                '不留痕迹，不必告别。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.9, color: p.inkSub),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  children: [
                    _promiseRow(
                      p,
                      Icons.wifi_off_rounded,
                      '永不联网',
                      '无任何网络请求与云端同步',
                    ),
                    const SizedBox(height: 10),
                    _promiseRow(
                      p,
                      Icons.phone_iphone_rounded,
                      '仅存本地',
                      '数据不出这台设备',
                    ),
                    const SizedBox(height: 10),
                    _promiseRow(
                      p,
                      Icons.auto_delete_rounded,
                      '卸载即除',
                      '随应用删除，不留痕迹',
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.action,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _stage = _OnbStage.cards);
                  },
                  child: const Text(
                    '安心开启',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promiseRow(
    AppPalettes p,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: p.emerald),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: p.ink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, color: p.inkMute),
          ),
        ),
      ],
    );
  }

  // ── 卡牌流：借鉴《八十亿分之一》的逐张揭示——一次一屏一题，
  // 大字排版 + 方向感切换 + 实时聚焦反馈；跳过即未答不剪。──

  List<OnboardingQuestion> _flowQuestions(OnboardingConfig config) => [
    for (final q in config.visibleQuestions(_selected))
      if (q.id != 'focus_domains') q,
  ];

  void _advanceCard(int from) {
    if (!mounted || _stage != _OnbStage.cards || _cardIdx != from) return;
    setState(() {
      _cardDir = 1;
      _cardIdx += 1;
    });
  }

  Widget _cardFlowScreen(AppPalettes p, OnboardingConfig config) {
    final questions = _flowQuestions(config);
    final done = _cardIdx >= questions.length;
    final q = done ? null : questions[_cardIdx];
    final answered = q != null && _answered.contains(q.id);
    final layerTitle = done
        ? ''
        : config.layers
              .firstWhere(
                (l) => l.key == q!.layer,
                orElse: () => config.layers.first,
              )
              .title;
    final single =
        q != null && q.kind != 'multi_choice' && q.kind != 'topic_picker';

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        done
                            ? '画像已成形'
                            : '第 ${_cardIdx + 1}/${questions.length} 题',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: done ? p.done : p.inkMute,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!done)
                        Text(
                          layerTitle,
                          style: TextStyle(fontSize: 11, color: p.amber),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _cardIdx / questions.length),
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 3,
                        backgroundColor: p.pillBg,
                        valueColor: AlwaysStoppedAnimation(p.action),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.bolt, size: 13, color: p.action),
                      const SizedBox(width: 5),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Text(
                          '已为你聚焦 ${_state!.activeCount}/${_state!.totalCount} 条建议'
                          '（随时可跳过，未答不影响推荐）',
                          key: ValueKey(_state!.activeCount),
                          style: TextStyle(fontSize: 11.5, color: p.action),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(_cardIdx);
                  return ClipRect(
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: Offset(
                              _cardDir * (incoming ? 0.08 : -0.08),
                              0,
                            ),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: incoming
                                  ? Curves.easeOutCubic
                                  : Curves.easeIn,
                            ),
                          ),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_cardIdx),
                  child: done
                      ? SingleChildScrollView(child: _cardSummary(p, config))
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: _questionStage(p, q!, single),
                          ),
                        ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    if (_cardIdx > 0)
                      TextButton(
                        onPressed: () => setState(() {
                          _cardDir = -1;
                          _cardIdx -= 1;
                        }),
                        child: Text(
                          '上一步',
                          style: TextStyle(fontSize: 13, color: p.inkMute),
                        ),
                      ),
                    const Spacer(),
                    if (!done && !answered)
                      TextButton(
                        onPressed: () => setState(() {
                          _cardDir = 1;
                          _cardIdx += 1;
                        }),
                        child: Text(
                          '跳过此题',
                          style: TextStyle(fontSize: 12.5, color: p.inkMute),
                        ),
                      ),
                    if (!done && !single)
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: p.action,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                          ),
                          onPressed: () => setState(() {
                            _cardDir = 1;
                            _cardIdx += 1;
                          }),
                          child: const Text(
                            '下一题',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionStage(AppPalettes p, OnboardingQuestion q, bool single) {
    final idx = _cardIdx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (q.parentId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '细分：${_config.questions.firstWhere((parent) => parent.id == q.parentId).prompt}',
              style: TextStyle(fontSize: 12, color: p.inkSub),
            ),
          ),
        Text(
          q.prompt,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 22),
        if (q.options.isNotEmpty)
          for (final o in q.options)
            _bigOption(
              p,
              q,
              o,
              selected: _isOptionActive(q, o),
              single: single,
              idx: idx,
            )
        else if (q.id == 'birth_year')
          _ageSlider(p)
        else if (q.id == 'height_weight')
          _heightWeightSliders(p)
        else if (q.kind == 'topic_picker')
          _topicChoices(),
        if (q.id == 'birth_year' || q.id == 'height_weight')
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: p.action,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => setState(() {
                  _cardDir = 1;
                  _cardIdx += 1;
                }),
                child: const Text(
                  '下一题',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _topicChoices() {
    final catalog = catalogOf(context);
    final chosen = _selected['focus_topics'] ?? <String>{};
    final counts = catalog.topics.countsFor(catalog.adviceList);

    void update(Set<String> paths) {
      setState(() {
        _selected['focus_topics'] = paths;
        _sliderPatches['focus_topics'] = {'focusTopics': paths.toList()};
        _answered.add('focus_topics');
        _recompute();
      });
    }

    Iterable<TopicNode> leaves(TopicNode node) sync* {
      if (node.children.isEmpty) {
        yield node;
      } else {
        for (final child in node.children) {
          yield* leaves(child);
        }
      }
    }

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '展开领域选择具体主题。数量为全库主题覆盖，可能交叉；实际推荐仍受年龄、健康与角色条件限制。未选择则不限定主题，全量指南始终可查。',
          ),
          TextButton(
            onPressed: () => update({}),
            child: Text(chosen.isEmpty ? '暂不限定主题' : '清空 ${chosen.length} 项选择'),
          ),
          for (final root in catalog.topics.roots)
            ExpansionTile(
              key: ValueKey('onboarding-topics-${root.path}'),
              title: Text(root.name),
              subtitle: Text(
                '${counts[root.path] ?? 0} 条建议 · 已选 ${chosen.where((p) => TopicNode.containsPath(root.path, p)).length} 项',
              ),
              children: [
                for (final leaf in leaves(root))
                  if ((counts[leaf.path] ?? 0) > 0)
                    CheckboxListTile(
                      key: ValueKey('onboarding-topic-${leaf.path}'),
                      title: Text(leaf.name),
                      subtitle: Text('${counts[leaf.path]} 条建议'),
                      value: chosen.contains(leaf.path),
                      onChanged: (value) {
                        final next = {...chosen};
                        value == true
                            ? next.add(leaf.path)
                            : next.remove(leaf.path);
                        update(next);
                      },
                    ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _bigOption(
    AppPalettes p,
    OnboardingQuestion q,
    OnboardingOption o, {
    required bool selected,
    required bool single,
    required int idx,
  }) {
    return GestureDetector(
      onTap: () {
        _applyOption(q, o);
        if (single) {
          Future.delayed(
            const Duration(milliseconds: 420),
            () => _advanceCard(idx),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? p.action.withValues(alpha: 0.1) : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? p.action : p.hairline,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                o.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? p.action : p.ink,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: p.action),
          ],
        ),
      ),
    );
  }

  Widget _cardSummary(AppPalettes p, OnboardingConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_rounded, size: 44, color: p.done),
        const SizedBox(height: 14),
        Text(
          '画像已成形',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '已确认 ${_answered.length}/${_flowQuestions(config).length} 项 · '
          '未答项不参与剪枝（未答不剪），随时可回看修改',
          style: TextStyle(fontSize: 12.5, height: 1.5, color: p.inkSub),
        ),
        const SizedBox(height: 24),
        Text(
          _draft.focusTopics.isEmpty
              ? '具体主题：暂不限定'
              : '已选择 ${_draft.focusTopics.length} 个具体主题，可在画像中随时修改',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.action,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _complete();
            },
            child: const Text(
              '以此配置直接开启',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
  // ── 顶部：进度 + 实时聚焦反馈 ──

  Widget _header(AppPalettes p, OnboardingConfig config) {
    final state = _state!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '画像引导 · ${_layers[_page].title}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${_page + 1}/$_layerCount',
                style: TextStyle(fontSize: 12, color: p.inkMute),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('已为你聚焦 ', style: TextStyle(fontSize: 11.5, color: p.action)),
              // 聚焦计数变化时淡入上滑，避免数字跳变
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  '${state.activeCount}/${state.totalCount}',
                  key: ValueKey('${state.activeCount}/${state.totalCount}'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.action,
                  ),
                ),
              ),
              Text(
                ' 条建议（随时可跳过，未答不影响推荐）',
                style: TextStyle(fontSize: 11.5, color: p.action),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            // 进度变化时平滑生长，而非跳到新位置
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_page + 1) / _layerCount),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: p.pillBg,
                valueColor: AlwaysStoppedAnimation(p.action),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 层页面：该层全部题目纵向排布 ──

  Widget _layerPage(
    BuildContext context,
    AppPalettes p,
    OnboardingConfig config,
    OnboardingLayer layer,
  ) {
    final byId = {for (final q in config.questions) q.id: q};
    final visible = config.visibleQuestions(_selected).map((q) => q.id).toSet();
    // 题序严格按配置的层内固定顺序渲染：作答不改变位次（引擎只负责聚焦
    // 计数与下一题建议，不再驱动卡片重排——作答后内容跳位被用户否决）。
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final qid in layer.questions)
          if (visible.contains(qid))
            if (byId[qid] case final q?) _questionCard(p, config, q),
      ],
    );
  }

  Widget _questionCard(
    AppPalettes p,
    OnboardingConfig config,
    OnboardingQuestion q,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  q.prompt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              // 仅保留「建议作答」提醒；「可跳过」角标按产品要求删除
              if (q.required)
                Text('建议作答', style: TextStyle(fontSize: 10, color: p.amber)),
            ],
          ),
          if (q.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in q.options)
                  _optionPill(p, q, o, _isOptionActive(q, o)),
              ],
            ),
          ],
          if (q.kind == 'topic_picker') _topicChoices(),
          if (q.id == 'birth_year') ...[
            const SizedBox(height: 8),
            _ageSlider(p),
          ],
          if (q.id == 'height_weight') ...[
            const SizedBox(height: 8),
            _heightWeightSliders(p),
          ],
          for (final o in q.options)
            if (o.note != null)
              // 选中注释平滑展开/收起，而非突然出现或消失
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topLeft,
                child: _isOptionActive(q, o)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          o.note!,
                          style: TextStyle(fontSize: 10.5, color: p.inkMute),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
        ],
      ),
    );
  }

  Widget _optionPill(
    AppPalettes p,
    OnboardingQuestion q,
    OnboardingOption o,
    bool active,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () => _applyOption(q, o),
      // 选中态底色/描边 200ms 过渡，避免瞬时变色
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? p.action : p.pillBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: active ? p.action : p.hairline, width: 1.2),
        ),
        child: Text(
          o.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? p.canvas : p.ink,
          ),
        ),
      ),
    );
  }

  Widget _ageSlider(AppPalettes p) {
    return Row(
      children: [
        Text('年龄 ${_draft.age}', style: TextStyle(fontSize: 12, color: p.ink)),
        Expanded(
          child: Slider(
            value: _draft.age.toDouble(),
            min: 14,
            max: 90,
            divisions: 76,
            activeColor: p.action,
            label: '${_draft.age}',
            // 拖动中只更新数值显示与合成 patch；松手才重算剪枝视图
            onChanged: (v) => setState(() {
              _sliderPatches['birth_year'] = {'age': v.round()};
              _draft = _draft.copyWith(age: v.round());
              _answered.add('birth_year');
            }),
            onChangeEnd: (v) => setState(_recompute),
          ),
        ),
      ],
    );
  }

  Widget _heightWeightSliders(AppPalettes p) {
    final h = _draft.heightCm ?? 170;
    final w = _draft.weightKg ?? 65;
    return Column(
      children: [
        Row(
          children: [
            Text(
              '身高 ${h.round()}cm',
              style: TextStyle(fontSize: 12, color: p.ink),
            ),
            Expanded(
              child: Slider(
                value: h,
                min: 140,
                max: 210,
                divisions: 70,
                activeColor: p.action,
                label: '${h.round()}',
                onChanged: (v) => setState(() {
                  _sliderPatches['height_weight'] = {
                    'heightCm': v,
                    'weightKg': _draft.weightKg ?? 65,
                  };
                  _draft = _draft.copyWith(heightCm: v);
                  _answered.add('height_weight');
                }),
                onChangeEnd: (v) => setState(_recompute),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              '体重 ${w.round()}kg',
              style: TextStyle(fontSize: 12, color: p.ink),
            ),
            Expanded(
              child: Slider(
                value: w,
                min: 35,
                max: 150,
                divisions: 115,
                activeColor: p.action,
                label: '${w.round()}',
                onChanged: (v) => setState(() {
                  _sliderPatches['height_weight'] = {
                    'heightCm': _draft.heightCm ?? 170,
                    'weightKg': v,
                  };
                  _draft = _draft.copyWith(weightKg: v);
                  _answered.add('height_weight');
                }),
                onChangeEnd: (v) => setState(_recompute),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 底部：上一步/下一步（完成） ──

  Widget _footer(AppPalettes p, OnboardingConfig config) {
    final isLast = _page == _lastIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (_page > 0)
            TextButton(
              onPressed: _prevPage,
              child: Text(
                '上一步',
                style: TextStyle(fontSize: 13, color: p.inkMute),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _complete, // 随时可以此配置直接开启（未答不剪）
            child: Text(
              '以此配置直接开启',
              style: TextStyle(fontSize: 12, color: p.inkMute),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: _nextPage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: p.action,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                isLast ? '完成并开启' : '下一步',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.canvas,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
