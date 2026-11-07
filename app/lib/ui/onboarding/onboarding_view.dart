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

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  final Set<String> _answered = {};

  // ── 选择态（唯一事实源）：qid → 已选选项 value（保序）──
  final Map<String, Set<String>> _selected = {};

  // ── 滑块题合成 patch（birth_year/height_weight 无选项，滑块值落在这里）──
  final Map<String, Map<String, dynamic>> _sliderPatches = {};

  // ── 预编译缓存（build 路径零引擎调用）──
  // _frozenOrder：进引导时 rankQuestions 算一次定死（主干固定）；
  // _state：activeCount/candidates 等仅在离散作答时经 _recompute 重算。
  OnboardingState? _state;
  List<String>? _frozenOrder;

  UserProfile _draft = ProfileEngine.onboardingBaseline;
  int _page = 0;

  // 首次进入的隐私告知页（不联网 / 仅本地 / 卸载即除）；重配置入口不再展示。
  bool _privacyIntroDone = false;

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
    for (final q in _engine.onboarding.questions) {
      final hits = [
        for (final o in q.options)
          if (o.profilePatch.isNotEmpty && _matchesProfile(p, o.profilePatch)) o.value,
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
      final key = e.key.endsWith('+') ? e.key.substring(0, e.key.length - 1) : e.key;
      switch (key) {
        case 'gender':
          if (p.gender != e.value) return false;
        case 'relationshipStatus':
          if (p.relationshipStatus != e.value) return false;
        case 'childAgeStage':
          if (p.childAgeStage != e.value) return false;
        case 'roles+':
          if (!p.roles.contains(e.value)) return false;
        case 'livingConditions+':
          if (!p.livingConditions.contains(e.value)) return false;
        case 'healthConcerns+':
          if (!p.healthConcerns.contains(e.value)) return false;
        case 'focusDomains+':
          if (!p.focusDomains.contains(e.value)) return false;
        case 'medications+':
          if (!p.medications.contains(e.value)) return false;
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
    _draft = _computeDraft();
    _frozenOrder ??= [
      for (final y in _engine
          .rankQuestions(_draft, _engine.activeAdviceIds(_draft), _answered))
        y.question.id,
    ];
    _state = _engine.onboardingState(_draft, _answered, frozenOrder: _frozenOrder);
  }

  bool _emptyPatchOption(OnboardingQuestion q, String value) {
    for (final o in q.options) {
      if (o.value == value) return o.profilePatch.isEmpty;
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
          if (o.profilePatch.isNotEmpty) selected.remove(o.value);
        } else if (o.profilePatch.isEmpty) {
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
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: !widget.isReconfiguring && !_privacyIntroDone
          ? KeyedSubtree(
              key: const ValueKey('privacy-intro'),
              child: _privacyIntro(p),
            )
          : KeyedSubtree(
              key: const ValueKey('onboarding-body'),
              child: _onboardingScaffold(p, config),
            ),
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
                child: Icon(Icons.verified_user_rounded, size: 30, color: p.action),
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
                '从这里开始的一切——画像、待办与每一次打卡，\n'
                '都不会走向云端。\n'
                '这是一座不联网的岛屿：没有上传，没有同步，也没有旁观者；\n'
                '所有数据只安放于这台设备的方寸之间，与你朝夕相处。\n'
                '哪怕某天卸载而去，它们也会与应用一同悄然离席——\n'
                '不留痕迹，不必告别。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.9, color: p.inkSub),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  children: [
                    _promiseRow(p, Icons.wifi_off_rounded, '永不联网', '无任何网络请求与云端同步'),
                    const SizedBox(height: 10),
                    _promiseRow(p, Icons.phone_iphone_rounded, '仅存本地', '数据不出这台设备'),
                    const SizedBox(height: 10),
                    _promiseRow(p, Icons.auto_delete_rounded, '卸载即除', '随应用删除，不留痕迹'),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _privacyIntroDone = true);
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

  Widget _promiseRow(AppPalettes p, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: p.emerald),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(subtitle, style: TextStyle(fontSize: 11.5, color: p.inkMute)),
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
              Text(
                '已为你聚焦 ',
                style: TextStyle(fontSize: 11.5, color: p.action),
              ),
              // 聚焦计数变化时淡入上滑，避免数字跳变
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(anim),
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
    // 引擎动态出题读缓存（题序进引导时冻结，先粗后细在层内生效）：
    // 未答题按冻结序排前，已答题保持原位在后（展示已选状态）。
    final ranked = [
      for (final y in _state!.candidates)
        if (layer.questions.contains(y.question.id)) y.question.id,
    ];
    final answeredInLayer = [
      for (final qid in layer.questions)
        if (!ranked.contains(qid)) qid,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final qid in [...ranked, ...answeredInLayer])
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
              if (q.required)
                Text('建议作答', style: TextStyle(fontSize: 10, color: p.amber))
              else
                Text('可跳过', style: TextStyle(fontSize: 10, color: p.inkMute)),
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
          border: Border.all(
            color: active ? p.action : p.hairline,
            width: 1.2,
          ),
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
            Text('身高 ${h.round()}cm', style: TextStyle(fontSize: 12, color: p.ink)),
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
            Text('体重 ${w.round()}kg', style: TextStyle(fontSize: 12, color: p.ink)),
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
              child: Text('上一步', style: TextStyle(fontSize: 13, color: p.inkMute)),
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
