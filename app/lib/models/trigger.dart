// 触发域：触发模式 + 自定义触发配置 + 浮出时段规范（自 models/advice.dart 分域拆出，类名不变）。
import 'package:flutter/material.dart';

// ============================================================================
// 6. 建议触发方式与周期配置模型 (Trigger Mode & Custom Cadence Config)
// ============================================================================

/// 建议触发模式
enum TriggerMode {
  /// 静默储备态：无明确触发日期/偶发情境，绝不进入 Now/今天/每周/每月，仅在全景库中随用随查
  dormant,

  /// 日常节律态：明确进入“今天”与“当下 Now”指定时段
  daily,

  /// 周期循环态：明确进入“周期”页面（每周/每月/每年）
  cadence,

  /// 到期窗口期：到期日前设定天数开始浮出
  windowed,
}

/// 用户自定义触发与周期配置
@immutable
class CustomTriggerConfig {
  const CustomTriggerConfig({
    required this.mode,
    this.dailyPeriods =
        const [], // 'morning', 'focus', 'afternoon', 'evening', 'night'
    this.cadenceScopeKey = 'weekly', // 'weekly', 'monthly', 'yearly'
    this.targetDate, // yyyy-mm-dd
    this.leadDays = 15,
    this.weekday = 1, // 1~7
    this.monthDay = 1, // 1~31
    this.reminderTimes = const [], // 提醒时间列表，如 ['07:30', '12:30']
  });

  final TriggerMode mode;
  final List<String> dailyPeriods;
  final String cadenceScopeKey;
  final String? targetDate;
  final int leadDays;
  final int weekday;
  final int monthDay;
  final List<String> reminderTimes;

  CustomTriggerConfig copyWith({
    TriggerMode? mode,
    List<String>? dailyPeriods,
    String? cadenceScopeKey,
    String? targetDate,
    int? leadDays,
    int? weekday,
    int? monthDay,
    List<String>? reminderTimes,
  }) => CustomTriggerConfig(
    mode: mode ?? this.mode,
    dailyPeriods: dailyPeriods ?? this.dailyPeriods,
    cadenceScopeKey: cadenceScopeKey ?? this.cadenceScopeKey,
    targetDate: targetDate ?? this.targetDate,
    leadDays: leadDays ?? this.leadDays,
    weekday: weekday ?? this.weekday,
    monthDay: monthDay ?? this.monthDay,
    reminderTimes: reminderTimes ?? this.reminderTimes,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'dailyPeriods': dailyPeriods,
    'cadenceScopeKey': cadenceScopeKey,
    'targetDate': targetDate,
    'leadDays': leadDays,
    'weekday': weekday,
    'monthDay': monthDay,
    'reminderTimes': reminderTimes,
  };

  factory CustomTriggerConfig.fromJson(
    Map<String, dynamic> json,
  ) => CustomTriggerConfig(
    mode: TriggerMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => TriggerMode.dormant,
    ),
    dailyPeriods: (json['dailyPeriods'] as List?)?.cast<String>() ?? const [],
    cadenceScopeKey: json['cadenceScopeKey'] as String? ?? 'weekly',
    targetDate: json['targetDate'] as String?,
    leadDays: json['leadDays'] as int? ?? 15,
    weekday: json['weekday'] as int? ?? 1,
    monthDay: json['monthDay'] as int? ?? 1,
    reminderTimes: (json['reminderTimes'] as List?)?.cast<String>() ?? const [],
  );
}

/// 浮出时段规范定义：包含具体时间段范围与交叠判定算法
class PeriodDefinition {
  const PeriodDefinition({
    required this.key,
    required this.name,
    required this.startMinute,
    required this.endMinute,
    required this.timeRangeLabel,
  });

  final String key;
  final String name;
  final int startMinute; // 0 ~ 1440
  final int endMinute; // 0 ~ 1440
  final String timeRangeLabel; // 如 "05:00-09:30"

  String get fullLabel => '$name $timeRangeLabel';

  static const morning = PeriodDefinition(
    key: 'morning',
    name: '早晨',
    startMinute: 300, // 05:00
    endMinute: 570, // 09:30
    timeRangeLabel: '05:00-09:30',
  );

  static const focus = PeriodDefinition(
    key: 'focus',
    name: '上午',
    startMinute: 570, // 09:30
    endMinute: 720, // 12:00
    timeRangeLabel: '09:30-12:00',
  );

  static const afternoon = PeriodDefinition(
    key: 'afternoon',
    name: '午后',
    startMinute: 720, // 12:00
    endMinute: 1080, // 18:00
    timeRangeLabel: '12:00-18:00',
  );

  static const evening = PeriodDefinition(
    key: 'evening',
    name: '傍晚',
    startMinute: 1080, // 18:00
    endMinute: 1320, // 22:00
    timeRangeLabel: '18:00-22:00',
  );

  static const night = PeriodDefinition(
    key: 'night',
    name: '夜深',
    startMinute: 1320, // 22:00
    endMinute: 300, // 05:00（跨午夜）
    timeRangeLabel: '22:00-05:00',
  );

  static const standardPeriods = [morning, focus, afternoon, evening, night];

  static PeriodDefinition? byKey(String key) {
    for (final p in standardPeriods) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// 检查给定区间 [windowStart, windowEnd] 是否与本时段发生交叠
  bool overlaps(int windowStart, int windowEnd) {
    return timeRangesOverlap(startMinute, endMinute, windowStart, windowEnd);
  }

  /// 通用时间段交叠判定（支持跨午夜，如 22:00-05:00）
  static bool timeRangesOverlap(int aStart, int aEnd, int bStart, int bEnd) {
    final aIntervals = _splitInterval(aStart, aEnd);
    final bIntervals = _splitInterval(bStart, bEnd);
    for (final a in aIntervals) {
      for (final b in bIntervals) {
        if (a.$1 < b.$2 && b.$1 < a.$2) return true;
      }
    }
    return false;
  }

  static List<(int, int)> _splitInterval(int start, int end) {
    if (start <= end) {
      return [(start, end)];
    } else {
      // 跨越午夜
      return [(start, 1440), (0, end)];
    }
  }

  /// 解析自定义时段字符串，例如 'custom:08:00-10:00'
  static (int, int, String)? parseCustomPeriod(String str) {
    if (!str.startsWith('custom:')) return null;
    final parts = str.substring(7).split('-');
    if (parts.length != 2) return null;
    final sParts = parts[0].split(':');
    final eParts = parts[1].split(':');
    if (sParts.length != 2 || eParts.length != 2) return null;
    final sh = int.tryParse(sParts[0]);
    final sm = int.tryParse(sParts[1]);
    final eh = int.tryParse(eParts[0]);
    final em = int.tryParse(eParts[1]);
    if (sh == null || sm == null || eh == null || em == null) return null;
    final startMin = sh * 60 + sm;
    final endMin = eh * 60 + em;
    final label = '${parts[0]}-${parts[1]}';
    return (startMin, endMin, label);
  }

  static String formatPeriodTag(String periodKey) {
    final def = byKey(periodKey);
    if (def != null) return '${def.name} (${def.timeRangeLabel})';
    final custom = parseCustomPeriod(periodKey);
    if (custom != null) return '自定义 (${custom.$3})';
    return periodKey;
  }
}

enum PeriodScope { today, weekly, monthly, yearly }
