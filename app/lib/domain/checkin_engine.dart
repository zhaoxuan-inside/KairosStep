// 打卡状态引擎（REFACTOR_DESIGN §5.6）：CardState / 连击 / 周期翻零 / 窗口锚点。
// 自 app_store（原 :1224-1295、:1740-1781 与恢复逻辑）整体迁移，逻辑逐字保留。
// 依赖规则：持久化经 CheckinPersistence Port（state 层实现写 SharedPreferences），
// 本引擎零 prefs/Flutter 依赖，可独立单测。
import '../models/advice.dart';

/// 打卡持久化 Port（state 层实现；键名冻结：kScope.* / kScopeEpoch.* / kStreak.* / kWindow.*）。
abstract class CheckinPersistence {
  /// 整把写某作用域的打卡表 + 纪元键（原 _persistScope）。
  void persistScope(PeriodScope scope, Map<int, CardState> cards, String epoch);

  /// 跨周期清零：移除打卡表并写入新纪元（原 prefs.remove + setString）。
  void clearScope(PeriodScope scope, String newEpoch);

  void persistEpoch(PeriodScope scope, String epoch);

  void persistStreak(int id, StreakState streak);

  void persistWindowAnchor(int id, DateTime at);
}

class CheckinEngine {
  CheckinEngine(this.persistence);

  final CheckinPersistence persistence;

  // scope → (adviceId → CardState)
  final Map<PeriodScope, Map<int, CardState>> _cards = {
    for (final s in PeriodScope.values) s: {},
  };

  // scope → 周期纪元键（今天: yyyy-MM-dd，本周: w_yyyy-MM-dd，本月: m_yyyy-MM，每年: y_yyyy）
  final Map<PeriodScope, String> _lastScopeEpochs = {};

  // adviceId → StreakState（跨周期属于习惯本体）
  final Map<int, StreakState> _streaks = {};

  // 窗口期锚点：adviceId → 首次浮出日（决定窗口进度）
  final Map<int, DateTime> _windowAnchors = {};

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String scopeEpochKey(PeriodScope s, DateTime now) {
    switch (s) {
      case PeriodScope.today:
        return dayKey(now);
      case PeriodScope.weekly:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return 'w_${dayKey(monday)}';
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
      final currentEpoch = scopeEpochKey(s, now);
      final lastEpoch = _lastScopeEpochs[s];
      if (lastEpoch != null && lastEpoch != currentEpoch) {
        _lastScopeEpochs[s] = currentEpoch;
        _cards[s]?.clear();
        persistence.clearScope(s, currentEpoch);
      }
    }
  }

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

  /// 卡片部件变更入口：交互器调用，统一持久化（广播由 store facade 负责）。
  void updateCard(PeriodScope s, int id, void Function(CardState st) mutator) {
    final st = cardState(s, id);
    mutator(st);
    persistScope(s);
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
    persistScope(s);
  }

  /// 每日连击打卡，按日历日期维护连续天数。
  void checkinStreak(int id, DateTime now) {
    final today = dayKey(now);
    final next =
        _streaks[id]?.bump(today) ?? StreakState(lastDay: today, days: 1);
    _streaks[id] = next;
    persistence.persistStreak(id, next);
  }

  /// 记录窗口期锚点（首次交互时落锚）。
  DateTime ensureWindowAnchor(int id, DateTime now) {
    return _windowAnchors.putIfAbsent(id, () {
      persistence.persistWindowAnchor(id, now);
      return now;
    });
  }

  /// 某作用域的完成数 / 总数。
  (int, int) countersOf(PeriodScope s, List<Advice> scopeList) {
    if (scopeList.isEmpty) return (0, 0);
    final done = scopeList
        .where((a) => _cards[s]?[a.id]?.isDone ?? false)
        .length;
    return (done, scopeList.length);
  }

  // ── 恢复（restore() 逐 key 注入；键已规范化） ──

  void restoreEpoch(PeriodScope s, String epoch) =>
      _lastScopeEpochs[s] = epoch;

  void restoreScopeCard(PeriodScope s, int id, CardState st) =>
      _cards[s]?[id] = st;

  void restoreStreak(int id, StreakState st) => _streaks[id] = st;

  void restoreWindowAnchor(int id, DateTime at) => _windowAnchors[id] = at;

  void persistScope(PeriodScope s) {
    final epoch = scopeEpochKey(s, DateTime.now());
    _lastScopeEpochs[s] = epoch;
    persistence.persistScope(s, _cards[s] ?? {}, epoch);
  }
}
