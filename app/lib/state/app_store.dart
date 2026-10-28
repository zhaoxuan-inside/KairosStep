import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog.dart';
import '../models/advice.dart';
import '../models/topic_tree.dart';
import 'reminder_registry.dart';

/// 周期作用域：打卡记录天然按周期归零（今天跨天清空、周/月/年各自滚动）。
enum PeriodScope { today, weekly, monthly, yearly }

PeriodScope scopeFromKey(String key) => PeriodScope.values.firstWhere(
  (s) => s.name == key,
  orElse: () => PeriodScope.today,
);

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
  final String childAgeStage; // 孩子年龄阶段
  final String relationshipStatus; // 亲密关系状态
  final List<int> formedHabits; // 已养成并沉淀为生活防线的习惯条目 ID 列表

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
    childAgeStage: json['childAgeStage'] as String? ?? 'none',
    relationshipStatus: json['relationshipStatus'] as String? ?? 'single',
    formedHabits: (json['formedHabits'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
  );

  String get label =>
      '$age 岁 · $gender · ${roles.where((r) => r != '全民').take(3).join('/')}';
}

/// 父母适用清单（人工复核，来源 HowToLiveBetterFor35Dev.md，139 条）。
const List<int> parentsAdviceIds = [
  13,
  20,
  22,
  37,
  40,
  58,
  111,
  138,
  153,
  232,
  233,
  259,
  264,
  342,
  397,
  398,
  399,
  400,
  401,
  402,
  403,
  404,
  405,
  406,
  407,
  408,
  409,
  410,
  411,
  412,
  413,
  414,
  415,
  416,
  417,
  418,
  419,
  420,
  421,
  422,
  423,
  424,
  425,
  426,
  427,
  428,
  430,
  431,
  432,
  433,
  435,
  436,
  437,
  438,
  442,
  443,
  444,
  475,
  476,
  477,
  478,
  479,
  480,
  481,
  482,
  483,
  484,
  485,
  486,
  487,
  488,
  489,
  490,
  491,
  492,
  493,
  494,
  495,
  496,
  497,
  498,
  499,
  501,
  560,
  614,
  615,
  616,
  617,
  618,
  619,
  620,
  621,
  622,
  623,
  624,
  625,
  626,
  670,
  671,
  673,
  674,
  675,
  677,
  678,
  679,
  680,
  681,
  682,
  683,
  734,
  735,
  736,
  737,
  738,
  739,
  740,
  742,
  743,
  744,
  745,
  746,
  747,
  748,
  749,
  750,
  751,
  752,
  753,
  754,
  755,
  757,
  760,
  761,
  762,
  763,
  764,
  765,
  766,
  767,
];

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

/// 全局应用状态：画像、主题、打卡、连击、窗口期锚点。
///
/// 全部数据仅落在本地 SharedPreferences，不上云、不联网。
class AppStore extends ChangeNotifier {
  AppStore(this.catalog, this.prefs, {ThemeMode mode = ThemeMode.system})
    : _themeMode = mode;

  final Catalog catalog;
  final SharedPreferences prefs;

  /// 弹窗提示与提醒注册器
  late final ReminderRegistry reminderRegistry = ReminderRegistry(this);

  /// 同步当前活跃防线至提醒注册器（零全盘扫描开销，仅注册剪枝后的活跃条目）
  void syncReminderRegistry() {
    reminderRegistry.registerActiveReminders(todayAdvices);
  }

  // ---------- 偏好 ----------
  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode v) {
    _themeMode = v;
    prefs.setString('kThemeMode', v.name);
    notifyListeners();
  }

  UserProfile _profile = const UserProfile();
  UserProfile get profile => _profile;
  set profile(UserProfile v) {
    _profile = v;
    prefs.setString('kProfile', jsonEncode(v.toJson()));
    syncReminderRegistry();
    notifyListeners();
  }

  bool _hasProfile = false;
  bool get hasProfile => _hasProfile;

  /// 完成初始画像引导并持久化
  void completeOnboarding(UserProfile p) {
    _profile = p.normalized();
    _hasProfile = true;
    prefs.setString('kProfile', jsonEncode(_profile.toJson()));
    prefs.setBool('kHasCompletedOnboarding', true);
    syncReminderRegistry();
    notifyListeners();
  }

  /// 更新画像
  void updateProfile(UserProfile p) {
    _profile = p.normalized();
    prefs.setString('kProfile', jsonEncode(_profile.toJson()));
    syncReminderRegistry();
    notifyListeners();
  }

  // ---------- 父母关爱大字极简模式 ----------
  bool _seniorMode = false;
  bool get seniorMode => _seniorMode;
  set seniorMode(bool v) {
    _seniorMode = v;
    prefs.setBool('kSeniorMode', v);
    notifyListeners();
  }

  // ---------- 用户个性化排除集合 (Card Custom Exclusion / Pruning) ----------
  final Set<int> _excludedAdviceIds = {};
  Set<int> get excludedAdviceIds => Set.unmodifiable(_excludedAdviceIds);

  bool isExcluded(int id) => _excludedAdviceIds.contains(id);

  /// 排除某条建议（不进日常所有流）
  void excludeAdvice(int id) {
    _excludedAdviceIds.add(id);
    _persistExcluded();
    notifyListeners();
  }

  /// 恢复某条被排除的建议
  void restoreAdvice(int id) {
    _excludedAdviceIds.remove(id);
    _persistExcluded();
    notifyListeners();
  }

  void _persistExcluded() {
    prefs.setStringList(
      'kExcludedAdviceIds',
      _excludedAdviceIds.map((id) => id.toString()).toList(),
    );
  }

  // ---------- 已养成习惯与生活防线 (Formed Habits & Dynamic Pruning) ----------
  final Set<int> _formedHabits = {};
  final Map<int, String> _formedHabitDates = {};

  Set<int> get formedHabits => Set.unmodifiable(_formedHabits);
  bool isHabitFormed(int id) => _formedHabits.contains(id);
  String? habitFormedDate(int id) => _formedHabitDates[id];

  /// 标记某项建议已成为习惯：从今日/当下待办中剪枝移出，沉淀为生活防线，并联动演进用户画像
  void markHabitFormed(int id, {DateTime? date}) {
    final now = date ?? DateTime.now();
    _formedHabits.add(id);
    _formedHabitDates[id] =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _persistFormedHabits();
    _evolveProfileByHabit(id);
    notifyListeners();
  }

  /// 重新带我练习一周（当用户生活节奏被打乱松懈时，温和恢复至今日待办）
  void relearnHabit(int id) {
    _formedHabits.remove(id);
    _formedHabitDates.remove(id);
    _persistFormedHabits();

    _profile = _profile.copyWith(
      formedHabits: _formedHabits.toList(),
    );
    _persistProfile();
    notifyListeners();
  }

  void _persistFormedHabits() {
    prefs.setStringList(
      'kFormedHabits',
      _formedHabits.map((id) => id.toString()).toList(),
    );
    final dateMap = <String, String>{};
    _formedHabitDates.forEach((id, d) {
      dateMap['$id'] = d;
    });
    prefs.setString('kFormedHabitDates', jsonEncode(dateMap));
  }

  /// 根据已养成的建议演化用户画像特质
  void _evolveProfileByHabit(int adviceId) {
    var p = _profile;
    final nextFormed = Set<int>.from(p.formedHabits)..add(adviceId);

    if (adviceId >= 49 && adviceId <= 54) {
      // 戒烟系列习惯毕业：画像更新为非吸烟者，健康关注移除吸烟者
      final nextHealth = Set<String>.from(p.healthConcerns)..remove('吸烟者');
      p = p.copyWith(
        isSmoker: false,
        healthConcerns: nextHealth.toList(),
      );
    } else if (adviceId == 7 || adviceId == 57) {
      // 血压达标/低钠盐习惯毕业
      final nextHealth = Set<String>.from(p.healthConcerns)..remove('血压关注');
      p = p.copyWith(
        hasHypertension: false,
        healthConcerns: nextHealth.toList(),
      );
    } else if (adviceId == 61 || adviceId == 97 || adviceId == 98) {
      // 睡眠规律/固定起床习惯养成
      final nextHealth = Set<String>.from(p.healthConcerns)..add('作息规律');
      p = p.copyWith(healthConcerns: nextHealth.toList());
    }

    _profile = p.copyWith(formedHabits: nextFormed.toList());
    _persistProfile();
  }

  void _persistProfile() {
    prefs.setString('kProfile', jsonEncode(_profile.toJson()));
  }

  // Topic preferences are independent of single-card exclusions and never erase content.
  final Set<String> _excludedTopicPaths = {};
  Set<String> get excludedTopicPaths => Set.unmodifiable(_excludedTopicPaths);

  String? hiddenAncestorOf(String path) {
    for (final hidden in _excludedTopicPaths) {
      if (TopicNode.containsPath(hidden, path)) return hidden;
    }
    return null;
  }

  bool matchesTopicPreferences(Advice a) =>
      catalog.topics.isVisible(a, _excludedTopicPaths);

  void excludeTopic(String path) {
    if (!catalog.topics.byPath.containsKey(path)) {
      throw ArgumentError.value(path, 'path', 'Unknown topic');
    }
    if (hiddenAncestorOf(path) != null) return;
    _excludedTopicPaths.removeWhere(
      (child) => TopicNode.containsPath(path, child),
    );
    _excludedTopicPaths.add(path);
    _persistTopicPreferences();
  }

  void restoreTopic(String path) {
    if (_excludedTopicPaths.remove(path)) _persistTopicPreferences();
  }

  void restoreAllTopics() {
    _excludedTopicPaths.clear();
    _persistTopicPreferences();
  }

  void _persistTopicPreferences() {
    prefs.setStringList(
      'kExcludedTopicPaths',
      _excludedTopicPaths.toList()..sort(),
    );
    notifyListeners();
  }

  // ---------- 建议自定义触发方式与触发周期 (Custom Triggers) ----------
  final Map<int, CustomTriggerConfig> _customTriggers = {};

  CustomTriggerConfig? triggerConfigOf(int id) => _customTriggers[id];

  /// 获取建议生效的触发配置（有自定义取自定义，否则推断原生默认）
  CustomTriggerConfig effectiveTriggerOf(Advice a) {
    if (_customTriggers.containsKey(a.id)) {
      return _customTriggers[a.id]!;
    }
    // 突发事件、急救处置、中暑处理等应急建议，原生推断一律为静默储备态（TriggerMode.dormant），严禁进入日常时间流
    if (a.isEmergencyOrIncident) {
      return const CustomTriggerConfig(mode: TriggerMode.dormant);
    }
    // 原生推断
    if (a.tags.contains('每天') || a.tags.contains('每日多次')) {
      final periods = <String>[];
      final text =
          '${a.title} ${a.tags.join(" ")} ${a.timingBadge} ${a.chapter}';
      if ([
        '晨',
        '早餐',
        '出发',
        '起床',
        '安全带',
        '头盔',
        '出行',
        '上班',
        '步行',
        '早起',
      ].any(text.contains)) {
        periods.add('morning');
      }
      if ([
        '工作',
        '工位',
        '久坐',
        '专注',
        '单线程',
        '视力',
        '办公',
        '开会',
        '同事',
        '屏幕',
        '咖啡',
        '饮水',
        '体态',
      ].any(text.contains)) {
        periods.add('focus');
      }
      if ([
        '午后',
        '站立',
        '远眺',
        '喝茶',
        '快走',
        '舒展',
        '午休',
        '小憩',
        '下午',
        '步数',
        '散步',
        '活动',
      ].any(text.contains)) {
        periods.add('afternoon');
      }
      if ([
        '归途',
        '晚餐',
        '家人',
        '沟通',
        '回家',
        '下班',
        '安全带',
        '头盔',
        '散步',
        '运动',
        '锻炼',
      ].any(text.contains)) {
        periods.add('evening');
      }
      if ([
        '睡眠',
        '屏幕',
        '夜里',
        '褪黑素',
        '安稳',
        '睡前',
        '刷牙',
        '洗漱',
        '失眠',
        '入眠',
        '23:00',
        '放松',
      ].any(text.contains)) {
        periods.add('night');
      }
      if (periods.isEmpty) {
        periods.addAll(['morning', 'focus', 'afternoon']);
      }

      // 智能预设黄金提醒时刻 (Smart Golden Reminder Hours)
      final reminderTimes = <String>[];
      if (text.contains('血压')) {
        reminderTimes.add('07:30');
      } else if (text.contains('早餐') ||
          text.contains('起床') ||
          text.contains('洗漱')) {
        reminderTimes.add('07:30');
      } else if (text.contains('安全带') || text.contains('头盔')) {
        reminderTimes.addAll(['08:15', '18:15']);
      } else if (text.contains('久坐') ||
          text.contains('远眺') ||
          text.contains('视力')) {
        reminderTimes.addAll(['10:30', '15:30']);
      } else if (text.contains('饮水') ||
          text.contains('喝水') ||
          text.contains('水')) {
        reminderTimes.addAll(['09:30', '11:30', '14:30', '16:30']);
      } else if (text.contains('午休') ||
          text.contains('小憩') ||
          text.contains('午后')) {
        reminderTimes.add('12:45');
      } else if (text.contains('散步') ||
          text.contains('运动') ||
          text.contains('慢跑') ||
          text.contains('快走')) {
        reminderTimes.add('19:00');
      } else if (text.contains('睡') ||
          text.contains('屏幕') ||
          text.contains('23:00')) {
        reminderTimes.add('22:00');
      } else {
        if (periods.contains('morning')) {
          reminderTimes.add('08:00');
        } else if (periods.contains('focus')) {
          reminderTimes.add('10:00');
        } else if (periods.contains('afternoon')) {
          reminderTimes.add('14:30');
        } else if (periods.contains('evening')) {
          reminderTimes.add('19:00');
        } else if (periods.contains('night')) {
          reminderTimes.add('22:00');
        }
      }

      return CustomTriggerConfig(
        mode: TriggerMode.daily,
        dailyPeriods: periods,
        reminderTimes: reminderTimes,
      );
    }
    if (a.tags.contains('每周')) {
      return const CustomTriggerConfig(
        mode: TriggerMode.cadence,
        cadenceScopeKey: 'weekly',
      );
    }
    if (a.tags.contains('每月')) {
      return const CustomTriggerConfig(
        mode: TriggerMode.cadence,
        cadenceScopeKey: 'monthly',
      );
    }
    if (a.tags.contains('每年') ||
        a.tags.contains('筛查') ||
        a.tags.contains('日历时点')) {
      return const CustomTriggerConfig(
        mode: TriggerMode.cadence,
        cadenceScopeKey: 'yearly',
      );
    }
    // 其余均属于未明确触发日期的静默储备态
    return const CustomTriggerConfig(mode: TriggerMode.dormant);
  }

  /// 设置自定义触发方式与周期
  void setTriggerConfig(int id, CustomTriggerConfig cfg) {
    _customTriggers[id] = cfg;
    _persistCustomTriggers();
    syncReminderRegistry();
    notifyListeners();
  }

  /// 恢复系统默认触发与周期
  void resetTriggerConfig(int id) {
    _customTriggers.remove(id);
    _persistCustomTriggers();
    syncReminderRegistry();
    notifyListeners();
  }

  void _persistCustomTriggers() {
    final map = <String, String>{};
    _customTriggers.forEach((id, cfg) {
      map['$id'] = jsonEncode(cfg.toJson());
    });
    prefs.setString('kCustomTriggers', jsonEncode(map));
  }

  // ---------- 90 天周期培养体系 (90-Day Plan) ----------
  NinetyDayPlan _ninetyDayPlan = NinetyDayPlan(
    startDate: DateTime.now(),
    goalAdviceIds: const [1, 387, 13], // 安全底线(安全带) + 财务防线(法律财产) + 健康关系(练平衡)
  );
  NinetyDayPlan get ninetyDayPlan => _ninetyDayPlan;

  void updateNinetyDayPlan(NinetyDayPlan plan) {
    _ninetyDayPlan = plan;
    prefs.setString('kNinetyDayPlan', jsonEncode(plan.toJson()));
    notifyListeners();
  }

  /// 替换本周期某个动作
  void swapCycleGoal(int oldId, int newId) {
    final list = List<int>.from(_ninetyDayPlan.goalAdviceIds);
    final idx = list.indexOf(oldId);
    if (idx != -1) {
      list[idx] = newId;
    } else if (list.length < 3) {
      list.add(newId);
    }
    updateNinetyDayPlan(_ninetyDayPlan.copyWith(goalAdviceIds: list));
  }

  /// 标记启动期节点复盘完成
  void markKickoffReview(int day) {
    if (day == 7) {
      updateNinetyDayPlan(_ninetyDayPlan.copyWith(kickoffReviewDay7: true));
    } else if (day == 14) {
      updateNinetyDayPlan(_ninetyDayPlan.copyWith(kickoffReviewDay14: true));
    } else if (day == 21) {
      updateNinetyDayPlan(_ninetyDayPlan.copyWith(kickoffReviewDay21: true));
    }
  }

  // ---------- 卡内基式 4 步周复盘 (Carnegie Review) ----------
  final List<CarnegieReviewItem> _carnegieReviews = [];
  List<CarnegieReviewItem> get carnegieReviews =>
      List.unmodifiable(_carnegieReviews);

  void addCarnegieReview({
    required String eventFact,
    required String myAction,
    required String theirReaction,
    required String nextOneSentence,
    String tag = '日常自检',
  }) {
    final item = CarnegieReviewItem(
      id: 'review_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      eventFact: eventFact.trim(),
      myAction: myAction.trim(),
      theirReaction: theirReaction.trim(),
      nextOneSentence: nextOneSentence.trim(),
      tag: tag,
    );
    _carnegieReviews.insert(0, item);
    _persistCarnegieReviews();
    notifyListeners();
  }

  void _persistCarnegieReviews() {
    final list = _carnegieReviews.map((r) => r.toJson()).toList();
    prefs.setString('kCarnegieReviews', jsonEncode(list));
  }

  // ---------- 紧急联系人 (Emergency Contacts) ----------
  final List<EmergencyContact> _emergencyContacts = [];
  List<EmergencyContact> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);

  void addEmergencyContact(String name, String phone, String relation) {
    _emergencyContacts.add(
      EmergencyContact(name: name, phone: phone, relation: relation),
    );
    _persistEmergencyContacts();
    notifyListeners();
  }

  void removeEmergencyContact(int index) {
    if (index >= 0 && index < _emergencyContacts.length) {
      _emergencyContacts.removeAt(index);
      _persistEmergencyContacts();
      notifyListeners();
    }
  }

  void _persistEmergencyContacts() {
    final list = _emergencyContacts.map((c) => c.toJson()).toList();
    prefs.setString('kEmergencyContacts', jsonEncode(list));
  }

  // ---------- 用户自建待办清单 (User Behavior & Todo Layer) ----------
  final List<UserTodoItem> _userTodos = [];
  List<UserTodoItem> get userTodos => List.unmodifiable(_userTodos);

  /// 添加用户自建行动项或从建议转化的待办
  void addUserTodo(
    String title, {
    int? adviceId,
    String? note,
    String? targetDate,
  }) {
    if (title.trim().isEmpty) return;
    final item = UserTodoItem(
      id: 'todo_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      adviceId: adviceId,
      createdAt: DateTime.now(),
      targetDate: targetDate,
      note: note,
    );
    _userTodos.insert(0, item);
    _persistUserTodos();
    notifyListeners();
  }

  /// 切换待办完成状态
  void toggleUserTodo(String id) {
    final idx = _userTodos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _userTodos[idx] = _userTodos[idx].copyWith(
        isDone: !_userTodos[idx].isDone,
      );
      _persistUserTodos();
      notifyListeners();
    }
  }

  /// 删除待办项
  void removeUserTodo(String id) {
    _userTodos.removeWhere((t) => t.id == id);
    _persistUserTodos();
    notifyListeners();
  }

  void _persistUserTodos() {
    final list = _userTodos.map((t) => t.toJson()).toList();
    prefs.setString('kUserTodos', jsonEncode(list));
  }

  // ---------- 打卡状态 ----------
  // scope → (adviceId → CardState)
  final Map<PeriodScope, Map<int, CardState>> _cards = {
    for (final s in PeriodScope.values) s: {},
  };

  // scope → 周期纪元键（今天: yyyy-MM-dd，本周: w_yyyy-MM-dd，本月: m_yyyy-MM，每年: y_yyyy）
  final Map<PeriodScope, String> _lastScopeEpochs = {};

  static String _scopeEpochKey(PeriodScope s, DateTime now) {
    switch (s) {
      case PeriodScope.today:
        return _dayKey(now);
      case PeriodScope.weekly:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return 'w_${_dayKey(monday)}';
      case PeriodScope.monthly:
        return 'm_${now.year}-${now.month.toString().padLeft(2, '0')}';
      case PeriodScope.yearly:
        return 'y_${now.year}';
    }
  }

  /// 周期跨期检测：跨天/跨周/跨月/跨年时自然清空打卡记录，业务上完全不影响次日展示。
  void checkPeriodRollover([DateTime? customNow]) {
    final now = customNow ?? DateTime.now();
    for (final s in PeriodScope.values) {
      final currentEpoch = _scopeEpochKey(s, now);
      final lastEpoch = _lastScopeEpochs[s];
      if (lastEpoch != null && lastEpoch != currentEpoch) {
        _lastScopeEpochs[s] = currentEpoch;
        _cards[s]?.clear();
        prefs.remove('kScope.${s.name}');
        prefs.setString('kScopeEpoch.${s.name}', currentEpoch);
      }
    }
  }

  // adviceId → StreakState（跨周期属于习惯本体）
  final Map<int, StreakState> _streaks = {};

  // 窗口期锚点：adviceId → 首次浮出日（决定窗口进度）
  final Map<int, DateTime> _windowAnchors = {};

  Map<int, CardState> cardsOf(PeriodScope s) {
    checkPeriodRollover();
    return _cards[s] ?? {};
  }

  CardState cardState(PeriodScope s, int id) {
    checkPeriodRollover();
    return _cards[s]![id] ??= CardState();
  }

  StreakState streakOf(int id) => _streaks[id] ?? const StreakState();
  DateTime? windowAnchorOf(int id) => _windowAnchors[id];

  /// 真实动态今天待办流（严格准入：绝不塞入无明确日期的偶发建议）
  List<Advice> get todayAdvices {
    checkPeriodRollover();
    final list = catalog.adviceList.where((a) {
      if (isExcluded(a.id) || !matchesTopicPreferences(a)) return false;
      if (isHabitFormed(a.id)) return false; // 已养成的习惯剪枝隐退，不再每日反复提醒
      if (_profile.prunedOnly && !matchPersona(a)) return false;

      // 应急/急救/突发处置建议（如中暑），除非显式自定义，否则严禁进入今日流
      if (a.isEmergencyOrIncident && !_customTriggers.containsKey(a.id)) {
        return false;
      }

      final trig = effectiveTriggerOf(a);
      switch (trig.mode) {
        case TriggerMode.dormant:
          return false; // 静默储备态严禁进入今日流
        case TriggerMode.daily:
          return true;
        case TriggerMode.windowed:
          if (trig.targetDate == null) return false;
          final target = DateTime.tryParse(trig.targetDate!);
          if (target == null) return false;
          final now = DateTime.now();
          final diff = target
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          return diff >= 0 && diff <= trig.leadDays;
        case TriggerMode.cadence:
          return false; // 周期循环态在周期页查看，不直接占位今日流
      }
    }).toList();

    // 已经打卡完成的排在下面（未完成优先置顶，已完成沉底）
    list.sort((a, b) {
      final aDone = cardState(PeriodScope.today, a.id).isDone ? 1 : 0;
      final bDone = cardState(PeriodScope.today, b.id).isDone ? 1 : 0;
      return aDone.compareTo(bDone);
    });

    return list;
  }

  /// 真实动态周期流（严格准入：绝不塞入无明确周期的偶发建议）
  List<Advice> cycleAdvicesOf(PeriodScope scope) {
    final list = catalog.adviceList.where((a) {
      if (isExcluded(a.id) || !matchesTopicPreferences(a)) return false;
      if (isHabitFormed(a.id)) return false; // 已养成的习惯剪枝隐退
      if (_profile.prunedOnly && !matchPersona(a)) return false;

      final trig = effectiveTriggerOf(a);
      switch (trig.mode) {
        case TriggerMode.cadence:
          return trig.cadenceScopeKey == scope.name;
        case TriggerMode.daily:
          return scope == PeriodScope.today;
        case TriggerMode.windowed:
          // 窗口期若设置在当年，可在 yearly 中列出
          return scope == PeriodScope.yearly;
        case TriggerMode.dormant:
          return false; // 静默储备态严禁进入周期流
      }
    }).toList();

    // 已经打卡完成的排在下面（未完成优先，已完成沉底）
    list.sort((a, b) {
      final aDone = cardState(scope, a.id).isDone ? 1 : 0;
      final bDone = cardState(scope, b.id).isDone ? 1 : 0;
      return aDone.compareTo(bDone);
    });

    return list;
  }

  /// 根据 1.5 小时聚焦视窗（中心时刻前后各 45 分钟）动态筛选严格属于该视窗的建议流
  List<Advice> advicesForWindow(DateTime centerTime) {
    final windowStart = centerTime.subtract(const Duration(minutes: 45));
    final windowEnd = centerTime.add(const Duration(minutes: 45));
    final winStartMin = windowStart.hour * 60 + windowStart.minute;
    final winEndMin = windowEnd.hour * 60 + windowEnd.minute;

    final mCenter = centerTime.hour * 60 + centerTime.minute;
    final centerHour = centerTime.hour;

    // 筛选严格与 1.5 小时视窗 [centerTime-45m, centerTime+45m] 发生时段交叠的建议
    final matched = catalog.adviceList.where((a) {
      if (isExcluded(a.id) || !matchesTopicPreferences(a)) return false;
      if (isHabitFormed(a.id)) return false; // 已养成的习惯剪枝隐退，不在时钟视窗流打扰
      if (_profile.prunedOnly && !matchPersona(a)) return false;

      // 应急/急救/突发处置建议（如中暑处理），除非用户显式手动自定义配置，否则严禁进入当下日常视窗流
      if (a.isEmergencyOrIncident && !_customTriggers.containsKey(a.id)) {
        return false;
      }

      final trig = effectiveTriggerOf(a);
      if (trig.mode == TriggerMode.dormant ||
          trig.mode == TriggerMode.cadence) {
        return false; // 严禁进入时钟视窗流
      }

      if (trig.mode == TriggerMode.daily) {
        // 检查该建议配置的任何时段（标准规范时段或自定义时段）是否与 1.5 小时视窗相交
        for (final pk in trig.dailyPeriods) {
          final def = PeriodDefinition.byKey(pk);
          if (def != null) {
            if (def.overlaps(winStartMin, winEndMin)) return true;
          }
          final custom = PeriodDefinition.parseCustomPeriod(pk);
          if (custom != null) {
            if (PeriodDefinition.timeRangesOverlap(
              custom.$1,
              custom.$2,
              winStartMin,
              winEndMin,
            )) {
              return true;
            }
          }
        }
        return false;
      }

      if (trig.mode == TriggerMode.windowed && trig.targetDate != null) {
        final target = DateTime.tryParse(trig.targetDate!);
        if (target != null) {
          final now = DateTime.now();
          final diff = target
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          if (diff >= 0 && diff <= trig.leadDays) {
            return PeriodDefinition.morning.overlaps(winStartMin, winEndMin) ||
                PeriodDefinition.evening.overlaps(winStartMin, winEndMin);
          }
        }
      }

      return false;
    }).toList();

    // 按照与中心时刻的相关性与精准锚点排序
    matched.sort((a, b) {
      // 已经打卡完成的排在下面（未完成优先充当 Hero，全部完成才轮到已完成）
      final aDone = cardState(PeriodScope.today, a.id).isDone ? 1 : 0;
      final bDone = cardState(PeriodScope.today, b.id).isDone ? 1 : 0;
      if (aDone != bDone) {
        return aDone.compareTo(bDone);
      }

      int score(Advice adv) {
        int s = 0;
        final trig = effectiveTriggerOf(adv);

        // 如果建议配置了自定义时段，距离 centerTime 越近权重越高
        for (final pk in trig.dailyPeriods) {
          final custom = PeriodDefinition.parseCustomPeriod(pk);
          if (custom != null) {
            final customMid = (custom.$1 + custom.$2) ~/ 2;
            final dist = (customMid - mCenter).abs();
            s += (300 - dist).clamp(0, 300);
          }
        }

        final badge = adv.timingBadge;
        final title = adv.title;

        // 针对不同时段的关键行动加权
        if (centerHour >= 22 || centerHour < 5) {
          if (badge.contains('23:00') ||
              title.contains('屏幕') ||
              title.contains('睡')) {
            s += 60;
          }
          if (badge.contains('洗漱') || title.contains('刷牙')) s += 30;
        } else if (centerHour >= 6 && centerHour <= 8) {
          if (badge.contains('07:00') ||
              badge.contains('晨') ||
              title.contains('安全带') ||
              title.contains('头盔')) {
            s += 60;
          }
          if (title.contains('早餐') || title.contains('血压')) s += 40;
        } else if (centerHour >= 9 && centerHour < 12) {
          if (title.contains('久坐') ||
              title.contains('专注') ||
              title.contains('工位') ||
              title.contains('单线程')) {
            s += 60;
          }
          if (title.contains('喝水') || title.contains('视力')) s += 30;
        } else if (centerHour >= 12 && centerHour <= 14) {
          if (badge.contains('13:00') ||
              title.contains('午') ||
              title.contains('小憩')) {
            s += 60;
          }
          if (title.contains('坐') || title.contains('远眺')) s += 30;
        } else if (centerHour > 14 && centerHour < 17) {
          if (title.contains('快走') ||
              title.contains('步数') ||
              title.contains('舒展') ||
              title.contains('远眺')) {
            s += 60;
          }
        } else if (centerHour >= 17 && centerHour <= 19) {
          if (title.contains('安全带') ||
              title.contains('头盔') ||
              title.contains('晚') ||
              title.contains('归途')) {
            s += 60;
          }
          if (title.contains('家人') || title.contains('晚餐')) s += 30;
        } else if (centerHour > 19 && centerHour < 22) {
          if (title.contains('家人') ||
              title.contains('散步') ||
              title.contains('沟通') ||
              title.contains('放松')) {
            s += 60;
          }
        }
        return s;
      }

      return score(b).compareTo(score(a));
    });

    return matched;
  }

  /// 真实动态时段建议流（严格准入：绝不塞入无明确时段的偶发建议）
  List<Advice> periodAdvicesOf(String periodKey) {
    final list = catalog.adviceList.where((a) {
      if (isExcluded(a.id) || !matchesTopicPreferences(a)) return false;
      if (isHabitFormed(a.id)) return false; // 已养成的习惯剪枝隐退，不在时段流打扰
      if (_profile.prunedOnly && !matchPersona(a)) return false;

      // 应急/急救建议严禁进入日常时段流
      if (a.isEmergencyOrIncident && !_customTriggers.containsKey(a.id)) {
        return false;
      }

      final trig = effectiveTriggerOf(a);
      if (trig.mode == TriggerMode.dormant ||
          trig.mode == TriggerMode.cadence) {
        return false; // 严禁进入时钟时段流
      }

      if (trig.mode == TriggerMode.daily) {
        return trig.dailyPeriods.contains(periodKey);
      }

      if (trig.mode == TriggerMode.windowed && trig.targetDate != null) {
        final target = DateTime.tryParse(trig.targetDate!);
        if (target != null) {
          final now = DateTime.now();
          final diff = target
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          if (diff >= 0 && diff <= trig.leadDays) {
            return periodKey == 'morning' || periodKey == 'evening';
          }
        }
      }

      return false;
    }).toList();

    if (list.isEmpty) {
      // 兜底保护：当该时段无特定项目时，仅从通用日常建议中优雅展现对应动作，绝不抽取偶发建议
      return catalog.adviceList.where((a) {
        if (isExcluded(a.id)) return false;
        if (a.isEmergencyOrIncident && !_customTriggers.containsKey(a.id)) {
          return false;
        }
        final trig = effectiveTriggerOf(a);
        if (trig.mode != TriggerMode.daily) return false;
        return trig.dailyPeriods.contains(periodKey);
      }).toList();
    }
    return list;
  }

  /// 全量应急/急救/突发处置条目（供紧急面板或突发模式使用，如中暑、骨折、海姆立克等）
  List<Advice> get emergencyAdvices {
    return catalog.adviceList.where((a) => a.isEmergencyOrIncident).toList();
  }

  /// 某作用域的完成数 / 总数（动态根据真实建议统计，零写死 Mock）。
  (int, int) countersOf(PeriodScope s) {
    final list = cycleAdvicesOf(s);
    if (list.isEmpty) return (0, 0);
    final done = list.where((a) => _cards[s]?[a.id]?.isDone ?? false).length;
    return (done, list.length);
  }

  /// 卡片部件变更入口：交互器调用，统一持久化 + 广播。
  void updateCard(PeriodScope s, int id, void Function(CardState st) mutator) {
    final st = cardState(s, id);
    mutator(st);
    _persistScope(s);
    notifyListeners();
  }

  /// 一键完成 / 重置（用于快捷打卡）。
  void toggleDone(PeriodScope s, int id, bool done) {
    final st = cardState(s, id);
    if (done) {
      st.doneParts.add('__done__');
      st.completionRatio = 1;
    } else {
      st.doneParts.clear();
      st.completionRatio = 0;
    }
    _persistScope(s);
    notifyListeners();
  }

  /// 每日连击打卡（跨天自然续接，不惩罚断签——只记录）。
  void checkinStreak(int id, DateTime now) {
    final today = _dayKey(now);
    final next =
        _streaks[id]?.bump(today) ?? StreakState(lastDay: today, days: 1);
    _streaks[id] = next;
    prefs.setString(
      'kStreak.$id',
      jsonEncode({'lastDay': next.lastDay, 'days': next.days}),
    );
    notifyListeners();
  }

  /// 记录窗口期锚点（首次交互时落锚）。
  DateTime ensureWindowAnchor(int id, DateTime now) {
    return _windowAnchors.putIfAbsent(id, () {
      prefs.setString('kWindow.$id', now.toIso8601String());
      return now;
    });
  }

  // ---------- 持久化 ----------
  void _persistScope(PeriodScope s) {
    final map = <String, String>{};
    _cards[s]?.forEach((id, st) => map['$id'] = jsonEncode(st.toJson()));
    prefs.setString('kScope.${s.name}', jsonEncode(map));
    final epoch = _scopeEpochKey(s, DateTime.now());
    prefs.setString('kScopeEpoch.${s.name}', epoch);
    _lastScopeEpochs[s] = epoch;
  }

  Future<void> restore() async {
    final mode = prefs.getString('kThemeMode');
    if (mode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      );
    }
    final completed = prefs.getBool('kHasCompletedOnboarding') ?? false;
    final p = prefs.getString('kProfile');
    if (p != null) {
      try {
        _profile = UserProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
        _hasProfile = completed;
      } catch (_) {
        _hasProfile = false;
      }
    } else {
      _hasProfile = false;
    }

    final todosRaw = prefs.getString('kUserTodos');
    if (todosRaw != null) {
      try {
        final list = jsonDecode(todosRaw) as List;
        _userTodos.clear();
        for (final item in list) {
          _userTodos.add(UserTodoItem.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    _seniorMode = prefs.getBool('kSeniorMode') ?? false;

    final exList = prefs.getStringList('kExcludedAdviceIds');
    if (exList != null) {
      _excludedAdviceIds.clear();
      for (final s in exList) {
        final id = int.tryParse(s);
        if (id != null) _excludedAdviceIds.add(id);
      }
    }

    _excludedTopicPaths.clear();
    for (final path
        in prefs.getStringList('kExcludedTopicPaths') ?? <String>[]) {
      // Ignore removed/unknown taxonomy nodes instead of pruning unrelated content.
      if (catalog.topics.byPath.containsKey(path)) {
        _excludedTopicPaths.add(path);
      }
    }

    final fhList = prefs.getStringList('kFormedHabits');
    if (fhList != null) {
      _formedHabits.clear();
      for (final s in fhList) {
        final id = int.tryParse(s);
        if (id != null) _formedHabits.add(id);
      }
    }
    final fhDatesJson = prefs.getString('kFormedHabitDates');
    if (fhDatesJson != null) {
      try {
        final map = jsonDecode(fhDatesJson) as Map<String, dynamic>;
        _formedHabitDates.clear();
        map.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null && v is String) {
            _formedHabitDates[id] = v;
          }
        });
      } catch (_) {}
    }

    final trRaw = prefs.getString('kCustomTriggers');
    if (trRaw != null) {
      try {
        final map = jsonDecode(trRaw) as Map<String, dynamic>;
        _customTriggers.clear();
        map.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null) {
            _customTriggers[id] = CustomTriggerConfig.fromJson(
              jsonDecode(v as String) as Map<String, dynamic>,
            );
          }
        });
      } catch (_) {}
    }

    final p90Raw = prefs.getString('kNinetyDayPlan');
    if (p90Raw != null) {
      try {
        _ninetyDayPlan = NinetyDayPlan.fromJson(
          jsonDecode(p90Raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final revRaw = prefs.getString('kCarnegieReviews');
    if (revRaw != null) {
      try {
        final list = jsonDecode(revRaw) as List;
        _carnegieReviews.clear();
        for (final item in list) {
          _carnegieReviews.add(
            CarnegieReviewItem.fromJson(item as Map<String, dynamic>),
          );
        }
      } catch (_) {}
    }

    final emRaw = prefs.getString('kEmergencyContacts');
    if (emRaw != null) {
      try {
        final list = jsonDecode(emRaw) as List;
        _emergencyContacts.clear();
        for (final item in list) {
          _emergencyContacts.add(
            EmergencyContact.fromJson(item as Map<String, dynamic>),
          );
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    for (final s in PeriodScope.values) {
      final currentEpoch = _scopeEpochKey(s, now);
      final savedEpoch = prefs.getString('kScopeEpoch.${s.name}');
      if (savedEpoch != null && savedEpoch != currentEpoch) {
        // 跨周期：自然清空该周期的打卡记录，不将旧周期的打卡带入新周期
        prefs.remove('kScope.${s.name}');
        prefs.setString('kScopeEpoch.${s.name}', currentEpoch);
        _lastScopeEpochs[s] = currentEpoch;
        continue;
      }
      _lastScopeEpochs[s] = savedEpoch ?? currentEpoch;
      final raw = prefs.getString('kScope.${s.name}');
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          _cards[s]?[int.parse(e.key)] = CardState.fromJson(
            jsonDecode(e.value as String) as Map<String, dynamic>,
          );
        }
      } catch (_) {}
    }
    for (final key in prefs.getKeys()) {
      if (key.startsWith('kStreak.')) {
        final id = int.tryParse(key.substring(8));
        final raw = prefs.getString(key);
        if (id != null && raw != null) {
          try {
            final m = jsonDecode(raw) as Map<String, dynamic>;
            _streaks[id] = StreakState(
              lastDay: m['lastDay'] as String,
              days: m['days'] as int,
            );
          } catch (_) {}
        }
      } else if (key.startsWith('kWindow.')) {
        final id = int.tryParse(key.substring(8));
        final raw = prefs.getString(key);
        if (id != null && raw != null) {
          final dt = DateTime.tryParse(raw);
          if (dt != null) _windowAnchors[id] = dt;
        }
      }
    }
    syncReminderRegistry();
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------- 画像过滤 ----------
  /// 画像专属：人生阶段 ∩ 社会角色 ∩ 适用群体，且不命中排除维度。
  bool matchPersona(Advice a, {bool includeTopicPreferences = true}) {
    final p = profile;
    if (includeTopicPreferences && !matchesTopicPreferences(a)) return false;

    // 0. 关注领域过滤（若设置了特定关注领域且未全选）
    if (p.focusDomains.isNotEmpty && p.focusDomains.length < 6) {
      final domain = LifeDomain.ofChapter(a.chapter);
      if (!p.focusDomains.contains(domain.id)) return false;
    }

    // 0.5 树节点画像前置守卫 (Prerequisites Gating)
    final prereqs = a.prerequisites;
    if (prereqs.isNotEmpty) {
      if (prereqs['has_car'] == true && !p.hasCar) return false;
      if (prereqs['has_twowheeler'] == true && !p.hasTwowheeler) return false;
      if (prereqs['is_smoker'] == true && !p.isSmoker) return false;
      if (prereqs['has_children'] == true &&
          !p.hasChildren &&
          !p.roles.contains('家长') &&
          !p.roles.contains('准父母')) {
        return false;
      }
      if (prereqs['is_pregnant_or_parent'] == true &&
          !p.hasChildren &&
          !p.roles.contains('孕产') &&
          !p.roles.contains('准父母') &&
          !p.roles.contains('家长')) {
        return false;
      }
      if (prereqs['has_aging_parents'] == true &&
          !p.hasAgingParents &&
          !p.livingConditions.contains('家有老人') &&
          !p.roles.contains('照护者')) {
        return false;
      }
      if (prereqs['is_tenant'] == true &&
          !p.isTenant &&
          !p.livingConditions.contains('租房人')) {
        return false;
      }
      if (prereqs['has_mortgage'] == true &&
          !p.hasMortgage &&
          !p.livingConditions.contains('购房人')) {
        return false;
      }
      if (prereqs['has_pets'] == true &&
          !p.hasPets &&
          !p.livingConditions.contains('养犬人')) {
        return false;
      }
      if (prereqs['has_piped_gas'] == true && !p.hasPipedGas) return false;
      if (prereqs['is_entrepreneur'] == true &&
          !p.isEntrepreneur &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('合伙人')) {
        return false;
      }
      if (prereqs['gender_female'] == true && p.gender != '女') return false;
      if (prereqs['gender_male'] == true && p.gender != '男') return false;
      if (prereqs['min_age'] is int && p.age < (prereqs['min_age'] as int)) {
        return false;
      }
    }

    // 0.6 慢性病与特殊病理史强门禁 (Condition Strong Gating)
    // 凡涉及特定确诊疾病、慢性病或特殊病理史的条目，一票否决「全民/通用」穿透特权
    final text = '${a.title} ${a.tags.join(" ")} ${a.chapter}';
    final hasChronic = a.tags.contains('确诊慢病') ||
        a.tags.contains('慢性病') ||
        a.chapter == '得了慢性病之后怎么活' ||
        a.chapter == '残疾之后怎么活';

    if (hasChronic ||
        text.contains('肾结石') ||
        text.contains('痛风') ||
        text.contains('高尿酸')) {
      if (text.contains('肾结石')) {
        if (!p.hasKidneyStones && !p.healthConcerns.contains('肾结石')) {
          return false;
        }
      }
      if (text.contains('痛风') || text.contains('高尿酸')) {
        if (!p.hasGout && !p.healthConcerns.contains('痛风')) {
          return false;
        }
      }
      if (text.contains('高血压') || (text.contains('血压') && hasChronic)) {
        if (!p.hasHypertension && !p.healthConcerns.contains('血压关注')) {
          return false;
        }
      }
      if (text.contains('糖尿病') ||
          text.contains('血糖') ||
          text.contains('胰岛素')) {
        if (!p.hasDiabetes && !p.healthConcerns.contains('血糖关注')) {
          return false;
        }
      }
      if (a.chapter == '残疾之后怎么活' ||
          a.tags.contains('残疾') ||
          a.tags.contains('残障人士')) {
        if (!p.roles.contains('残障人士') &&
            !p.healthConcerns.contains('残疾照护')) {
          return false;
        }
      }
      // 如果属于《得了慢性病之后怎么活》且用户未勾选慢病关注，默认拦截
      if (a.chapter == '得了慢性病之后怎么活' &&
          !p.hasHypertension &&
          !p.hasDiabetes &&
          !p.hasKidneyStones &&
          !p.hasGout &&
          !p.healthConcerns.contains('确诊慢病')) {
        return false;
      }
    }

    // 1. 硬性排除
    if (a.tags.any(p.exclude.contains)) return false;

    // 女性专属硬条件
    if (p.gender != '女' && a.tags.contains('女性健康')) return false;

    // 2. 年龄阶段匹配：若建议包含阶段标签（少年/青年/中年/老年），必须与用户阶段有交集
    final stageTags = const ['少年', '青年', '中年', '老年'];
    final adviceStages = a.tags.where(stageTags.contains).toList();
    if (adviceStages.isNotEmpty && !adviceStages.any(p.stages.contains)) {
      return false;
    }

    // 3. 角色与群体匹配：建议若包含特定角色标签，且非全民通用，则检查用户是否具备该角色
    final specificRoleTags = const [
      '程序员',
      '创业者',
      '学生',
      '求职者',
      '家长',
      '准父母',
      '孕产',
      '照护者',
      '家有老人',
      '残障人士',
      '租房人',
      '购房人',
      '司机',
      '出境者',
      '灵活就业者',
      '雇主',
      '合伙人',
    ];
    final adviceSpecificRoles = a.tags
        .where(specificRoleTags.contains)
        .toList();
    if (adviceSpecificRoles.isNotEmpty) {
      final userAllRoles = {
        ...p.roles,
        ...p.livingConditions,
        ...p.healthConcerns,
      };
      final isGeneric =
          !hasChronic && (a.tags.contains('全民') || a.tags.contains('通用'));
      final matchesUserRole = adviceSpecificRoles.any(userAllRoles.contains);
      if (!isGeneric && !matchesUserRole) {
        return false;
      }
    }

    return true;
  }

  /// 健康节点包条目的硬条件求值（性别 / 年龄），不通过则不渲染。
  ({bool show, String? reason, String? note}) evalNodeItem(NodePackageItem it) {
    final p = profile;
    if (it.female && p.gender != '女') {
      return (show: false, reason: '女性专属 · 已按画像过滤', note: null);
    }
    if (it.bone) {
      if (p.gender == '女' && p.age >= 65) {
        return (show: true, reason: null, note: null);
      }
      if (p.gender == '男' && p.age >= 70) {
        return (
          show: true,
          reason: null,
          note: '70 岁以上男性（中国指南）· 条件谓词动态求值后重新出现',
        );
      }
      return (show: false, reason: '适用：女性 65+ / 男性 70+ · 已按画像过滤', note: null);
    }
    return (show: true, reason: null, note: null);
  }
}
