// 画像引导渲染器（Phase 6.5 数据驱动化）：题目/分层/剪枝反馈全部来自
// L7 onboarding.json + ProfileEngine——本文件只负责渲染与答案收集。
// 原则（ADR-009）：引导即剪枝、未答不剪、先粗后细；required 5 题不可跳过。
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
  });

  final VoidCallback? onComplete;

  /// 「我的-画像」补全入口：true 时完成即返回（而非替换首页路由）。
  final bool isReconfiguring;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  UserProfile _draft = const UserProfile();
  final Set<String> _answered = {};
  List<OnboardingLayer>? _layers;
  int _page = 0;

  AppStore get _store => storeOf(context);
  ProfileEngine get _engine => _store.profileEngine;

  @override
  void initState() {
    super.initState();
    OnboardingConfig.load().then((c) {
      if (mounted) setState(() => _layers = [for (final l in c.layers) l]);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _layerCount => _layers?.length ?? 0;
  int get _lastIndex => _layerCount - 1;

  void _applyOption(OnboardingQuestion q, OnboardingOption o) {
    HapticFeedback.selectionClick();
    setState(() {
      _answered.add(q.id);
      if (q.kind == 'single_choice') {
        // 单选：先撤销该题此前选项的影响（重答场景），再应用新选项
        for (final prev in q.options) {
          if (prev.value == o.value) continue;
          final reverted = _revert(_draft, prev.profilePatch);
          if (reverted != null) _draft = reverted;
        }
      }
      final patched = _engine.applyPatch(_draft, o.profilePatch);
      if (patched != null) _draft = patched;
    });
  }

  bool _isOptionActive(OnboardingQuestion q, OnboardingOption o) {
    // 以 patch 反推选中态：选项的全部字段效果均已体现在 draft
    return _patchApplied(_draft, o.profilePatch);
  }

  bool _patchApplied(UserProfile p, Map<String, dynamic> patch) {
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

  /// 单选重答的反向撤销（null=无可撤销）。
  UserProfile? _revert(UserProfile p, Map<String, dynamic> patch) {
    var reverted = false;
    var n = p;
    for (final e in patch.entries) {
      final key = e.key.endsWith('+') ? e.key.substring(0, e.key.length - 1) : e.key;
      if (key == 'roles+' || key == 'livingConditions+' || key == 'healthConcerns+') {
        final v = e.value as String;
        if (key == 'roles+' && n.roles.contains(v)) {
          n = n.copyWith(roles: n.roles.where((x) => x != v).toList());
          reverted = true;
        }
        if (key == 'livingConditions+' && n.livingConditions.contains(v)) {
          n = n.copyWith(
            livingConditions: n.livingConditions.where((x) => x != v).toList(),
          );
          reverted = true;
        }
        if (key == 'healthConcerns+' && n.healthConcerns.contains(v)) {
          n = n.copyWith(
            healthConcerns: n.healthConcerns.where((x) => x != v).toList(),
          );
          reverted = true;
        }
      }
    }
    return reverted ? n : null;
  }

  bool get _allRequiredAnswered {
    for (final q in _engine.onboarding.questions) {
      if (q.required && !_answered.contains(q.id)) return false;
    }
    return true;
  }

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
    } else if (_allRequiredAnswered) {
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

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    if (_layers == null) {
      return Scaffold(
        backgroundColor: p.canvas,
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final config = _engine.onboarding;
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
                itemBuilder: (context, i) =>
                    _layerPage(context, p, config, _layers![i]),
              ),
            ),
            _footer(p, config),
          ],
        ),
      ),
    );
  }

  // ── 顶部：进度 + 实时聚焦反馈 ──

  Widget _header(AppPalettes p, OnboardingConfig config) {
    final state = _engine.onboardingState(_draft, _answered);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '画像引导 · ${_layers![_page].title}',
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
          Text(
            '已为你聚焦 ${state.activeCount}/${state.totalCount} 条建议'
            '（随时可跳过，未答不影响推荐）',
            style: TextStyle(fontSize: 11.5, color: p.action),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: (_page + 1) / _layerCount,
              minHeight: 3,
              backgroundColor: p.pillBg,
              valueColor: AlwaysStoppedAnimation(p.action),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final qid in layer.questions)
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
                Text('必答', style: TextStyle(fontSize: 10, color: p.rose))
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
            if (o.note != null && _isOptionActive(q, o))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  o.note!,
                  style: TextStyle(fontSize: 10.5, color: p.inkMute),
                ),
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
      child: Container(
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
            onChanged: (v) {
              setState(() {
                _draft = _draft.copyWith(age: v.round());
                _answered.add('birth_year');
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _heightWeightSliders(AppPalettes p) {
    final h = _draft.heightCm ?? 170;
    final w = _draft.weightKg ?? 65;
    void write() => _answered.add('height_weight');
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
                  _draft = _draft.copyWith(heightCm: v);
                  write();
                }),
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
                  _draft = _draft.copyWith(weightKg: v);
                  write();
                }),
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
    final canFinish = _allRequiredAnswered;
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
            onTap: isLast && !canFinish ? null : _nextPage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isLast && !canFinish ? p.pillBg : p.action,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                isLast ? (canFinish ? '完成并开启' : '完成必答题后开启') : '下一步',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isLast && !canFinish ? p.inkMute : p.canvas,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
