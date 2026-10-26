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

  /// 真实动态今天待办流（零 Mock 数据，随画像动态求值）
  List<Advice> get todayAdvices {
    return catalog.adviceList.where((a) {
      final isDaily = a.tags.contains('每天') ||
          a.tags.contains('每日多次') ||
          a.tags.contains('打卡');
      if (!isDaily) return false;
      if (_profile.prunedOnly) {
        return matchPersona(a);
      }
      return true;
    }).toList();
  }

  /// 真实动态周期流（零 Mock 数据）
  List<Advice> cycleAdvicesOf(PeriodScope scope) {
    return catalog.adviceList.where((a) {
      final matchesScope = switch (scope) {
        PeriodScope.today => a.tags.contains('每天') ||
            a.tags.contains('每日多次') ||
            a.tags.contains('打卡'),
        PeriodScope.weekly => a.tags.contains('每周'),
        PeriodScope.monthly => a.tags.contains('每月'),
        PeriodScope.yearly => a.tags.contains('每年') ||
            a.tags.contains('日历时点') ||
            a.tags.contains('筛查'),
      };
      if (!matchesScope) return false;
      if (_profile.prunedOnly) {
        return matchPersona(a);
      }
      return true;
    }).toList();
  }

  /// 真实动态时段建议流（零 Mock 数据）
  List<Advice> periodAdvicesOf(String periodKey) {
    final list = catalog.adviceList.where((a) {
      if (_profile.prunedOnly && !matchPersona(a)) return false;
      final text = '${a.title} ${a.tags.join(" ")} ${a.timingBadge}';
      return switch (periodKey) {
        'morning' => a.tags.any(['在路上', '交通', '安全', '饮食', '打卡'].contains) ||
            ['安全带', '头盔', '出发', '早餐', '步行', '鸡蛋', '果蔬'].any(text.contains),
        'focus' => a.tags.any(['在职场', '职场', '效率', '时间管理', '打卡'].contains) ||
            ['工作', '工位', '久坐', '深度工作', '单线程', '批量收发', '专注'].any(text.contains),
        'afternoon' => a.tags.any(['健康', '运动', '打卡', '日常'].contains) ||
            ['久坐', '远眺', '站立', '喝茶', '运动', '力量训练', '快走', '舒展', '放松'].any(text.contains),
        'evening' => a.tags.any(['家庭', '伴侣', '生活', '在路上', '安全'].contains) ||
            ['归途', '晚餐', '家人', '沟通', '安全带', '复盘'].any(text.contains),
        'night' => a.tags.any(['健康', '日常', '安全'].contains) ||
            ['睡眠', '屏幕', '夜里', '褪黑素', '起床', '安稳', '门锁', '黑暗'].any(text.contains),
        _ => true,
      };
    }).toList();

    if (list.isEmpty) {
      // 兜底保护：当画像极端时，保证至少展现当前时段通用健康/安全条目
      return catalog.adviceList.where((a) {
        final text = '${a.title} ${a.tags.join(" ")} ${a.timingBadge}';
        return switch (periodKey) {
          'morning' => ['安全带', '头盔', '出发', '早餐'].any(text.contains),
          'focus' => ['工作', '工位', '久坐', '效率'].any(text.contains),
          'afternoon' => ['久坐', '远眺', '站立', '快走'].any(text.contains),
          'evening' => ['归途', '家人', '沟通', '安全带'].any(text.contains),
          'night' => ['睡眠', '屏幕', '褪黑素', '安稳'].any(text.contains),
          _ => true,
        };
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
