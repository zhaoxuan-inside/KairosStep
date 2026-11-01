import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/advice_identity.dart';
import '../domain/checkin_engine.dart';
import '../domain/gatekeeper_engine.dart';
import '../domain/semantic_search_engine.dart';
import '../domain/stream_engine.dart';
import '../domain/trigger_engine.dart';
import '../models/advice.dart';
import '../models/topic_tree.dart';
import '../data/catalog.dart';
import '../domain/probe_engine.dart';
import '../domain/reminder_engine.dart';
import '../infra/notifications/mobile_notification_service.dart';

// 建议身份与周期作用域迁移后的兼容导出（存量 import app_store 的引用方零改动）
export '../domain/advice_identity.dart' show adviceIdAliases, canonicalAdviceId;
export '../models/trigger.dart' show PeriodScope;

/// 全局应用状态门面（Phase 3 瘦身）：
/// 装配领域引擎（Trigger/Gatekeeper/Checkin/Stream）、持有用户会话状态
/// （画像/排除/习惯/待办/90 天计划/复盘/联系人）并负责 SharedPreferences 持久化。
/// 引擎逻辑见 lib/domain/*；本类不再承载任何引擎判定逻辑。
///
/// 全部数据仅落在本地 SharedPreferences，不上云、不联网。
class AppStore extends ChangeNotifier implements CheckinPersistence {
  AppStore(this.catalog, this.prefs, {ThemeMode mode = ThemeMode.system})
    : _themeMode = mode;

  final Catalog catalog;
  final SharedPreferences prefs;

  // ── 领域引擎装配（依赖规则见 docs/refactor/ARCHITECTURE.md §2） ──

  /// 通知推送引擎——应用内弹窗出口（打卡完成经 CheckinEngine，广播经 onStoreChange）
  late final ReminderEngine reminderRegistry = ReminderEngine(
    catalog: catalog,
    trigger: triggerEngine,
    checkin: checkinEngine,
    onStoreChange: notifyListeners,
  );

  /// 移动端系统通知通道（NotificationSink 的系统实现）
  late final MobileNotificationService mobileNotificationService =
      MobileNotificationService();

  /// 主动探测引擎（限频/静默/窗口配置来自 L7 engines.json）
  late final ProbeEngine probeScheduler = ProbeEngine(
    mobileNotificationService,
    catalog.engines.probe,
    probes: catalog.probes,
  );

  /// 触发计算引擎：默认推断 + 自定义覆盖（持久化回调写 kCustomTriggers）
  late final TriggerEngine triggerEngine = TriggerEngine(
    catalog,
    onPersist: _persistCustomTriggers,
  );

  /// 建议筛选门禁引擎（matchPersona / evalNodeItem）
  late final GatekeeperEngine gatekeeperEngine = GatekeeperEngine(catalog);

  /// 打卡状态引擎（持久化经 CheckinPersistence Port，本类为实现方）
  late final CheckinEngine checkinEngine = CheckinEngine(this);

  /// 建议流引擎（今日/周期/当下三流，用户态经 StreamInputs 快照注入）
  late final StreamEngine streamEngine = StreamEngine(
    catalog: catalog,
    trigger: triggerEngine,
    gatekeeper: gatekeeperEngine,
    checkin: checkinEngine,
  );

  /// 语义混合检索引擎（feature flag：engines.json semantic.enabled；不可用自动词法兜底）
  late final SemanticSearchEngine semanticSearch = SemanticSearchEngine(
    catalog,
    catalog.embeddingManifest,
  );

  StreamInputs _streamInputs() => StreamInputs(
    excludedIds: Set<int>.from(_excludedAdviceIds),
    topicAllowed: matchesTopicPreferences,
    formedHabitIds: Set<int>.from(_formedHabits),
    profile: _profile,
    userTodos: List<UserTodoItem>.from(_userTodos),
  );

  /// 同步当前活跃防线至提醒注册器与主动探测调度器（零全盘扫描开销，仅注册剪枝后的活跃条目）
  void syncReminderRegistry() {
    final active = todayAdvices;
    reminderRegistry.registerActiveReminders(active);
    probeScheduler.registerAdvices(active, profile);
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

  bool isExcluded(int id) => _excludedAdviceIds.contains(canonicalAdviceId(id));

  /// 排除某条建议（不进日常所有流）
  void excludeAdvice(int id) {
    _excludedAdviceIds.add(canonicalAdviceId(id));
    _persistExcluded();
    notifyListeners();
  }

  /// 恢复某条被排除的建议
  void restoreAdvice(int id) {
    _excludedAdviceIds.remove(canonicalAdviceId(id));
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
  bool isHabitFormed(int id) => _formedHabits.contains(canonicalAdviceId(id));
  String? habitFormedDate(int id) => _formedHabitDates[canonicalAdviceId(id)];

  /// 标记某项建议已成为习惯：从今日/当下待办中剪枝移出，沉淀为生活防线，并联动演进用户画像
  void markHabitFormed(int id, {DateTime? date}) {
    id = canonicalAdviceId(id);
    final now = date ?? DateTime.now();
    _formedHabits.add(id);
    _formedHabitDates[id] = CheckinEngine.dayKey(now);
    _persistFormedHabits();
    _evolveProfileByHabit(id);
    notifyListeners();
  }

  /// 重新带我练习一周（当用户生活节奏被打乱松懈时，温和恢复至今日待办）
  void relearnHabit(int id) {
    id = canonicalAdviceId(id);
    _formedHabits.remove(id);
    _formedHabitDates.remove(id);
    _persistFormedHabits();

    _profile = _profile.copyWith(formedHabits: _formedHabits.toList());
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

  /// 根据已养成的建议演化用户画像特质（规则数据化于 L7 gates.json habitEvolution）
  void _evolveProfileByHabit(int adviceId) {
    adviceId = canonicalAdviceId(adviceId);
    var p = _profile;
    final nextFormed = Set<int>.from(p.formedHabits)..add(adviceId);

    for (final rule in catalog.gates.habitEvolution) {
      if (!rule.matches(adviceId)) continue;
      final nextHealth = Set<String>.from(p.healthConcerns)
        ..removeAll(rule.removeConcerns)
        ..addAll(rule.addConcerns);
      p = p.copyWith(
        isSmoker: rule.clearFlags.contains('isSmoker') ? false : null,
        hasHypertension: rule.clearFlags.contains('hasHypertension')
            ? false
            : null,
        healthConcerns: nextHealth.toList(),
      );
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
  }

  // ---------- 建议自定义触发方式与触发周期（TriggerEngine 门面） ----------
  CustomTriggerConfig? triggerConfigOf(int id) =>
      triggerEngine.triggerConfigOf(id);

  /// 获取建议生效的触发配置（有自定义取自定义，否则推断原生默认）
  CustomTriggerConfig effectiveTriggerOf(Advice a) =>
      triggerEngine.effectiveTriggerOf(a);

  /// 设置自定义触发方式与周期
  void setTriggerConfig(int id, CustomTriggerConfig cfg) {
    triggerEngine.set(id, cfg);
    syncReminderRegistry();
    notifyListeners();
  }

  /// 恢复系统默认触发与周期
  void resetTriggerConfig(int id) {
    triggerEngine.reset(id);
    syncReminderRegistry();
    notifyListeners();
  }

  void _persistCustomTriggers() {
    final map = <String, String>{};
    triggerEngine.customTriggers.forEach((id, cfg) {
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
    oldId = canonicalAdviceId(oldId);
    newId = canonicalAdviceId(newId);
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
    String? content,
    String? triggerTime,
    String timePeriod = 'all_day',
    List<String> reminderTimes = const [],
    int leadMinutes = 0,
    String frequency = 'daily',
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
      content: content,
      triggerTime: triggerTime,
      timePeriod: timePeriod,
      reminderTimes: reminderTimes,
      leadMinutes: leadMinutes,
      frequency: frequency,
    );
    addUserTodoItem(item);
  }

  /// 添加完整的 UserTodoItem 并自动注册时点提醒
  void addUserTodoItem(UserTodoItem item) {
    _userTodos.insert(0, item);
    _persistUserTodos();

    // 自动向提醒注册表注册待办时点提醒
    if (item.reminderTimes.isNotEmpty) {
      final advice = item.toAdvice();
      triggerEngine.customTriggers[advice.id] = CustomTriggerConfig(
        mode: TriggerMode.daily,
        reminderTimes: item.reminderTimes,
      );
      _persistCustomTriggers();
      syncReminderRegistry();
    }

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

  // ---------- 打卡状态（CheckinEngine 门面） ----------
  Map<int, CardState> cardsOf(PeriodScope s) => checkinEngine.cardsOf(s);

  CardState cardState(PeriodScope s, int id) => checkinEngine.cardState(s, id);

  StreakState streakOf(int id) => checkinEngine.streakOf(id);

  DateTime? windowAnchorOf(int id) => checkinEngine.windowAnchorOf(id);

  /// 卡片部件变更入口：交互器调用，统一持久化 + 广播。
  void updateCard(PeriodScope s, int id, void Function(CardState st) mutator) {
    checkinEngine.updateCard(s, id, mutator);
    notifyListeners();
  }

  /// 一键完成 / 重置（用于快捷打卡）。
  void toggleDone(PeriodScope s, int id, bool done) {
    checkinEngine.toggleDone(s, id, done);
    notifyListeners();
  }

  /// 每日连击打卡，按日历日期维护连续天数。
  void checkinStreak(int id, DateTime now) {
    checkinEngine.checkinStreak(id, now);
    notifyListeners();
  }

  /// 记录窗口期锚点（首次交互时落锚）。
  DateTime ensureWindowAnchor(int id, DateTime now) =>
      checkinEngine.ensureWindowAnchor(id, now);

  /// 周期跨期检测（委托打卡引擎）。
  void checkPeriodRollover([DateTime? customNow]) =>
      checkinEngine.checkPeriodRollover(customNow);

  /// 某作用域的完成数 / 总数（动态根据真实建议统计，零写死 Mock）。
  (int, int) countersOf(PeriodScope s) =>
      checkinEngine.countersOf(s, cycleAdvicesOf(s));

  // ---------- 建议流（StreamEngine 门面） ----------

  /// 真实动态今天待办流（严格准入，包含今日有效自建待办，当下 ⊆ 今天）
  List<Advice> get todayAdvices => streamEngine.todayAdvices(_streamInputs());

  /// 真实动态周期流（层级严格包含：今天 ⊆ 本周 ⊆ 本月）
  List<Advice> cycleAdvicesOf(PeriodScope scope) =>
      streamEngine.cycleAdvicesOf(_streamInputs(), scope);

  /// 根据聚焦视窗动态筛选属于该视窗的建议流（当下 ⊆ 今天；窗口与加权来自 L7）
  List<Advice> advicesForWindow(DateTime centerTime) =>
      streamEngine.advicesForWindow(_streamInputs(), centerTime);

  /// 真实动态时段建议流（严格准入：绝不塞入无明确时段的偶发建议；存量测试消费）
  List<Advice> periodAdvicesOf(String periodKey) =>
      streamEngine.periodAdvicesOf(_streamInputs(), periodKey, DateTime.now());

  /// 全量应急/急救/突发处置条目（供紧急面板或突发模式使用，如中暑、骨折、海姆立克等）
  List<Advice> get emergencyAdvices => streamEngine.emergencyAdvices();

  // ---------- 画像过滤（GatekeeperEngine 门面） ----------
  /// 画像专属：人生阶段 ∩ 社会角色 ∩ 适用群体，且不命中排除维度。
  bool matchPersona(Advice a, {bool includeTopicPreferences = true}) =>
      gatekeeperEngine.matchPersona(
        a,
        profile: _profile,
        topicFilter: matchesTopicPreferences,
        includeTopicPreferences: includeTopicPreferences,
      );

  /// 健康节点包条目的硬条件求值（性别 / 年龄），不通过则不渲染。
  ({bool show, String? reason, String? note}) evalNodeItem(NodePackageItem it) =>
      gatekeeperEngine.evalNodeItem(it, _profile);

  // ---------- 打卡持久化 Port 实现（state 层写 SharedPreferences，键名冻结） ----------
  @override
  void persistScope(
    PeriodScope scope,
    Map<int, CardState> cards,
    String epoch,
  ) {
    final map = <String, String>{};
    cards.forEach((id, st) => map['$id'] = jsonEncode(st.toJson()));
    prefs.setString('kScope.${scope.name}', jsonEncode(map));
    prefs.setString('kScopeEpoch.${scope.name}', epoch);
  }

  @override
  void clearScope(PeriodScope scope, String newEpoch) {
    prefs.remove('kScope.${scope.name}');
    prefs.setString('kScopeEpoch.${scope.name}', newEpoch);
  }

  @override
  void persistEpoch(PeriodScope scope, String epoch) =>
      prefs.setString('kScopeEpoch.${scope.name}', epoch);

  @override
  void persistStreak(int id, StreakState streak) => prefs.setString(
    'kStreak.$id',
    jsonEncode({'lastDay': streak.lastDay, 'days': streak.days}),
  );

  @override
  void persistWindowAnchor(int id, DateTime at) =>
      prefs.setString('kWindow.$id', at.toIso8601String());

  // ---------- 恢复 ----------
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
        _profile = _profile.copyWith(
          formedHabits: _profile.formedHabits.map(canonicalAdviceId).toList(),
        );
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
        if (id != null) _excludedAdviceIds.add(canonicalAdviceId(id));
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
        if (id != null) _formedHabits.add(canonicalAdviceId(id));
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
            _formedHabitDates[canonicalAdviceId(id)] = v;
          }
        });
      } catch (_) {}
    }

    final trRaw = prefs.getString('kCustomTriggers');
    if (trRaw != null) {
      try {
        final map = jsonDecode(trRaw) as Map<String, dynamic>;
        final restored = <int, CustomTriggerConfig>{};
        map.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null) {
            restored[canonicalAdviceId(
              id,
            )] = CustomTriggerConfig.fromJson(
              jsonDecode(v as String) as Map<String, dynamic>,
            );
          }
        });
        triggerEngine.restoreFrom(restored);
      } catch (_) {}
    }

    final p90Raw = prefs.getString('kNinetyDayPlan');
    if (p90Raw != null) {
      try {
        final plan = NinetyDayPlan.fromJson(
          jsonDecode(p90Raw) as Map<String, dynamic>,
        );
        _ninetyDayPlan = plan.copyWith(
          goalAdviceIds: plan.goalAdviceIds.map(canonicalAdviceId).toList(),
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
      final currentEpoch = CheckinEngine.scopeEpochKey(s, now);
      final savedEpoch = prefs.getString('kScopeEpoch.${s.name}');
      if (savedEpoch != null && savedEpoch != currentEpoch) {
        // 跨周期：自然清空该周期的打卡记录，不将旧周期的打卡带入新周期
        prefs.remove('kScope.${s.name}');
        prefs.setString('kScopeEpoch.${s.name}', currentEpoch);
        checkinEngine.restoreEpoch(s, currentEpoch);
        continue;
      }
      checkinEngine.restoreEpoch(s, savedEpoch ?? currentEpoch);
      final raw = prefs.getString('kScope.${s.name}');
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          checkinEngine.restoreScopeCard(
            s,
            canonicalAdviceId(int.parse(e.key)),
            CardState.fromJson(
              jsonDecode(e.value as String) as Map<String, dynamic>,
            ),
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
            checkinEngine.restoreStreak(
              canonicalAdviceId(id),
              StreakState(lastDay: m['lastDay'] as String, days: m['days'] as int),
            );
          } catch (_) {}
        }
      } else if (key.startsWith('kWindow.')) {
        final id = int.tryParse(key.substring(8));
        final raw = prefs.getString(key);
        if (id != null && raw != null) {
          final dt = DateTime.tryParse(raw);
          if (dt != null) {
            checkinEngine.restoreWindowAnchor(canonicalAdviceId(id), dt);
          }
        }
      }
    }
    syncReminderRegistry();
  }
}
