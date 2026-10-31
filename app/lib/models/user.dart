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

/// 用户画像：年龄 + 性别 + 角色 + 居住与生活情境，驱动「画像专属」过滤与健康节点包触发。
@immutable
class UserProfile {
  const UserProfile({
    this.gender = '男',
    this.age = 28,
    this.roles = const ['全民', '上班族', '伴侣', '家人'],
    this.livingConditions = const ['租房人'],
    this.healthConcerns = const ['久坐伏案'],
    this.focusDomains = const [
      'health',
      'career',
      'family',
      'finance',
      'emergency',
      'cadence',
    ],
    this.prunedOnly = true,
    this.parentsOnly = false,
    this.hasCar = false,
    this.hasTwowheeler = false,
    this.hasChildren = false,
    this.hasAgingParents = false,
    this.isSmoker = false,
    this.hasPets = false,
    this.hasPipedGas = true,
    this.hasMortgage = false,
    this.isTenant = true,
    this.isEntrepreneur = false,
    this.hasHypertension = false,
    this.hasDiabetes = false,
    this.hasKidneyStones = false,
    this.hasGout = false,
    this.isProgrammer = false,
    this.isPregnantOrPlanning = false,
    this.hasAbroadTravelOrStudy = false,
    this.hasDebtPressure = false,
    this.hasDigitalAssetsConcern = false,
    this.hasDisabilityCare = false,
    this.hasCrisisOrMentalStress = false,
    this.heightCm,
    this.weightKg,
    this.hasWeightLossGoal = false,
    this.hasGastroAcidOrStomach = false,
    this.hasFrequentPainOrAnalgesic = false,
    this.childAgeStage = 'none', // 'none' | 'infant' (0~3岁) | 'school' (3~18岁)
    this.relationshipStatus = 'single', // 'single' | 'in_love' | 'married'
    this.formedHabits = const [],
  });

  final String gender;
  final int age;
  final List<String> roles;
  final List<String> livingConditions;
  final List<String> healthConcerns;
  final List<String> focusDomains; // 关注的人生领域，默认 6 大支柱全覆盖
  final bool prunedOnly; // 全景库默认「画像专属」
  final bool parentsOnly; // 父母适用清单
  final bool hasCar; // 是否拥有/常开机动车
  final bool hasTwowheeler; // 是否拥有/常骑电动车或摩托车
  final bool hasChildren; // 是否有子女/育儿中
  final bool hasAgingParents; // 是否家有老人需关照
  final bool isSmoker; // 是否吸烟（开启戒烟干预）
  final bool hasPets; // 是否养猫犬宠物
  final bool hasPipedGas; // 是否有厨房管道燃气设施
  final bool hasMortgage; // 是否有房贷/购房人
  final bool isTenant; // 是否租房人
  final bool isEntrepreneur; // 是否创业者/合伙人
  final bool hasHypertension; // 是否关注/确诊高血压
  final bool hasDiabetes; // 是否关注/确诊高血糖
  final bool hasKidneyStones; // 是否有肾结石病史
  final bool hasGout; // 是否有痛风/高尿酸
  final bool isProgrammer; // 是否程序员/技术研发人员
  final bool isPregnantOrPlanning; // 是否备孕/孕产中
  final bool hasAbroadTravelOrStudy; // 是否有出国/出境旅行/留学生涯
  final bool hasDebtPressure; // 是否面临债务压力或需极度拮据省钱
  final bool hasDigitalAssetsConcern; // 是否运营网站平台或关注核心数字资产
  final bool hasDisabilityCare; // 是否本人残障或需照护残障家人
  final bool hasCrisisOrMentalStress; // 是否经历重大变故或需高压心理减压
  final double? heightCm; // 身高 (cm)
  final double? weightKg; // 体重 (kg)
  final bool hasWeightLossGoal; // 是否有减重/塑形需求
  final bool hasGastroAcidOrStomach; // 是否有经常反酸烧心/慢性胃病史
  final bool hasFrequentPainOrAnalgesic; // 是否经常偏头痛/慢性疼痛常备止痛药
  final String childAgeStage; // 孩子年龄阶段
  final String relationshipStatus; // 亲密关系状态
  final List<int> formedHabits; // 已养成并沉淀为生活防线的习惯条目 ID 列表

  /// 计算 BMI 指数
  double? get bmi => (heightCm != null && weightKg != null && heightCm! > 0)
      ? (weightKg! / ((heightCm! / 100) * (heightCm! / 100)))
      : null;

  /// 是否属于超重或肥胖 (BMI >= 24)
  bool get isOverweightOrObese => (bmi ?? 0) >= 24.0;

  /// 归一化同步生活实体与旧标签池
  UserProfile normalized() {
    final nextRoles = Set<String>.from(roles)..add('全民');
    final nextLiving = Set<String>.from(livingConditions);
    final nextHealth = Set<String>.from(healthConcerns);

    if (hasCar) nextRoles.add('司机');
    if (hasChildren || childAgeStage != 'none') nextRoles.add('家长');
    if (relationshipStatus == 'married' || relationshipStatus == 'in_love') {
      nextRoles.add('伴侣');
    }
    if (hasAgingParents) nextLiving.add('家有老人');
    if (isTenant) nextLiving.add('租房人');
    if (hasMortgage) nextLiving.add('购房人');
    if (hasPets) nextLiving.add('养犬人');
    if (isEntrepreneur) nextRoles.add('创业者');
    if (isProgrammer) nextRoles.add('程序员');
    if (isPregnantOrPlanning) nextRoles.addAll(['准父母', '孕产']);
    if (hasAbroadTravelOrStudy) nextRoles.addAll(['出境者', '留学生']);
    if (hasDebtPressure) nextLiving.add('负债人群');
    if (hasDigitalAssetsConcern) nextRoles.add('平台运营');
    if (hasDisabilityCare) nextRoles.add('残障人士');
    if (hasCrisisOrMentalStress) nextHealth.add('心理减压');
    if (hasGastroAcidOrStomach) nextHealth.add('反酸胃炎');
    if (hasFrequentPainOrAnalgesic) nextHealth.add('止痛用药');
    if (hasWeightLossGoal) nextHealth.add('减重管理');
    if (isSmoker) nextHealth.add('吸烟者');
    if (hasHypertension) nextHealth.add('血压关注');
    if (hasDiabetes) nextHealth.add('血糖关注');
    if (hasKidneyStones) nextHealth.add('肾结石');
    if (hasGout) nextHealth.add('痛风');

    return copyWith(
      roles: nextRoles.toList(),
      livingConditions: nextLiving.toList(),
      healthConcerns: nextHealth.toList(),
    );
  }

  /// 人生阶段标签（口径同产品设计文档 §2）。
  List<String> get stages {
    if (age <= 22) return ['少年', '青年', '全民'];
    if (age <= 35) return ['青年', '全民'];
    if (age <= 55) return ['青年', '中年', '全民'];
    return ['中年', '老年', '全民'];
  }

  /// 适用群体（通用恒命中）。
  List<String> get groups => const ['通用', '自身', '泛指'];

  /// 排除维度：男性且无孕产相关角色时排除孕产/准父母条目。
  List<String> get exclude {
    final list = <String>[];
    if (gender == '男' && !roles.contains('准父母') && !roles.contains('家长')) {
      list.addAll(['孕产', '准父母']);
    }
    return list;
  }

  UserProfile copyWith({
    String? gender,
    int? age,
    List<String>? roles,
    List<String>? livingConditions,
    List<String>? healthConcerns,
    List<String>? focusDomains,
    bool? prunedOnly,
    bool? parentsOnly,
    bool? hasCar,
    bool? hasTwowheeler,
    bool? hasChildren,
    bool? hasAgingParents,
    bool? isSmoker,
    bool? hasPets,
    bool? hasPipedGas,
    bool? hasMortgage,
    bool? isTenant,
    bool? isEntrepreneur,
    bool? hasHypertension,
    bool? hasDiabetes,
    bool? hasKidneyStones,
    bool? hasGout,
    bool? isProgrammer,
    bool? isPregnantOrPlanning,
    bool? hasAbroadTravelOrStudy,
    bool? hasDebtPressure,
    bool? hasDigitalAssetsConcern,
    bool? hasDisabilityCare,
    bool? hasCrisisOrMentalStress,
    double? heightCm,
    double? weightKg,
    bool? hasWeightLossGoal,
    bool? hasGastroAcidOrStomach,
    bool? hasFrequentPainOrAnalgesic,
    String? childAgeStage,
    String? relationshipStatus,
    List<int>? formedHabits,
  }) => UserProfile(
    gender: gender ?? this.gender,
    age: age ?? this.age,
    roles: roles ?? this.roles,
    livingConditions: livingConditions ?? this.livingConditions,
    healthConcerns: healthConcerns ?? this.healthConcerns,
    focusDomains: focusDomains ?? this.focusDomains,
    prunedOnly: prunedOnly ?? this.prunedOnly,
    parentsOnly: parentsOnly ?? this.parentsOnly,
    hasCar: hasCar ?? this.hasCar,
    hasTwowheeler: hasTwowheeler ?? this.hasTwowheeler,
    hasChildren: hasChildren ?? this.hasChildren,
    hasAgingParents: hasAgingParents ?? this.hasAgingParents,
    isSmoker: isSmoker ?? this.isSmoker,
    hasPets: hasPets ?? this.hasPets,
    hasPipedGas: hasPipedGas ?? this.hasPipedGas,
    hasMortgage: hasMortgage ?? this.hasMortgage,
    isTenant: isTenant ?? this.isTenant,
    isEntrepreneur: isEntrepreneur ?? this.isEntrepreneur,
    hasHypertension: hasHypertension ?? this.hasHypertension,
    hasDiabetes: hasDiabetes ?? this.hasDiabetes,
    hasKidneyStones: hasKidneyStones ?? this.hasKidneyStones,
    hasGout: hasGout ?? this.hasGout,
    isProgrammer: isProgrammer ?? this.isProgrammer,
    isPregnantOrPlanning: isPregnantOrPlanning ?? this.isPregnantOrPlanning,
    hasAbroadTravelOrStudy:
        hasAbroadTravelOrStudy ?? this.hasAbroadTravelOrStudy,
    hasDebtPressure: hasDebtPressure ?? this.hasDebtPressure,
    hasDigitalAssetsConcern:
        hasDigitalAssetsConcern ?? this.hasDigitalAssetsConcern,
    hasDisabilityCare: hasDisabilityCare ?? this.hasDisabilityCare,
    hasCrisisOrMentalStress:
        hasCrisisOrMentalStress ?? this.hasCrisisOrMentalStress,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    hasWeightLossGoal: hasWeightLossGoal ?? this.hasWeightLossGoal,
    hasGastroAcidOrStomach:
        hasGastroAcidOrStomach ?? this.hasGastroAcidOrStomach,
    hasFrequentPainOrAnalgesic:
        hasFrequentPainOrAnalgesic ?? this.hasFrequentPainOrAnalgesic,
    childAgeStage: childAgeStage ?? this.childAgeStage,
    relationshipStatus: relationshipStatus ?? this.relationshipStatus,
    formedHabits: formedHabits ?? this.formedHabits,
  );

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'age': age,
    'roles': roles,
    'livingConditions': livingConditions,
    'healthConcerns': healthConcerns,
    'focusDomains': focusDomains,
    'prunedOnly': prunedOnly,
    'parentsOnly': parentsOnly,
    'hasCar': hasCar,
    'hasTwowheeler': hasTwowheeler,
    'hasChildren': hasChildren,
    'hasAgingParents': hasAgingParents,
    'isSmoker': isSmoker,
    'hasPets': hasPets,
    'hasPipedGas': hasPipedGas,
    'hasMortgage': hasMortgage,
    'isTenant': isTenant,
    'isEntrepreneur': isEntrepreneur,
    'hasHypertension': hasHypertension,
    'hasDiabetes': hasDiabetes,
    'hasKidneyStones': hasKidneyStones,
    'hasGout': hasGout,
    'isProgrammer': isProgrammer,
    'isPregnantOrPlanning': isPregnantOrPlanning,
    'hasAbroadTravelOrStudy': hasAbroadTravelOrStudy,
    'hasDebtPressure': hasDebtPressure,
    'hasDigitalAssetsConcern': hasDigitalAssetsConcern,
    'hasDisabilityCare': hasDisabilityCare,
    'hasCrisisOrMentalStress': hasCrisisOrMentalStress,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'hasWeightLossGoal': hasWeightLossGoal,
    'hasGastroAcidOrStomach': hasGastroAcidOrStomach,
    'hasFrequentPainOrAnalgesic': hasFrequentPainOrAnalgesic,
    'childAgeStage': childAgeStage,
    'relationshipStatus': relationshipStatus,
    'formedHabits': formedHabits,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    gender: json['gender'] as String? ?? '男',
    age: json['age'] as int? ?? 28,
    roles:
        (json['roles'] as List?)?.cast<String>() ??
        const ['全民', '上班族', '伴侣', '家人'],
    livingConditions:
        (json['livingConditions'] as List?)?.cast<String>() ?? const ['租房人'],
    healthConcerns:
        (json['healthConcerns'] as List?)?.cast<String>() ?? const ['久坐伏案'],
    focusDomains:
        (json['focusDomains'] as List?)?.cast<String>() ??
        const ['health', 'career', 'family', 'finance', 'emergency', 'cadence'],
    prunedOnly: json['prunedOnly'] as bool? ?? true,
    parentsOnly: json['parentsOnly'] as bool? ?? false,
    hasCar: json['hasCar'] as bool? ?? false,
    hasTwowheeler: json['hasTwowheeler'] as bool? ?? false,
    hasChildren: json['hasChildren'] as bool? ?? false,
    hasAgingParents: json['hasAgingParents'] as bool? ?? false,
    isSmoker: json['isSmoker'] as bool? ?? false,
    hasPets: json['hasPets'] as bool? ?? false,
    hasPipedGas: json['hasPipedGas'] as bool? ?? true,
    hasMortgage: json['hasMortgage'] as bool? ?? false,
    isTenant: json['isTenant'] as bool? ?? true,
    isEntrepreneur: json['isEntrepreneur'] as bool? ?? false,
    hasHypertension: json['hasHypertension'] as bool? ?? false,
    hasDiabetes: json['hasDiabetes'] as bool? ?? false,
    hasKidneyStones: json['hasKidneyStones'] as bool? ?? false,
    hasGout: json['hasGout'] as bool? ?? false,
    isProgrammer: json['isProgrammer'] as bool? ?? false,
    isPregnantOrPlanning: json['isPregnantOrPlanning'] as bool? ?? false,
    hasAbroadTravelOrStudy: json['hasAbroadTravelOrStudy'] as bool? ?? false,
    hasDebtPressure: json['hasDebtPressure'] as bool? ?? false,
    hasDigitalAssetsConcern: json['hasDigitalAssetsConcern'] as bool? ?? false,
    hasDisabilityCare: json['hasDisabilityCare'] as bool? ?? false,
    hasCrisisOrMentalStress: json['hasCrisisOrMentalStress'] as bool? ?? false,
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    hasWeightLossGoal: json['hasWeightLossGoal'] as bool? ?? false,
    hasGastroAcidOrStomach: json['hasGastroAcidOrStomach'] as bool? ?? false,
    hasFrequentPainOrAnalgesic:
        json['hasFrequentPainOrAnalgesic'] as bool? ?? false,
    childAgeStage: json['childAgeStage'] as String? ?? 'none',
    relationshipStatus: json['relationshipStatus'] as String? ?? 'single',
    formedHabits:
        (json['formedHabits'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [],
  );

  String get label =>
      '$age 岁 · $gender · ${roles.where((r) => r != '全民').take(3).join('/')}';
}

/// 父母适用清单（人工复核，来源 HowToLiveBetterFor35Dev.md，139 条）。


/// 卡片交互状态：某个作用域内一张卡的完成部件集合 + 附加数据。
///
/// 设计要点：交互器只改 [doneParts] / [extra]，完成判定由卡片统一求值，
/// 使 13 种形态共用一套持久化与计数管线。
class CardState {
  /// 默认集合必须是可变的：交互器会在其上直接 add/remove。
  CardState({Set<String>? doneParts, Map<String, dynamic>? extra})
    : doneParts = doneParts ?? <String>{},
      extra = extra ?? <String, dynamic>{};

  Set<String> doneParts;
  Map<String, dynamic> extra;

  bool get isDone => doneParts.isNotEmpty && _completionRatio >= 1;

  double _completionRatio = 0;

  /// 由卡片按目标部件数写入完成度（0~1），驱动进度条。
  double get completionRatio => _completionRatio;

  set completionRatio(double v) => _completionRatio = v.clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'p': doneParts.toList(),
    'x': extra,
    'r': _completionRatio,
  };

  factory CardState.fromJson(Map<String, dynamic> json) => CardState(
    doneParts: ((json['p'] as List?) ?? const []).cast<String>().toSet(),
    extra: (json['x'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
  )..completionRatio = (json['r'] as num?)?.toDouble() ?? 0;
}

/// 每日连击记录。
@immutable
class StreakState {
  const StreakState({this.lastDay = '', this.days = 0});
  final String lastDay; // yyyy-mm-dd
  final int days;

  StreakState bump(String today) =>
      lastDay == today ? this : StreakState(lastDay: today, days: days + 1);
}
