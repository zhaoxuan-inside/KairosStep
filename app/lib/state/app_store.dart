import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog.dart';
import '../models/advice.dart';

/// 周期作用域：打卡记录天然按周期归零（今天跨天清空、周/月/年各自滚动）。
enum PeriodScope { today, weekly, monthly, yearly }

PeriodScope scopeFromKey(String key) =>
    PeriodScope.values.firstWhere((s) => s.name == key, orElse: () => PeriodScope.today);

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
  });

  final String gender;
  final int age;
  final List<String> roles;
  final List<String> livingConditions;
  final List<String> healthConcerns;
  final List<String> focusDomains; // 关注的人生领域，默认 6 大支柱全覆盖
  final bool prunedOnly; // 全景库默认「画像专属」
  final bool parentsOnly; // 父母适用清单

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
  }) =>
      UserProfile(
        gender: gender ?? this.gender,
        age: age ?? this.age,
        roles: roles ?? this.roles,
        livingConditions: livingConditions ?? this.livingConditions,
        healthConcerns: healthConcerns ?? this.healthConcerns,
        focusDomains: focusDomains ?? this.focusDomains,
        prunedOnly: prunedOnly ?? this.prunedOnly,
        parentsOnly: parentsOnly ?? this.parentsOnly,
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
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        gender: json['gender'] as String? ?? '男',
        age: json['age'] as int? ?? 28,
        roles: (json['roles'] as List?)?.cast<String>() ??
            const ['全民', '上班族', '伴侣', '家人'],
        livingConditions: (json['livingConditions'] as List?)?.cast<String>() ??
            const ['租房人'],
        healthConcerns: (json['healthConcerns'] as List?)?.cast<String>() ??
            const ['久坐伏案'],
        focusDomains: (json['focusDomains'] as List?)?.cast<String>() ??
            const [
              'health',
              'career',
              'family',
              'finance',
              'emergency',
              'cadence',
            ],
        prunedOnly: json['prunedOnly'] as bool? ?? true,
        parentsOnly: json['parentsOnly'] as bool? ?? false,
      );

  String get label =>
      '$age 岁 · $gender · ${roles.where((r) => r != '全民').take(3).join('/')}';
}

/// 父母适用清单（人工复核，来源 HowToLiveBetterFor35Dev.md，139 条）。
const List<int> parentsAdviceIds = [
  13, 20, 22, 37, 40, 58, 111, 138, 153, 232, 233, 259, 264, 342, 397, 398, 399,
  400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414,
  415, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427, 428, 430,
  431, 432, 433, 435, 436, 437, 438, 442, 443, 444, 475, 476, 477, 478, 479,
  480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494,
  495, 496, 497, 498, 499, 501, 560, 614, 615, 616, 617, 618, 619, 620, 621,
  622, 623, 624, 625, 626, 670, 671, 673, 674, 675, 677, 678, 679, 680, 681,
  682, 683, 734, 735, 736, 737, 738, 739, 740, 742, 743, 744, 745, 746, 747,
  748, 749, 750, 751, 752, 753, 754, 755, 757, 760, 761, 762, 763, 764, 765,
  766, 767,
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

  Map<String, dynamic> toJson() => {'p': doneParts.toList(), 'x': extra, 'r': _completionRatio};

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
  AppStore(this.catalog, this.prefs, {ThemeMode mode = ThemeMode.dark})
      : _themeMode = mode;

  final Catalog catalog;
  final SharedPreferences prefs;

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
    notifyListeners();
  }

  bool _hasProfile = false;
  bool get hasProfile => _hasProfile;

  /// 完成初始画像引导并持久化
  void completeOnboarding(UserProfile p) {
    _profile = p;
    _hasProfile = true;
    prefs.setString('kProfile', jsonEncode(p.toJson()));
    prefs.setBool('kHasCompletedOnboarding', true);
    notifyListeners();
  }

  /// 更新画像
  void updateProfile(UserProfile p) {
    _profile = p;
    prefs.setString('kProfile', jsonEncode(p.toJson()));
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

  // ---------- 建议自定义触发方式与触发周期 (Custom Triggers) ----------
  final Map<int, CustomTriggerConfig> _customTriggers = {};

  CustomTriggerConfig? triggerConfigOf(int id) => _customTriggers[id];

  /// 获取建议生效的触发配置（有自定义取自定义，否则推断原生默认）
  CustomTriggerConfig effectiveTriggerOf(Advice a) {
    if (_customTriggers.containsKey(a.id)) {
      return _customTriggers[a.id]!;
    }
    // 原生推断
    if (a.tags.contains('每天') || a.tags.contains('每日多次')) {
      final periods = <String>[];
      final text = '${a.title} ${a.tags.join(" ")} ${a.timingBadge}';
      if (['出发', '早餐', '晨', '安全带', '头盔', '步行'].any(text.contains)) periods.add('morning');
      if (['工作', '工位', '久坐', '专注', '单线程'].any(text.contains)) periods.add('focus');
      if (['午后', '站立', '远眺', '喝茶', '快走', '舒展'].any(text.contains)) periods.add('afternoon');
      if (['归途', '晚餐', '家人', '沟通'].any(text.contains)) periods.add('evening');
      if (['睡眠', '屏幕', '夜里', '褪黑素', '安稳'].any(text.contains)) periods.add('night');
      if (periods.isEmpty) periods.add('morning');
      return CustomTriggerConfig(mode: TriggerMode.daily, dailyPeriods: periods);
    }
    if (a.tags.contains('每周')) {
      return const CustomTriggerConfig(mode: TriggerMode.cadence, cadenceScopeKey: 'weekly');
    }
    if (a.tags.contains('每月')) {
      return const CustomTriggerConfig(mode: TriggerMode.cadence, cadenceScopeKey: 'monthly');
    }
    if (a.tags.contains('每年') || a.tags.contains('筛查') || a.tags.contains('日历时点')) {
      return const CustomTriggerConfig(mode: TriggerMode.cadence, cadenceScopeKey: 'yearly');
    }
    // 其余均属于未明确触发日期的静默储备态
    return const CustomTriggerConfig(mode: TriggerMode.dormant);
  }

  /// 设置自定义触发方式与周期
  void setTriggerConfig(int id, CustomTriggerConfig cfg) {
    _customTriggers[id] = cfg;
    _persistCustomTriggers();
    notifyListeners();
  }

  /// 恢复系统默认触发与周期
  void resetTriggerConfig(int id) {
    _customTriggers.remove(id);
    _persistCustomTriggers();
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
  List<CarnegieReviewItem> get carnegieReviews => List.unmodifiable(_carnegieReviews);

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
  List<EmergencyContact> get emergencyContacts => List.unmodifiable(_emergencyContacts);

  void addEmergencyContact(String name, String phone, String relation) {
    _emergencyContacts.add(EmergencyContact(name: name, phone: phone, relation: relation));
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
  void addUserTodo(String title, {int? adviceId, String? note, String? targetDate}) {
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
      _userTodos[idx] = _userTodos[idx].copyWith(isDone: !_userTodos[idx].isDone);
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

  // adviceId → StreakState（跨周期属于习惯本体）
  final Map<int, StreakState> _streaks = {};

  // 窗口期锚点：adviceId → 首次浮出日（决定窗口进度）
  final Map<int, DateTime> _windowAnchors = {};

  Map<int, CardState> cardsOf(PeriodScope s) => _cards[s] ?? {};

  CardState cardState(PeriodScope s, int id) =>
      _cards[s]![id] ??= CardState();

  StreakState streakOf(int id) => _streaks[id] ?? const StreakState();
  DateTime? windowAnchorOf(int id) => _windowAnchors[id];

  /// 真实动态今天待办流（严格准入：绝不塞入无明确日期的偶发建议）
  List<Advice> get todayAdvices {
    return catalog.adviceList.where((a) {
      if (isExcluded(a.id)) return false;
      if (_profile.prunedOnly && !matchPersona(a)) return false;

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
          final diff = target.difference(DateTime(now.year, now.month, now.day)).inDays;
          return diff >= 0 && diff <= trig.leadDays;
        case TriggerMode.cadence:
          return false; // 周期循环态在周期页查看，不直接占位今日流
      }
    }).toList();
  }

  /// 真实动态周期流（严格准入：绝不塞入无明确周期的偶发建议）
  List<Advice> cycleAdvicesOf(PeriodScope scope) {
    return catalog.adviceList.where((a) {
      if (isExcluded(a.id)) return false;
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
  }

  /// 真实动态时段建议流（严格准入：绝不塞入无明确时段的偶发建议）
  List<Advice> periodAdvicesOf(String periodKey) {
    final list = catalog.adviceList.where((a) {
      if (isExcluded(a.id)) return false;
      if (_profile.prunedOnly && !matchPersona(a)) return false;

      final trig = effectiveTriggerOf(a);
      if (trig.mode == TriggerMode.dormant || trig.mode == TriggerMode.cadence) {
        return false; // 严禁进入时钟时段流
      }

      if (trig.mode == TriggerMode.daily) {
        return trig.dailyPeriods.contains(periodKey);
      }

      if (trig.mode == TriggerMode.windowed && trig.targetDate != null) {
        final target = DateTime.tryParse(trig.targetDate!);
        if (target != null) {
          final now = DateTime.now();
          final diff = target.difference(DateTime(now.year, now.month, now.day)).inDays;
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
        final trig = effectiveTriggerOf(a);
        if (trig.mode != TriggerMode.daily) return false;
        return trig.dailyPeriods.contains(periodKey);
      }).toList();
    }
    return list;
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
    final next = _streaks[id]?.bump(today) ?? StreakState(lastDay: today, days: 1);
    _streaks[id] = next;
    prefs.setString('kStreak.$id', jsonEncode(
        {'lastDay': next.lastDay, 'days': next.days}));
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
  }

  Future<void> restore() async {
    final mode = prefs.getString('kThemeMode');
    if (mode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.dark,
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

    final trRaw = prefs.getString('kCustomTriggers');
    if (trRaw != null) {
      try {
        final map = jsonDecode(trRaw) as Map<String, dynamic>;
        _customTriggers.clear();
        map.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null) {
            _customTriggers[id] =
                CustomTriggerConfig.fromJson(jsonDecode(v as String) as Map<String, dynamic>);
          }
        });
      } catch (_) {}
    }

    final p90Raw = prefs.getString('kNinetyDayPlan');
    if (p90Raw != null) {
      try {
        _ninetyDayPlan =
            NinetyDayPlan.fromJson(jsonDecode(p90Raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    final revRaw = prefs.getString('kCarnegieReviews');
    if (revRaw != null) {
      try {
        final list = jsonDecode(revRaw) as List;
        _carnegieReviews.clear();
        for (final item in list) {
          _carnegieReviews.add(
              CarnegieReviewItem.fromJson(item as Map<String, dynamic>));
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
              EmergencyContact.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    for (final s in PeriodScope.values) {
      final raw = prefs.getString('kScope.${s.name}');
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          _cards[s]?[int.parse(e.key)] =
              CardState.fromJson(jsonDecode(e.value as String) as Map<String, dynamic>);
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
            _streaks[id] =
                StreakState(lastDay: m['lastDay'] as String, days: m['days'] as int);
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
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------- 画像过滤 ----------
  /// 画像专属：人生阶段 ∩ 社会角色 ∩ 适用群体，且不命中排除维度。
  bool matchPersona(Advice a) {
    final p = profile;

    // 0. 关注领域过滤（若设置了特定关注领域且未全选）
    if (p.focusDomains.isNotEmpty && p.focusDomains.length < 6) {
      final domain = LifeDomain.ofChapter(a.chapter);
      if (!p.focusDomains.contains(domain.id)) return false;
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
      '程序员', '创业者', '学生', '求职者', '家长', '准父母', '孕产', '照护者',
      '家有老人', '残障人士', '租房人', '购房人', '司机', '出境者', '灵活就业者',
      '雇主', '合伙人'
    ];
    final adviceSpecificRoles = a.tags.where(specificRoleTags.contains).toList();
    if (adviceSpecificRoles.isNotEmpty) {
      final userAllRoles = {...p.roles, ...p.livingConditions, ...p.healthConcerns};
      final isGeneric = a.tags.contains('全民') || a.tags.contains('通用');
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
      if (p.gender == '女' && p.age >= 65) return (show: true, reason: null, note: null);
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
