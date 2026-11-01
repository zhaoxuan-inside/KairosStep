// 画像引擎（REFACTOR_DESIGN §5.8 / ONBOARDING_DESIGN §4）：引导即剪枝，未答不剪（ADR-009）。
// 判定复用 GatekeeperEngine（不写第二套门禁）；剪枝索引来自 L0 prerequisites + L3 标签 + L7 gates。
// 所有 profilePatch 映射到现有 UserProfile 字段（零迁移、零兼容风险）。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../data/catalog.dart';
import '../models/advice.dart';
import '../models/user.dart';
import 'gatekeeper_engine.dart';

class ProfileEngine {
  ProfileEngine({required this.catalog, required this.gatekeeper, required this.onboarding});

  final Catalog catalog;
  final GatekeeperEngine gatekeeper;
  final OnboardingConfig onboarding;

  UserProfile normalize(UserProfile p) => p.normalized();

  /// 测试可见：patch 应用（真实入口为选项作答）。
  UserProfile? testApplyPatch(UserProfile p, Map<String, dynamic> patch) =>
      _applyPatch(p, patch);

  /// 当前画像下的活跃建议集（引导剪枝视图；主题过滤中性——引导期不做主题剪枝）。
  Set<int> activeAdviceIds(UserProfile p) {
    return {
      for (final a in catalog.adviceList)
        if (gatekeeper.matchPersona(a, profile: p, topicFilter: (_) => true)) a.id,
    };
  }

  /// 问题排序（max-yield 贪心）：收益 = |active| − min_option 存活数。
  /// required 不参与竞争；softOnly（关注域）不剪枝；低于 minMarginalYield 淘汰。
  List<QuestionYield> rankQuestions(
    UserProfile p,
    Set<int> activeSet,
    Set<String> answeredIds,
  ) {
    final out = <QuestionYield>[];
    for (final q in onboarding.questions) {
      if (answeredIds.contains(q.id) || q.required || q.softOnly) continue;
      var minSurvive = activeSet.length;
      for (final o in q.options) {
        final patched = _applyPatch(p, o.profilePatch);
        final survive = patched == null
            ? activeSet.length
            : activeSet.where((id) {
                final a = catalog.adviceById(id);
                return a == null ||
                    gatekeeper.matchPersona(a, profile: patched, topicFilter: (_) => true);
              }).length;
        if (survive < minSurvive) minSurvive = survive;
      }
      final gain = activeSet.length - minSurvive;
      if (gain >= onboarding.pruning.minMarginalYield) {
        out.add(QuestionYield(question: q, yieldCount: gain));
      }
    }
    out.sort((a, b) => b.yieldCount.compareTo(a.yieldCount));
    return out;
  }

  /// 引导状态：required 缺答优先，其次收益榜首；无题可问即完成。
  OnboardingState onboardingState(UserProfile p, Set<String> answeredIds) {
    final active = activeAdviceIds(p);
    final missingRequired = [
      for (final q in onboarding.questions)
        if (q.required && !answeredIds.contains(q.id)) q,
    ];
    final ranked = rankQuestions(p, active, answeredIds);
    final next = missingRequired.isNotEmpty
        ? missingRequired.first
        : (ranked.isEmpty ? null : ranked.first.question);
    return OnboardingState(
      activeCount: active.length,
      totalCount: catalog.adviceList.length,
      answeredIds: answeredIds,
      nextQuestion: next,
      done: next == null,
      candidates: ranked,
    );
  }

  /// 应用 profilePatch（'+' 结尾=列表追加；未知键安全忽略——未答不剪原则下宁可冗余）。
  UserProfile? _applyPatch(UserProfile p, Map<String, dynamic> patch) {
    if (patch.isEmpty) return null;
    var n = p;
    var changed = false;
    void touch() => changed = true;

    for (final e in patch.entries) {
      final key = e.key.endsWith('+') ? e.key.substring(0, e.key.length - 1) : e.key;
      final isAppend = e.key.endsWith('+');
      switch (key) {
        case 'gender' when !isAppend:
          n = n.copyWith(gender: e.value as String);
          touch();
        case 'age' when !isAppend:
          n = n.copyWith(age: (e.value as num).toInt());
          touch();
        case 'heightCm' when !isAppend:
          n = n.copyWith(heightCm: (e.value as num).toDouble());
          touch();
        case 'weightKg' when !isAppend:
          n = n.copyWith(weightKg: (e.value as num).toDouble());
          touch();
        case 'relationshipStatus' when !isAppend:
          n = n.copyWith(relationshipStatus: e.value as String);
          touch();
        case 'childAgeStage' when !isAppend:
          n = n.copyWith(childAgeStage: e.value as String);
          touch();
        case 'roles' when isAppend:
          n = n.copyWith(roles: {...n.roles, ...(e.value as List).cast<String>()}.toList());
          touch();
        case 'livingConditions' when isAppend:
          n = n.copyWith(
            livingConditions: {...n.livingConditions, ...(e.value as List).cast<String>()}.toList(),
          );
          touch();
        case 'healthConcerns' when isAppend:
          n = n.copyWith(
            healthConcerns: {...n.healthConcerns, ...(e.value as List).cast<String>()}.toList(),
          );
          touch();
        case 'focusDomains' when isAppend:
          n = n.copyWith(
            focusDomains: {...n.focusDomains, ...(e.value as List).cast<String>()}.toList(),
          );
          touch();
        case 'medications' when isAppend:
          n = n.copyWith(medications: {
            ...n.medications,
            ...(e.value as List).cast<String>().where((x) => !n.medications.contains(x)),
          }.toList());
          touch();
        case 'medications' when !isAppend:
          n = n.copyWith(medications: (e.value as List).cast<String>());
          touch();
        case 'livingAlone' when !isAppend:
          n = n.copyWith(livingAlone: e.value as bool);
          touch();
        default:
          if (!isAppend && e.value is bool) {
            n = _applyBool(n, key, e.value as bool);
            touch();
          }
      }
    }
    return changed ? n : null;
  }

  UserProfile _applyBool(UserProfile p, String key, bool v) => switch (key) {
    'hasChildren' => p.copyWith(hasChildren: v),
    'hasAgingParents' => p.copyWith(hasAgingParents: v),
    'hasPets' => p.copyWith(hasPets: v),
    'hasPipedGas' => p.copyWith(hasPipedGas: v),
    'hasMortgage' => p.copyWith(hasMortgage: v),
    'isTenant' => p.copyWith(isTenant: v),
    'hasCar' => p.copyWith(hasCar: v),
    'hasTwowheeler' => p.copyWith(hasTwowheeler: v),
    'isSmoker' => p.copyWith(isSmoker: v),
    'isProgrammer' => p.copyWith(isProgrammer: v),
    'isEntrepreneur' => p.copyWith(isEntrepreneur: v),
    'hasAbroadTravelOrStudy' => p.copyWith(hasAbroadTravelOrStudy: v),
    'hasWeightLossGoal' => p.copyWith(hasWeightLossGoal: v),
    'hasGastroAcidOrStomach' => p.copyWith(hasGastroAcidOrStomach: v),
    'hasFrequentPainOrAnalgesic' => p.copyWith(hasFrequentPainOrAnalgesic: v),
    'hasHypertension' => p.copyWith(hasHypertension: v),
    'hasDiabetes' => p.copyWith(hasDiabetes: v),
    'hasKidneyStones' => p.copyWith(hasKidneyStones: v),
    'hasGout' => p.copyWith(hasGout: v),
    'hasCrisisOrMentalStress' => p.copyWith(hasCrisisOrMentalStress: v),
    _ => p,
  };
}

// ── onboarding.json 配置类型 ──

class OnboardingConfig {
  const OnboardingConfig({
    required this.pruning,
    required this.layers,
    required this.questions,
  });

  final OnboardingPruning pruning;
  final List<OnboardingLayer> layers;
  final List<OnboardingQuestion> questions;

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) => OnboardingConfig(
    pruning: OnboardingPruning.fromJson(json['pruning'] as Map<String, dynamic>),
    layers: (json['layers'] as List)
        .map((e) => OnboardingLayer.fromJson(e as Map<String, dynamic>))
        .toList(),
    questions: (json['questions'] as List)
        .map((e) => OnboardingQuestion.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static Future<OnboardingConfig> load() async {
    final raw = await rootBundle.loadString('assets/data/config/onboarding.json');
    return OnboardingConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

class OnboardingPruning {
  const OnboardingPruning({required this.minMarginalYield, required this.maxQuestions});

  final int minMarginalYield;
  final int maxQuestions;

  factory OnboardingPruning.fromJson(Map<String, dynamic> json) => OnboardingPruning(
    minMarginalYield: (json['minMarginalYield'] as num).toInt(),
    maxQuestions: (json['maxQuestions'] as num).toInt(),
  );
}

class OnboardingLayer {
  const OnboardingLayer({
    required this.key,
    required this.title,
    required this.required,
    required this.progressive,
    required this.questions,
  });

  final String key;
  final String title;
  final bool required;
  final bool progressive;
  final List<String> questions;

  factory OnboardingLayer.fromJson(Map<String, dynamic> json) => OnboardingLayer(
    key: json['key'] as String,
    title: json['title'] as String,
    required: json['required'] as bool? ?? false,
    progressive: json['progressive'] as bool? ?? false,
    questions: (json['questions'] as List).cast<String>(),
  );
}

class OnboardingQuestion {
  const OnboardingQuestion({
    required this.id,
    required this.layer,
    required this.required,
    required this.kind,
    required this.prompt,
    required this.skipAllowed,
    required this.softOnly,
    required this.options,
  });

  final String id;
  final String layer;
  final bool required;
  final String kind;
  final String prompt;
  final bool skipAllowed;
  final bool softOnly; // 关注域：影响排序不剪枝
  final List<OnboardingOption> options;

  factory OnboardingQuestion.fromJson(Map<String, dynamic> json) => OnboardingQuestion(
    id: json['id'] as String,
    layer: json['layer'] as String,
    required: json['required'] as bool? ?? false,
    kind: json['kind'] as String? ?? 'single_choice',
    prompt: json['prompt'] as String,
    skipAllowed: json['skipAllowed'] as bool? ?? true,
    softOnly: json['softOnly'] as bool? ?? false,
    options: (json['options'] as List? ?? const [])
        .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class OnboardingOption {
  const OnboardingOption({
    required this.value,
    required this.label,
    required this.profilePatch,
    this.note,
  });

  final String value;
  final String label;
  final Map<String, dynamic> profilePatch;
  final String? note;

  factory OnboardingOption.fromJson(Map<String, dynamic> json) => OnboardingOption(
    value: json['value'] as String,
    label: json['label'] as String,
    profilePatch: (json['profilePatch'] as Map<String, dynamic>?) ?? const {},
    note: json['note'] as String?,
  );
}

class QuestionYield {
  const QuestionYield({required this.question, required this.yieldCount});

  final OnboardingQuestion question;
  final int yieldCount; // 最坏情况剪枝收益（条）
}

class OnboardingState {
  const OnboardingState({
    required this.activeCount,
    required this.totalCount,
    required this.answeredIds,
    required this.nextQuestion,
    required this.done,
    required this.candidates,
  });

  final int activeCount;
  final int totalCount;
  final Set<String> answeredIds;
  final OnboardingQuestion? nextQuestion;
  final bool done;
  final List<QuestionYield> candidates;
}
