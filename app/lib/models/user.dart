// 用户域：自建待办 / 节点包 / 90 天周期体系 / 卡内基复盘 / 紧急联系人
import 'package:flutter/material.dart';

import 'advice_core.dart';
import 'facets.dart';
import 'presentation.dart';

// ============================================================================
// 4. 用户行为与自建待办数据层 (User Behavior & Todo Domain)
// ============================================================================

/// 用户自建待办项或由建议转化的行动任务。
@immutable
class UserTodoItem {
  const UserTodoItem({
    required this.id,
    required this.title,
    this.adviceId,
    this.isDone = false,
    required this.createdAt,
    this.targetDate,
    this.note,
    this.content,
    this.triggerTime, // 触发时间如 "08:30"
    this.timePeriod = 'all_day', // 'morning', 'focus', 'afternoon', 'evening', 'night', 'all_day'
    this.reminderTimes = const [], // 提醒时间列表如 ["08:30", "12:00"]
    this.leadMinutes = 0, // 提前提醒：0 (准时), 5, 15, 30
    this.frequency =
        'daily', // 'daily', 'workday', 'weekend', 'weekly', 'monthly', 'once'
    this.triggerCount = 1,
  });

  final String id;
  final String title;
  final int? adviceId; // 可选关联的建议编号
  final bool isDone;
  final DateTime createdAt;
  final String? targetDate; // yyyy-mm-dd
  final String? note;
  final String? content; // 详细内容/执行操作要点
  final String? triggerTime; // 触发时间点 (HH:mm)
  final String timePeriod; // 时间范围/时段
  final List<String> reminderTimes; // 提醒时间列表
  final int leadMinutes; // 提前提醒分钟数
  final String frequency; // 触发周期
  final int triggerCount; // 触发次数

  UserTodoItem copyWith({
    bool? isDone,
    String? title,
    String? targetDate,
    String? note,
    String? content,
    String? triggerTime,
    String? timePeriod,
    List<String>? reminderTimes,
    int? leadMinutes,
    String? frequency,
    int? triggerCount,
  }) => UserTodoItem(
    id: id,
    title: title ?? this.title,
    adviceId: adviceId,
    isDone: isDone ?? this.isDone,
    createdAt: createdAt,
    targetDate: targetDate ?? this.targetDate,
    note: note ?? this.note,
    content: content ?? this.content,
    triggerTime: triggerTime ?? this.triggerTime,
    timePeriod: timePeriod ?? this.timePeriod,
    reminderTimes: reminderTimes ?? this.reminderTimes,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    frequency: frequency ?? this.frequency,
    triggerCount: triggerCount ?? this.triggerCount,
  );

  bool isTodayActive(DateTime now) {
    if (frequency == 'daily') return true;
    if (frequency == 'workday') return now.weekday >= 1 && now.weekday <= 5;
    if (frequency == 'weekend') return now.weekday >= 6;
    if (frequency == 'once') {
      return now.year == createdAt.year &&
          now.month == createdAt.month &&
          now.day == createdAt.day;
    }
    return true;
  }

  /// 转换为 Advice 模型以供统一卡片流与时间尺调度
  Advice toAdvice({int? syntheticId}) {
    final synId = syntheticId ?? (id.hashCode.abs() % 80000 + 10000);
    final detail = content ?? note ?? title;
    return Advice(
      raw: RawAdvice(id: synId, chapter: '我的自建待办', title: title),
      facets: AdviceFacets(
        tags: [
          '全民',
          '自建',
          frequency == 'daily' ? '每天' : '情境触发',
          if (timePeriod != 'all_day') timePeriod,
        ],
      ),
      presentation: AdvicePresentation(
        parts: [title, if (detail != title && detail.isNotEmpty) detail],
        timingBadge: '自建 · ${_frequencyLabel(frequency)}',
        actType: 'quick-checkin',
      ),
      treePath: 'custom/todo',
      treeDisplay: '我的生活防线 > 自建待办',
    );
  }

  static String _frequencyLabel(String f) {
    switch (f) {
      case 'workday':
        return '工作日';
      case 'weekend':
        return '周末';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      case 'once':
        return '仅一次';
      default:
        return '每天';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'adviceId': adviceId,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'targetDate': targetDate,
    'note': note,
    'content': content,
    'triggerTime': triggerTime,
    'timePeriod': timePeriod,
    'reminderTimes': reminderTimes,
    'leadMinutes': leadMinutes,
    'frequency': frequency,
    'triggerCount': triggerCount,
  };

  factory UserTodoItem.fromJson(Map<String, dynamic> json) => UserTodoItem(
    id: json['id'] as String,
    title: json['title'] as String,
    adviceId: json['adviceId'] as int?,
    isDone: json['isDone'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    targetDate: json['targetDate'] as String?,
    note: json['note'] as String?,
    content: json['content'] as String?,
    triggerTime: json['triggerTime'] as String?,
    timePeriod: json['timePeriod'] as String? ?? 'all_day',
    reminderTimes: (json['reminderTimes'] as List?)?.cast<String>() ?? const [],
    leadMinutes: json['leadMinutes'] as int? ?? 0,
    frequency: json['frequency'] as String? ?? 'daily',
    triggerCount: json['triggerCount'] as int? ?? 1,
  );
}

// ============================================================================
// 节点包与交互形态定义
// ============================================================================

@immutable
class NodePackageItem {
  const NodePackageItem({
    this.src,
    required this.label,
    required this.freq,
    this.female = false,
    this.bone = false,
    this.soft,
  });

  final int? src;
  final String label;
  final String freq;
  final bool female;
  final bool bone;
  final String? soft;

  factory NodePackageItem.fromJson(Map<String, dynamic> json) =>
      NodePackageItem(
        src: (json['src'] as num?)?.toInt(),
        label: json['label'] as String,
        freq: json['freq'] as String,
        female: json['female'] as bool? ?? false,
        bone: json['bone'] as bool? ?? false,
        soft: json['soft'] as String?,
      );
}

@immutable
class NodePackage {
  const NodePackage({
    required this.no,
    required this.title,
    required this.trigger,
    required this.headline,
    required this.items,
  });

  final String no;
  final String title;
  final int trigger;
  final String headline;
  final List<NodePackageItem> items;

  factory NodePackage.fromJson(Map<String, dynamic> json) => NodePackage(
    no: json['no'] as String,
    title: json['title'] as String,
    trigger: (json['trigger'] as num).toInt(),
    headline: json['headline'] as String,
    items: ((json['items'] as List?) ?? const [])
        .map((e) => NodePackageItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ============================================================================
// 7. 90 天周期培养体系与卡内基复盘模型 (90-Day Plan & Carnegie Review)
// ============================================================================

/// 90 天培养周期阶段
enum CyclePhase {
  /// 启动期（第 1–21 天）：只练最小动作，第 7/14/21 天轻复盘
  kickoff('启动期', '建立肌肉记忆 · 只练最小动作', 1, 21),

  /// 巩固期（第 22–66 天）：情景模拟与红线间隔复习
  consolidate('巩固期', '强化防线 · 红线复习与模拟', 22, 66),

  /// 评估期（第 67–90 天）：压力测试与报告生成
  evaluate('评估期', '减少提醒 · 压力测试与评估', 67, 90),

  /// 维护期（第 90 天之后）：常态化自律
  maintenance('维护期', '常态自检与年度筛查', 91, 9999);

  const CyclePhase(this.label, this.desc, this.startDay, this.endDay);
  final String label;
  final String desc;
  final int startDay;
  final int endDay;

  static CyclePhase ofDay(int day) {
    if (day <= 21) return kickoff;
    if (day <= 66) return consolidate;
    if (day <= 90) return evaluate;
    return maintenance;
  }
}

/// 90 天周期计划
@immutable
class NinetyDayPlan {
  const NinetyDayPlan({
    required this.startDate,
    required this.goalAdviceIds, // [安全底线ID, 财务防线ID, 健康/关系ID]
    this.kickoffReviewDay7 = false,
    this.kickoffReviewDay14 = false,
    this.kickoffReviewDay21 = false,
    this.isCompleted = false,
  });

  final DateTime startDate;
  final List<int> goalAdviceIds;
  final bool kickoffReviewDay7;
  final bool kickoffReviewDay14;
  final bool kickoffReviewDay21;
  final bool isCompleted;

  int get currentDay {
    final diff = DateTime.now().difference(startDate).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  CyclePhase get phase => CyclePhase.ofDay(currentDay);

  NinetyDayPlan copyWith({
    DateTime? startDate,
    List<int>? goalAdviceIds,
    bool? kickoffReviewDay7,
    bool? kickoffReviewDay14,
    bool? kickoffReviewDay21,
    bool? isCompleted,
  }) => NinetyDayPlan(
    startDate: startDate ?? this.startDate,
    goalAdviceIds: goalAdviceIds ?? this.goalAdviceIds,
    kickoffReviewDay7: kickoffReviewDay7 ?? this.kickoffReviewDay7,
    kickoffReviewDay14: kickoffReviewDay14 ?? this.kickoffReviewDay14,
    kickoffReviewDay21: kickoffReviewDay21 ?? this.kickoffReviewDay21,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'goalAdviceIds': goalAdviceIds,
    'kickoffReviewDay7': kickoffReviewDay7,
    'kickoffReviewDay14': kickoffReviewDay14,
    'kickoffReviewDay21': kickoffReviewDay21,
    'isCompleted': isCompleted,
  };

  factory NinetyDayPlan.fromJson(Map<String, dynamic> json) => NinetyDayPlan(
    startDate:
        DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
    goalAdviceIds:
        (json['goalAdviceIds'] as List?)?.cast<int>() ?? const [1, 387, 13],
    kickoffReviewDay7: json['kickoffReviewDay7'] as bool? ?? false,
    kickoffReviewDay14: json['kickoffReviewDay14'] as bool? ?? false,
    kickoffReviewDay21: json['kickoffReviewDay21'] as bool? ?? false,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

/// 卡内基式 4 步周复盘条目
@immutable
class CarnegieReviewItem {
  const CarnegieReviewItem({
    required this.id,
    required this.createdAt,
    required this.eventFact,
    required this.myAction,
    required this.theirReaction,
    required this.nextOneSentence,
    this.tag = '职场沟通',
  });

  final String id;
  final DateTime createdAt;
  final String eventFact;
  final String myAction;
  final String theirReaction;
  final String nextOneSentence;
  final String tag;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'eventFact': eventFact,
    'myAction': myAction,
    'theirReaction': theirReaction,
    'nextOneSentence': nextOneSentence,
    'tag': tag,
  };

  factory CarnegieReviewItem.fromJson(Map<String, dynamic> json) =>
      CarnegieReviewItem(
        id: json['id'] as String,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        eventFact: json['eventFact'] as String? ?? '',
        myAction: json['myAction'] as String? ?? '',
        theirReaction: json['theirReaction'] as String? ?? '',
        nextOneSentence: json['nextOneSentence'] as String? ?? '',
        tag: json['tag'] as String? ?? '日常自检',
      );
}

/// 紧急联系人
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  final String name;
  final String phone;
  final String relation;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
      );
}
