// L7 引擎配置的强类型包装（engines.json / gates.json）。
// 数据与类型同源约定：本文件只做解析与求值，不含任何业务词表——
// 词表/参数的单一事实源在 JSON；修改行为必须改 JSON 并通过 golden 快照。
import 'package:flutter/foundation.dart';

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
