// 画像引擎（REFACTOR_DESIGN §5.8 / ONBOARDING_DESIGN §4）：引导即剪枝，未答不剪（ADR-009）。
// 判定复用 GatekeeperEngine（不写第二套门禁）；剪枝索引来自 L0 prerequisites + L3 标签 + L7 gates。
// 所有 profilePatch 映射到现有 UserProfile 字段（零迁移、零兼容风险）。
import '../data/catalog.dart';
import '../data/engine_configs.dart' show readOnboardingDoc;
import '../models/advice.dart';
import '../models/user.dart';
import 'gatekeeper_engine.dart';

class ProfileEngine {
  ProfileEngine({
    required this.catalog,
    required this.gatekeeper,
    required this.onboarding,
  });

  final Catalog catalog;
  final GatekeeperEngine gatekeeper;
  final OnboardingConfig onboarding;

  /// 引导重放基线（全新引导起步画像；「我的-画像」重配置则以当前画像为基线）。
  ///
  /// 与 UserProfile() 默认画像的唯一差异：focusDomains 空起步——默认全选会使
  /// 「关注域」多选题永远无效（追加进全选集合仍是 6 项，不触发剪枝）；空集
  /// 未答时同样不剪（matchPersona 仅在 0<|focusDomains|<6 时生效），未答不剪
  /// （ADR-009）语义不变，作答后按选择收窄。其余默认标签（租房人/上班族等）
  /// 保留以维持未答时的准入口径，由选项 patch 的 `key-` 移除语义负责清除。
  static const UserProfile onboardingBaseline = UserProfile(focusDomains: []);

  UserProfile normalize(UserProfile p) => p.normalized();

  /// 应用选项 patch（真实入口为选项作答；测试同用）。
  ///
  /// 键约定：`key+` = 列表追加（幂等去重）；`key-` = 列表移除（负面选择清除
  /// 默认标签/撤回他项，如「自住（无贷）」清「租房人」）；裸 key = 字段覆盖。
  UserProfile? applyPatch(UserProfile p, Map<String, dynamic> patch) =>
      _applyPatch(p, patch);

  /// 由选择态按题目顺序重放 patch 得出草稿画像（引导视图唯一草稿来源）。
  ///
  /// [selectedByQuestion]：题目 id → 已选选项 value 集（单选重答=整题替换、
  /// 多选可取消，均由调用方维护）；[sliderPatches]：滑块题（birth_year/
  /// height_weight）的合成 patch。重放保证重答无残留、空 patch 选项不产生
  /// 幽灵状态；[base] 为起始画像（重配置入口传当前画像）。
  UserProfile replayDraft(
    Map<String, Set<String>> selectedByQuestion, {
    UserProfile base = onboardingBaseline,
    Map<String, Map<String, dynamic>> sliderPatches = const {},
  }) {
    var p = base;
    // Reset owned facts first, then replay all surviving branches. This preserves
    // facts shared by multiple questions and clears stale values from saved profiles.
    final visible = onboarding
        .visibleQuestions(selectedByQuestion)
        .map((q) => q.id)
        .toSet();
    for (final q in onboarding.questions) {
      if (selectedByQuestion.containsKey(q.id) ||
          sliderPatches.containsKey(q.id) ||
          (q.parentId != null &&
              selectedByQuestion[q.parentId]?.isNotEmpty == true) ||
          onboarding.isRuledOut(q.id, selectedByQuestion)) {
        p = _applyPatch(p, q.resetPatch) ?? p;
      }
    }
    for (final q in onboarding.questions) {
      if (!visible.contains(q.id)) continue;
      if (sliderPatches[q.id] case final patch?) {
        if (_applyPatch(p, patch) case final patched?) p = patched;
      }
      final selected = selectedByQuestion[q.id];
      if (selected == null || selected.isEmpty) continue;
      for (final o in q.options) {
        if (!selected.contains(o.value)) continue;
        if (_applyPatch(p, o.profilePatch) case final patched?) p = patched;
      }
    }
    return p.copyWith(
      onboardingAnswers: {
        for (final e in selectedByQuestion.entries)
          if (visible.contains(e.key)) e.key: e.value.toList(),
      },
    );
  }

  /// 当前画像下的活跃建议集；复用角色门禁与已作答的具体主题选择。
  Set<int> activeAdviceIds(UserProfile p) {
    return {
      for (final a in catalog.adviceList)
        if (gatekeeper.matchPersona(a, profile: p, topicFilter: (_) => true))
          a.id,
    };
  }

  /// 单题剪枝收益（max-yield 贪心的原子量）：收益 = |active| − min_option 存活数。
  /// 编译门禁下为纯字段判定（43 patch × 活跃集 ≈ 亚毫秒），供作答时低收益跳过判断。
  int questionYield(OnboardingQuestion q, UserProfile p, Set<int> activeSet) {
    var minSurvive = activeSet.length;
    for (final o in q.options) {
      final patched = _applyPatch(p, o.profilePatch);
      final survive = patched == null
          ? activeSet.length
          : activeSet.where((id) {
              final a = catalog.adviceById(id);
              return a == null ||
                  gatekeeper.matchPersona(
                    a,
                    profile: patched,
                    topicFilter: (_) => true,
                  );
            }).length;
      if (survive < minSurvive) minSurvive = survive;
    }
    return activeSet.length - minSurvive;
  }

  int _yieldThreshold(OnboardingQuestion q) =>
      q.tier >= 2 ? 1 : onboarding.pruning.minMarginalYield;

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
      if (!onboarding.isVisible(q.id, {
        for (final e in p.onboardingAnswers.entries) e.key: e.value.toSet(),
      })) {
        continue;
      }
      final gain = questionYield(q, p, activeSet);
      // 先粗后细：粗/中层收益达阈值才保留；细层（渐进收集）>0 即保留
      // ——细题的价值在画像精确度，不在剪枝量。
      if (gain >= _yieldThreshold(q) ||
          onboarding.questions.any((child) => child.parentId == q.id)) {
        out.add(QuestionYield(question: q, yieldCount: gain));
      }
    }
    // tier 主键（先粗后细），层内收益降序
    out.sort((a, b) {
      final byTier = a.question.tier.compareTo(b.question.tier);
      return byTier != 0 ? byTier : b.yieldCount.compareTo(a.yieldCount);
    });
    return out;
  }

  /// 引导状态：required 缺答优先，其次收益榜首；无题可问即完成。
  ///
  /// [frozenOrder] 冻结题序（引导页进入时由 rankQuestions 算一次定死，主干固定）：
  /// 提供后候选严格按该序推进，仅低收益跳过判断（questionYield）逐答求值——
  /// 不再逐答全量重排。
  OnboardingState onboardingState(
    UserProfile p,
    Set<String> answeredIds, {
    List<String>? frozenOrder,
  }) {
    final active = activeAdviceIds(p);
    final selections = {
      for (final e in p.onboardingAnswers.entries) e.key: e.value.toSet(),
    };
    final missingRequired = [
      for (final q in onboarding.visibleQuestions(selections))
        if (q.required &&
            !answeredIds.contains(q.id) &&
            onboarding.isVisible(q.id, selections))
          q,
    ];
    final List<QuestionYield> ranked;
    if (frozenOrder == null) {
      ranked = rankQuestions(p, active, answeredIds);
    } else {
      final byId = {for (final q in onboarding.questions) q.id: q};
      ranked = <QuestionYield>[];
      for (final id in frozenOrder) {
        if (answeredIds.contains(id)) continue;
        final q = byId[id];
        if (q == null ||
            q.required ||
            q.softOnly ||
            !onboarding.isVisible(q.id, selections)) {
          continue;
        }
        final gain = questionYield(q, p, active);
        if (gain >= _yieldThreshold(q)) {
          ranked.add(QuestionYield(question: q, yieldCount: gain));
        }
      }
    }
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

  /// 应用 profilePatch（`+` 结尾=列表追加；`-` 结尾=列表移除；未知键安全忽略
  /// ——未答不剪原则下宁可冗余）。
  UserProfile? _applyPatch(UserProfile p, Map<String, dynamic> patch) {
    if (patch.isEmpty) return null;
    var n = p;
    var changed = false;
    void touch() => changed = true;

    List<String> listOf(Object? v) => (v as List).cast<String>();
    List<String> without(List<String> list, List<String> gone) => [
      for (final x in list)
        if (!gone.contains(x)) x,
    ];

    for (final e in patch.entries) {
      final isAppend = e.key.endsWith('+');
      final isRemove = e.key.endsWith('-');
      final key = isAppend || isRemove
          ? e.key.substring(0, e.key.length - 1)
          : e.key;
      switch (key) {
        case 'gender' when !isAppend && !isRemove:
          n = n.copyWith(gender: e.value as String);
          touch();
        case 'age' when !isAppend && !isRemove:
          n = n.copyWith(age: (e.value as num).toInt());
          touch();
        case 'heightCm' when !isAppend && !isRemove:
          n = e.value == null
              ? n.copyWith(clearBodyMeasurements: true)
              : n.copyWith(heightCm: (e.value as num).toDouble());
          touch();
        case 'weightKg' when !isAppend && !isRemove:
          n = e.value == null
              ? n.copyWith(clearBodyMeasurements: true)
              : n.copyWith(weightKg: (e.value as num).toDouble());
          touch();
        case 'relationshipStatus' when !isAppend && !isRemove:
          n = n.copyWith(relationshipStatus: e.value as String);
          touch();
        case 'childAgeStage' when !isAppend && !isRemove:
          n = n.copyWith(childAgeStage: e.value as String);
          touch();
        case 'roles' when isAppend:
          n = n.copyWith(roles: {...n.roles, ...listOf(e.value)}.toList());
          touch();
        case 'roles' when isRemove:
          n = n.copyWith(roles: without(n.roles, listOf(e.value)));
          touch();
        case 'livingConditions' when isAppend:
          n = n.copyWith(
            livingConditions: {
              ...n.livingConditions,
              ...listOf(e.value),
            }.toList(),
          );
          touch();
        case 'livingConditions' when isRemove:
          n = n.copyWith(
            livingConditions: without(n.livingConditions, listOf(e.value)),
          );
          touch();
        case 'healthConcerns' when isAppend:
          n = n.copyWith(
            healthConcerns: {...n.healthConcerns, ...listOf(e.value)}.toList(),
          );
          touch();
        case 'healthConcerns' when isRemove:
          n = n.copyWith(
            healthConcerns: without(n.healthConcerns, listOf(e.value)),
          );
          touch();
        case 'focusDomains' when isAppend:
          n = n.copyWith(
            focusDomains: {...n.focusDomains, ...listOf(e.value)}.toList(),
          );
          touch();
        case 'focusDomains' when isRemove:
          n = n.copyWith(
            focusDomains: without(n.focusDomains, listOf(e.value)),
          );
          touch();
        case 'focusTopics':
          final topics = listOf(e.value)
              .where(catalog.topics.byPath.containsKey)
              .toList();
          n = n.copyWith(
            focusTopics: isAppend
                ? {...n.focusTopics, ...topics}.toList()
                : isRemove
                ? without(n.focusTopics, topics)
                : topics,
          );
          touch();
        case 'medications' when isAppend:
          n = n.copyWith(
            medications: {
              ...n.medications,
              ...listOf(e.value).where((x) => !n.medications.contains(x)),
            }.toList(),
          );
          touch();
        case 'medications' when isRemove:
          n = n.copyWith(medications: without(n.medications, listOf(e.value)));
          touch();
        case 'medications' when !isAppend && !isRemove:
          n = n.copyWith(medications: listOf(e.value));
          touch();
        case 'livingAlone' when !isAppend && !isRemove:
          n = n.copyWith(livingAlone: e.value as bool);
          touch();
        default:
          if (!isAppend && !isRemove && e.value is bool) {
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
    'isPregnantOrPlanning' => p.copyWith(isPregnantOrPlanning: v),
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

  bool isVisible(String id, Map<String, Set<String>> selections) {
    final byId = {for (final q in questions) q.id: q};
    bool visible(OnboardingQuestion q) {
      if (q.parentId == null) return true;
      final parent = byId[q.parentId]!;
      if (!visible(parent)) return false;
      final selected = selections[parent.id] ?? const <String>{};
      return selected.isNotEmpty &&
          (q.whenAny.isEmpty || selected.any(q.whenAny.contains));
    }

    return visible(byId[id]!);
  }

  /// Unknown/unanswered parents are not a negative answer.
  bool isRuledOut(String id, Map<String, Set<String>> selections) {
    final byId = {for (final q in questions) q.id: q};
    bool ruledOut(OnboardingQuestion q) {
      if (q.parentId == null) return false;
      final parent = byId[q.parentId]!;
      if (ruledOut(parent)) return true;
      final selected = selections[parent.id] ?? const <String>{};
      return selected.isNotEmpty &&
          q.whenAny.isNotEmpty &&
          !selected.any(q.whenAny.contains);
    }

    return ruledOut(byId[id]!);
  }

  List<OnboardingQuestion> visibleQuestions(
    Map<String, Set<String>> selections,
  ) {
    final byId = {for (final q in questions) q.id: q};
    int depth(OnboardingQuestion q) =>
        q.parentId == null ? 0 : 1 + depth(byId[q.parentId]!);
    final order = {
      for (var i = 0; i < questions.length; i++) questions[i].id: i,
    };
    return questions.where((q) => isVisible(q.id, selections)).toList()
      ..sort((a, b) {
        final level = depth(a).compareTo(depth(b));
        return level != 0 ? level : order[a.id]!.compareTo(order[b.id]!);
      });
  }

  void validateTree() {
    final byId = {for (final q in questions) q.id: q};
    if (byId.length != questions.length) {
      throw const FormatException('Duplicate onboarding question');
    }
    for (final q in questions) {
      final seen = <String>{q.id};
      var node = q;
      while (node.parentId != null) {
        final parent = byId[node.parentId];
        if (parent == null || !seen.add(parent.id)) {
          throw FormatException('Invalid onboarding parent: ${q.id}');
        }
        if (node.whenAny.any(
          (value) => !parent.options.any((o) => o.value == value),
        )) {
          throw FormatException('Unknown parent option: ${node.id}');
        }
        node = parent;
      }
    }
  }

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) =>
      OnboardingConfig(
        pruning: OnboardingPruning.fromJson(
          json['pruning'] as Map<String, dynamic>,
        ),
        layers: (json['layers'] as List)
            .map((e) => OnboardingLayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        questions: (json['questions'] as List)
            .map((e) => OnboardingQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 解析后把分层的 granularity 下放为题目 tier。
  OnboardingConfig withTierResolved() {
    validateTree();
    final tierOf = {for (final l in layers) l.key: l.tier};
    return OnboardingConfig(
      pruning: pruning,
      layers: layers,
      questions: [for (final q in questions) q.withTier(tierOf[q.layer] ?? 1)],
    );
  }

  static Future<OnboardingConfig> load() async {
    final json = await readOnboardingDoc();
    return OnboardingConfig.fromJson(json).withTierResolved();
  }
}

class OnboardingPruning {
  const OnboardingPruning({
    required this.minMarginalYield,
    required this.maxQuestions,
  });

  final int minMarginalYield;
  final int maxQuestions;

  factory OnboardingPruning.fromJson(Map<String, dynamic> json) =>
      OnboardingPruning(
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
    required this.granularity,
    required this.questions,
  });

  final String key;
  final String title;
  final bool required;
  final bool progressive;
  final String granularity; // coarse | mid | fine（先粗后细）
  final List<String> questions;

  int get tier => switch (granularity) {
    'coarse' => 0,
    'mid' => 1,
    _ => 2,
  };

  factory OnboardingLayer.fromJson(Map<String, dynamic> json) =>
      OnboardingLayer(
        key: json['key'] as String,
        title: json['title'] as String,
        required: json['required'] as bool? ?? false,
        progressive: json['progressive'] as bool? ?? false,
        granularity: json['granularity'] as String? ?? 'mid',
        questions: (json['questions'] as List).cast<String>(),
      );
}

class OnboardingQuestion {
  const OnboardingQuestion({
    required this.id,
    required this.layer,
    required this.tier,
    required this.required,
    required this.kind,
    required this.prompt,
    required this.skipAllowed,
    required this.softOnly,
    required this.options,
    this.parentId,
    this.whenAny = const [],
    this.resetPatch = const {},
  });

  final String id;
  final String layer;
  final int tier; // 0 粗 / 1 中 / 2 细（先粗后细排序主键）
  final bool required;
  final String kind;
  final String prompt;
  final bool skipAllowed;
  final bool softOnly; // 关注域：影响排序不剪枝
  final List<OnboardingOption> options;
  final String? parentId;
  final List<String> whenAny;
  final Map<String, dynamic> resetPatch;

  factory OnboardingQuestion.fromJson(Map<String, dynamic> json) =>
      OnboardingQuestion(
        id: json['id'] as String,
        layer: json['layer'] as String,
        tier: 1, // 解析后由 withTierResolved 按 granularity 下放
        required: json['required'] as bool? ?? false,
        kind: json['kind'] as String? ?? 'single_choice',
        prompt: json['prompt'] as String,
        skipAllowed: json['skipAllowed'] as bool? ?? true,
        softOnly: json['softOnly'] as bool? ?? false,
        options: (json['options'] as List? ?? const [])
            .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        parentId: json['parentId'] as String?,
        whenAny: (json['whenAny'] as List? ?? const []).cast<String>(),
        resetPatch: (json['resetPatch'] as Map<String, dynamic>?) ?? const {},
      );

  OnboardingQuestion withTier(int t) => OnboardingQuestion(
    id: id,
    layer: layer,
    tier: t,
    required: required,
    kind: kind,
    prompt: prompt,
    skipAllowed: skipAllowed,
    softOnly: softOnly,
    options: options,
    parentId: parentId,
    whenAny: whenAny,
    resetPatch: resetPatch,
  );
}

class OnboardingOption {
  const OnboardingOption({
    required this.value,
    required this.label,
    required this.profilePatch,
    this.note,
    this.exclusive = false,
  });

  final String value;
  final String label;
  final Map<String, dynamic> profilePatch;
  final String? note;
  final bool exclusive;

  factory OnboardingOption.fromJson(Map<String, dynamic> json) =>
      OnboardingOption(
        value: json['value'] as String,
        label: json['label'] as String,
        profilePatch:
            (json['profilePatch'] as Map<String, dynamic>?) ?? const {},
        note: json['note'] as String?,
        exclusive:
            json['exclusive'] as bool? ??
            ((json['profilePatch'] as Map?)?.isEmpty ?? true),
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
