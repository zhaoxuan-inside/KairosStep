// L7 引擎配置的强类型包装（engines.json / gates.json）。
// 数据与类型同源约定：本文件只做解析与求值，不含任何业务词表——
// 词表/参数的单一事实源在 JSON；修改行为必须改 JSON 并通过 golden 快照。
import 'package:flutter/foundation.dart';

import '../models/advice.dart';
import '../models/probe_model.dart';

// ───────────────────────── engines.json ─────────────────────────

class EngineConfig {
  const EngineConfig({required this.reminder, required this.probe, required this.stream});

  final ReminderEngineConfig reminder;
  final ProbeEngineConfig probe;
  final StreamEngineConfig stream;

  factory EngineConfig.fromJson(Map<String, dynamic> json) => EngineConfig(
    reminder: ReminderEngineConfig.fromJson(json['reminder'] as Map<String, dynamic>),
    probe: ProbeEngineConfig.fromJson(json['probe'] as Map<String, dynamic>),
    stream: StreamEngineConfig.fromJson(json['stream'] as Map<String, dynamic>),
  );
}

class QuietHours {
  const QuietHours({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;

  /// 与原实现逐字对齐：`now.hour >= start || now.hour < end`。
  bool covers(int hour) => hour >= startHour || hour < endHour;

  factory QuietHours.fromJson(Map<String, dynamic> json) => QuietHours(
    startHour: (json['start'] as num).toInt(),
    endHour: (json['end'] as num).toInt(),
  );
}

class ReminderEngineConfig {
  const ReminderEngineConfig({
    required this.tickerSeconds,
    required this.snoozeMinutes,
    required this.quietHours,
  });

  final int tickerSeconds;
  final int snoozeMinutes;
  final QuietHours quietHours;

  factory ReminderEngineConfig.fromJson(Map<String, dynamic> json) =>
      ReminderEngineConfig(
        tickerSeconds: (json['tickerSeconds'] as num).toInt(),
        snoozeMinutes: (json['snoozeMinutes'] as num).toInt(),
        quietHours: QuietHours.fromJson(json['quietHours'] as Map<String, dynamic>),
      );
}

class ProbeEngineConfig {
  const ProbeEngineConfig({
    required this.tickerMinutes,
    required this.maxDailyRoutine,
    required this.cooldownMinutes,
    required this.quietHours,
    required this.routineWindows,
    required this.dailySystemNotifications,
  });

  final int tickerMinutes;
  final int maxDailyRoutine;
  final int cooldownMinutes;
  final QuietHours quietHours;
  final List<RoutineWindow> routineWindows;
  final List<DailySystemNotification> dailySystemNotifications;

  factory ProbeEngineConfig.fromJson(Map<String, dynamic> json) =>
      ProbeEngineConfig(
        tickerMinutes: (json['tickerMinutes'] as num).toInt(),
        maxDailyRoutine: (json['maxDailyRoutine'] as num).toInt(),
        cooldownMinutes: (json['cooldownMinutes'] as num).toInt(),
        quietHours: QuietHours.fromJson(json['quietHours'] as Map<String, dynamic>),
        routineWindows: (json['routineWindows'] as List)
            .map((e) => RoutineWindow.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailySystemNotifications: (json['dailySystemNotifications'] as List)
            .map((e) => DailySystemNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 探查时机窗口：闭区间 [startHour:startMinute, endHour:endMinute]（分钟级含端点）。
class RoutineWindow {
  const RoutineWindow({
    required this.key,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final String key;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  bool isDue(int hour, int minute) {
    final t = hour * 60 + minute;
    return t >= startHour * 60 + startMinute && t <= endHour * 60 + endMinute;
  }

  factory RoutineWindow.fromJson(Map<String, dynamic> json) => RoutineWindow(
    key: json['key'] as String,
    startHour: (json['startHour'] as num).toInt(),
    startMinute: (json['startMinute'] as num).toInt(),
    endHour: (json['endHour'] as num).toInt(),
    endMinute: (json['endMinute'] as num).toInt(),
  );
}

class DailySystemNotification {
  const DailySystemNotification({
    required this.id,
    required this.hour,
    required this.minute,
  });

  final int id;
  final int hour;
  final int minute;

  factory DailySystemNotification.fromJson(Map<String, dynamic> json) =>
      DailySystemNotification(
        id: (json['id'] as num).toInt(),
        hour: (json['hour'] as num).toInt(),
        minute: (json['minute'] as num).toInt(),
      );
}

class StreamEngineConfig {
  const StreamEngineConfig({
    required this.windowMinutes,
    required this.customPeriodDistanceScale,
    required this.boostWindows,
  });

  final int windowMinutes;
  final int customPeriodDistanceScale;
  final List<BoostWindow> boostWindows;

  factory StreamEngineConfig.fromJson(Map<String, dynamic> json) =>
      StreamEngineConfig(
        windowMinutes: (json['windowMinutes'] as num).toInt(),
        customPeriodDistanceScale:
            (json['customPeriodDistanceScale'] as num).toInt(),
        boostWindows: (json['boostWindows'] as List)
            .map((e) => BoostWindow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 时段加权窗口：wrap=true 表示跨午夜（h>=from || h<=to），否则 h∈[from,to]。
/// 与原 if-else 链同序、首窗命中即止（互斥），组内任一命中加一次 boost。
class BoostWindow {
  const BoostWindow({
    required this.fromHour,
    required this.toHour,
    required this.wrap,
    required this.boosts,
  });

  final int fromHour;
  final int toHour;
  final bool wrap;
  final List<BoostGroup> boosts;

  bool covers(int hour) =>
      wrap ? (hour >= fromHour || hour <= toHour) : (hour >= fromHour && hour <= toHour);

  factory BoostWindow.fromJson(Map<String, dynamic> json) => BoostWindow(
    fromHour: (json['fromHour'] as num).toInt(),
    toHour: (json['toHour'] as num).toInt(),
    wrap: json['wrap'] as bool? ?? false,
    boosts: (json['boosts'] as List)
        .map((e) => BoostGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class BoostGroup {
  const BoostGroup({required this.boost, required this.any});

  final int boost;
  final List<BoostMatch> any;

  /// 组内任一匹配即命中（OR），等价原 if 条件的 || 链。
  bool matches(String badge, String title) => any.any((m) {
    final source = m.on == 'badge' ? badge : title;
    return m.text.any(source.contains);
  });

  factory BoostGroup.fromJson(Map<String, dynamic> json) => BoostGroup(
    boost: (json['boost'] as num).toInt(),
    any: (json['any'] as List)
        .map((e) => BoostMatch.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class BoostMatch {
  const BoostMatch({required this.on, required this.text});

  final String on; // 'badge' | 'title'
  final List<String> text; // 任一子串命中即匹配

  factory BoostMatch.fromJson(Map<String, dynamic> json) => BoostMatch(
    on: json['on'] as String,
    text: (json['text'] as List).cast<String>(),
  );
}

// ───────────────────────── gates.json ─────────────────────────

class GateConfig {
  const GateConfig({
    required this.dormantChapters,
    required this.dormantActTypes,
    required this.parentsAdviceIds,
    required this.habitEvolution,
    required this.ruleIdSets,
  });

  final Set<String> dormantChapters;
  final Set<String> dormantActTypes;
  final List<int> parentsAdviceIds;
  final List<HabitEvolutionRule> habitEvolution;
  final Map<String, List<int>> ruleIdSets;

  List<int> ruleSet(String id) => ruleIdSets[id] ?? const [];

  factory GateConfig.fromJson(Map<String, dynamic> json) => GateConfig(
    dormantChapters: (json['dormantChapters'] as List).cast<String>().toSet(),
    dormantActTypes: (json['dormantActTypes'] as List).cast<String>().toSet(),
    parentsAdviceIds: (json['parentsAdviceIds'] as List)
        .map((e) => (e as num).toInt())
        .toList(),
    habitEvolution: (json['habitEvolution'] as List)
        .map((e) => HabitEvolutionRule.fromJson(e as Map<String, dynamic>))
        .toList(),
    ruleIdSets: {
      for (final e in (json['ruleIdSets'] as Map<String, dynamic>).entries)
        e.key: (e.value as List).map((v) => (v as num).toInt()).toList(),
    },
  );
}

/// 习惯毕业 → 画像演进规则（数据驱动，替代原 if-else 链）。
@immutable
class HabitEvolutionRule {
  const HabitEvolutionRule({
    required this.adviceIds,
    this.removeConcerns = const [],
    this.addConcerns = const [],
    this.clearFlags = const [],
  });

  final List<int> adviceIds;
  final List<String> removeConcerns;
  final List<String> addConcerns;
  final List<String> clearFlags; // 画像布尔字段名：isSmoker / hasHypertension

  bool matches(int adviceId) => adviceIds.contains(adviceId);

  factory HabitEvolutionRule.fromJson(Map<String, dynamic> json) =>
      HabitEvolutionRule(
        adviceIds: (json['adviceIds'] as List).map((e) => (e as num).toInt()).toList(),
        removeConcerns: (json['removeConcerns'] as List?)?.cast<String>() ?? const [],
        addConcerns: (json['addConcerns'] as List?)?.cast<String>() ?? const [],
        clearFlags: (json['clearFlags'] as List?)?.cast<String>() ?? const [],
      );
}

// ───────────────────────── probes.json ─────────────────────────

/// 探查内容（probes.json）：绑定规则 + 三窗口题目模板 + 每日系统通知。
class ProbeContent {
  const ProbeContent({required this.bindings, required this.questions, required this.dailyNotifications});

  final ProbeBindingsConfig bindings;
  final Map<String, ProbeSlotTemplate> questions;
  final Map<String, DailyProbeNotificationContent> dailyNotifications;

  factory ProbeContent.fromJson(Map<String, dynamic> json) => ProbeContent(
    bindings: ProbeBindingsConfig.fromJson(json['bindings'] as Map<String, dynamic>),
    questions: {
      for (final e in (json['questions'] as Map<String, dynamic>).entries)
        e.key: ProbeSlotTemplate.fromJson(e.key, e.value as Map<String, dynamic>),
    },
    dailyNotifications: {
      for (final e in (json['dailySystemNotifications'] as Map<String, dynamic>).entries)
        e.key: DailyProbeNotificationContent.fromJson(e.value as Map<String, dynamic>),
    },
  );
}

class ProbeBindingsConfig {
  const ProbeBindingsConfig({
    required this.explicit,
    required this.urgentFallback,
    required this.keywordRules,
    required this.lifestyleFallback,
  });

  final Map<int, AdviceProbeSpec> explicit;
  final AdviceProbeSpec urgentFallback;
  final List<ProbeKeywordRule> keywordRules;
  final AdviceProbeSpec lifestyleFallback;

  factory ProbeBindingsConfig.fromJson(Map<String, dynamic> json) => ProbeBindingsConfig(
    explicit: {
      for (final e in (json['explicit'] as Map<String, dynamic>).entries)
        int.parse(e.key): _spec(e.value as Map<String, dynamic>),
    },
    urgentFallback: _spec(json['urgentFallback'] as Map<String, dynamic>),
    keywordRules: (json['keywordRules'] as List)
        .map((e) => ProbeKeywordRule.fromJson(e as Map<String, dynamic>))
        .toList(),
    lifestyleFallback: _spec(json['lifestyleFallback'] as Map<String, dynamic>),
  );

  static AdviceProbeSpec _spec(Map<String, dynamic> j) => AdviceProbeSpec(
    category: ProbeCategory.values.firstWhere((c) => c.name == j['category']),
    signalLevel: ProbeSignalLevel.values.firstWhere((s) => s.name == j['signalLevel']),
    promptQuestion: j['promptQuestion'] as String,
    matchingOption: j['matchingOption'] as String,
    targetPeriods: (j['targetPeriods'] as List).cast<String>(),
    responseGuidance: j['responseGuidance'] as String,
  );
}

/// 关键词归并规则：与原 if-else 链同序（声明序即优先级）。
/// chapterContains/tagsAny 对应原 chapter.contains / facets.any；
/// textContains 对应原 rawText（标题+核心动作+标签+章节拼接）子串匹配。
class ProbeKeywordRule {
  const ProbeKeywordRule({required this.id, required this.match, required this.spec});

  final String id;
  final ProbeKeywordMatch match;
  final AdviceProbeSpec spec;

  bool matches(Advice advice) {
    final chapter = advice.chapter;
    if (match.chapterContains.any(chapter.contains)) return true;
    if (match.tagsAny.any(advice.facets.contains)) return true;
    if (match.textContains.isNotEmpty) {
      final rawText = '${advice.title} ${advice.coreAction} ${advice.facets.tags.join(" ")} ${advice.chapter}';
      if (match.textContains.any(rawText.contains)) return true;
    }
    return false;
  }

  factory ProbeKeywordRule.fromJson(Map<String, dynamic> json) => ProbeKeywordRule(
    id: json['id'] as String,
    match: ProbeKeywordMatch.fromJson(json['match'] as Map<String, dynamic>),
    spec: ProbeBindingsConfig._spec(json['spec'] as Map<String, dynamic>),
  );
}

class ProbeKeywordMatch {
  const ProbeKeywordMatch({
    this.chapterContains = const [],
    this.tagsAny = const [],
    this.textContains = const [],
  });

  final List<String> chapterContains;
  final List<String> tagsAny;
  final List<String> textContains;

  factory ProbeKeywordMatch.fromJson(Map<String, dynamic> json) => ProbeKeywordMatch(
    chapterContains: (json['chapterContains'] as List?)?.cast<String>() ?? const [],
    tagsAny: (json['tagsAny'] as List?)?.cast<String>() ?? const [],
    textContains: (json['textContains'] as List?)?.cast<String>() ?? const [],
  );
}

/// 窗口探查模板（morning/afternoon/evening）。
class ProbeSlotTemplate {
  const ProbeSlotTemplate({
    required this.key,
    required this.title,
    required this.description,
    required this.signalLevel,
    required this.categories,
    required this.isMerged,
    required this.questions,
    this.roleQuestion,
  });

  final String key;
  final String title;
  final String description;
  final ProbeSignalLevel signalLevel;
  final List<ProbeCategory> categories;
  final bool isMerged;
  final List<ProbeQuestionSpec> questions;
  final ProbeRoleQuestion? roleQuestion;

  factory ProbeSlotTemplate.fromJson(String key, Map<String, dynamic> json) => ProbeSlotTemplate(
    key: key,
    title: json['title'] as String,
    description: json['description'] as String,
    signalLevel: ProbeSignalLevel.values.firstWhere((s) => s.name == json['signalLevel']),
    categories: (json['categories'] as List)
        .map((c) => ProbeCategory.values.firstWhere((c2) => c2.name == c))
        .toList(),
    isMerged: json['isMerged'] as bool? ?? false,
    questions: (json['questions'] as List)
        .map((e) => ProbeQuestionSpec.fromJson(e as Map<String, dynamic>))
        .toList(),
    roleQuestion: json['roleQuestion'] == null
        ? null
        : ProbeRoleQuestion.fromJson(json['roleQuestion'] as Map<String, dynamic>),
  );
}

class ProbeQuestionSpec {
  const ProbeQuestionSpec({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.options,
  });

  final String id;
  final ProbeCategory category;
  final String title;
  final String subtitle;
  final List<ProbeOptionSpec> options;

  ProbeQuestion toQuestion() => ProbeQuestion(
    id: id,
    category: category,
    title: title,
    subtitle: subtitle,
    options: [for (final o in options) o.toOption()],
  );

  factory ProbeQuestionSpec.fromJson(Map<String, dynamic> json) => ProbeQuestionSpec(
    id: json['id'] as String,
    category: ProbeCategory.values.firstWhere((c) => c.name == json['category']),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    options: (json['options'] as List)
        .map((e) => ProbeOptionSpec.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ProbeOptionSpec {
  const ProbeOptionSpec({
    required this.key,
    required this.label,
    required this.emoji,
    this.description,
    this.associatedAdviceIds = const [],
  });

  final String key;
  final String label;
  final String emoji;
  final String? description;
  final List<int> associatedAdviceIds;

  ProbeOption toOption() => ProbeOption(
    key: key,
    label: label,
    emoji: emoji,
    description: description,
    associatedAdviceIds: associatedAdviceIds,
  );

  factory ProbeOptionSpec.fromJson(Map<String, dynamic> json) => ProbeOptionSpec(
    key: json['key'] as String,
    label: json['label'] as String,
    emoji: json['emoji'] as String,
    description: json['description'] as String?,
    associatedAdviceIds: (json['associatedAdviceIds'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [],
  );
}

/// 晚间心情题的画像角色变体（worker/student/default）。
class ProbeRoleQuestion {
  const ProbeRoleQuestion({
    required this.id,
    required this.category,
    required this.subtitle,
    required this.variants,
  });

  final String id;
  final ProbeCategory category;
  final String subtitle;
  final Map<String, ProbeRoleVariant> variants;

  /// 与原实现逐字对齐：null 画像视为 worker；上班族优先，其次学生。
  String variantFor(UserProfile? profile) {
    final isWorker = profile?.roles.contains('上班族') ?? true;
    final isStudent = profile?.roles.contains('学生') ?? false;
    if (isWorker) return 'worker';
    if (isStudent) return 'student';
    return 'default';
  }

  ProbeQuestionSpec toQuestionSpec(String variantKey) {
    final v = variants[variantKey]!;
    return ProbeQuestionSpec(
      id: id,
      category: category,
      title: v.title,
      subtitle: subtitle,
      options: v.options,
    );
  }

  factory ProbeRoleQuestion.fromJson(Map<String, dynamic> json) => ProbeRoleQuestion(
    id: json['id'] as String,
    category: ProbeCategory.values.firstWhere((c) => c.name == json['category']),
    subtitle: json['subtitle'] as String,
    variants: {
      for (final e in (json['variants'] as Map<String, dynamic>).entries)
        e.key: ProbeRoleVariant.fromJson(e.value as Map<String, dynamic>),
    },
  );
}

class ProbeRoleVariant {
  const ProbeRoleVariant({required this.title, required this.options});

  final String title;
  final List<ProbeOptionSpec> options;

  factory ProbeRoleVariant.fromJson(Map<String, dynamic> json) => ProbeRoleVariant(
    title: json['title'] as String,
    options: (json['options'] as List)
        .map((e) => ProbeOptionSpec.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// 每日系统通知内容（9101-9103）。
class DailyProbeNotificationContent {
  const DailyProbeNotificationContent({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.payload,
    this.body,
    this.whenCategory,
    this.whenCategories = const [],
    this.roleBodies = const {},
  });

  final int id;
  final int hour;
  final int minute;
  final String title;
  final String payload;
  final String? body; // 固定文案（morning/afternoon）
  final String? whenCategory; // 触发条件：该探查类别有活跃建议
  final List<String> whenCategories;
  final Map<String, String> roleBodies; // evening：worker/student/default

  DailyProbeNotification toNotification({required String roleBody}) =>
      DailyProbeNotification(
        id: id,
        hour: hour,
        minute: minute,
        title: title,
        body: roleBody,
        payload: payload,
      );

  factory DailyProbeNotificationContent.fromJson(Map<String, dynamic> json) =>
      DailyProbeNotificationContent(
        id: (json['id'] as num).toInt(),
        hour: (json['hour'] as num).toInt(),
        minute: (json['minute'] as num).toInt(),
        title: json['title'] as String,
        payload: json['payload'] as String,
        body: json['body'] as String?,
        whenCategory: json['whenCategory'] as String?,
        whenCategories: (json['whenCategories'] as List?)?.cast<String>() ?? const [],
        roleBodies: (json['roleBodies'] as Map<String, dynamic>?)?.cast<String, String>() ?? const {},
      );
}
