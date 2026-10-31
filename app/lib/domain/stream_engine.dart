// 建议流引擎（REFACTOR_DESIGN §5.3）：今日/周期/当下三流 + 排序（自 app_store
// 原 :1366-1730 整体迁移，逻辑逐字保留）。
// 依赖规则：只依赖 data/、models/ 与同层引擎（Trigger/Gatekeeper/Checkin）；
// 用户会话状态经 [StreamInputs] 快照注入（state 层每次调用前构造），不反向依赖 state。
import '../data/catalog.dart';
import '../models/advice.dart';
import 'checkin_engine.dart';
import 'gatekeeper_engine.dart';
import 'trigger_engine.dart';

/// 建议流的用户态快照（AppStore 每次调用时构造）。
class StreamInputs {
  const StreamInputs({
    required this.excludedIds,
    required this.topicAllowed,
    required this.formedHabitIds,
    required this.profile,
    required this.userTodos,
  });

  final Set<int> excludedIds;
  final bool Function(Advice) topicAllowed; // store.matchesTopicPreferences
  final Set<int> formedHabitIds;
  final UserProfile profile;
  final List<UserTodoItem> userTodos;
}

class StreamEngine {
  const StreamEngine({
    required this.catalog,
    required this.trigger,
    required this.gatekeeper,
    required this.checkin,
  });

  final Catalog catalog;
  final TriggerEngine trigger;
  final GatekeeperEngine gatekeeper;
  final CheckinEngine checkin;

  bool _matchPersona(Advice a, StreamInputs i) => gatekeeper.matchPersona(
    a,
    profile: i.profile,
    topicFilter: i.topicAllowed,
  );

  /// 真实动态今天待办流（严格准入，包含今日有效自建待办，当下 ⊆ 今天）。
  /// [at] 仅用于 windowed 目标日判定（测试可注入）；跨期翻零永远以真实当前时间求值（与原实现一致）。
  List<Advice> todayAdvices(StreamInputs i, [DateTime? at]) {
    checkin.checkPeriodRollover();
    final now = at ?? DateTime.now();

    // 1. 系统实证库中匹配当前画像的日常待办
    final list = catalog.adviceList.where((a) {
      if (i.excludedIds.contains(a.id) || !i.topicAllowed(a)) return false;
      if (i.formedHabitIds.contains(a.id)) {
        return false; // 已养成的习惯剪枝隐退，不再每日反复提醒
      }
      if (i.profile.prunedOnly && !_matchPersona(a, i)) return false;

      // 应急/急救/突发处置建议（如中暑、工伤），除非显式自定义，否则严禁进入今日流
      if (a.isEmergencyOrIncident && !trigger.hasCustom(a.id)) {
        return false;
      }

      final trig = trigger.effectiveTriggerOf(a);
      switch (trig.mode) {
        case TriggerMode.dormant:
          return false; // 静默储备态严禁进入今日流
        case TriggerMode.daily:
          return true;
        case TriggerMode.windowed:
          if (trig.targetDate == null) return false;
          final target = DateTime.tryParse(trig.targetDate!);
          if (target == null) return false;
          final diff = target
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          return diff >= 0 && diff <= trig.leadDays;
        case TriggerMode.cadence:
          return false; // 周期循环态在周期页查看，不直接占位今日流
      }
    }).toList();

    // 2. 融入今日生效的用户自建待办
    for (final todo in i.userTodos) {
      if (todo.isTodayActive(now)) {
        list.add(todo.toAdvice());
      }
    }

    // 已经打卡完成的排在下面（未完成优先置顶，已完成沉底）
    list.sort((a, b) {
      final aDone = checkin.cardState(PeriodScope.today, a.id).isDone ? 1 : 0;
      final bDone = checkin.cardState(PeriodScope.today, b.id).isDone ? 1 : 0;
      return aDone.compareTo(bDone);
    });

    return list;
  }

  /// 真实动态周期流（层级严格包含：今天 ⊆ 本周 ⊆ 本月）
  List<Advice> cycleAdvicesOf(StreamInputs i, PeriodScope scope, [DateTime? at]) {
    if (scope == PeriodScope.today) {
      return todayAdvices(i, at);
    }

    final seenIds = <int>{};
    final list = <Advice>[];

    void addAdvice(Advice a) {
      if (!seenIds.contains(a.id)) {
        seenIds.add(a.id);
        list.add(a);
      }
    }

    bool basePass(Advice a) {
      if (i.excludedIds.contains(a.id) || !i.topicAllowed(a)) return false;
      if (i.formedHabitIds.contains(a.id)) return false;
      if (i.profile.prunedOnly && !_matchPersona(a, i)) return false;
      return true;
    }

    // 包含关系保证：本周/本月/每年必须包含今日待办流
    for (final a in todayAdvices(i, at)) {
      addAdvice(a);
    }

    // 若为本月或每年，必须额外包含每周周期的条目
    if (scope == PeriodScope.monthly || scope == PeriodScope.yearly) {
      final weeklyItems = catalog.adviceList.where((a) {
        if (!basePass(a)) return false;
        final trig = trigger.effectiveTriggerOf(a);
        return trig.mode == TriggerMode.cadence &&
            trig.cadenceScopeKey == 'weekly';
      });
      for (final a in weeklyItems) {
        addAdvice(a);
      }
    }

    // 若为每年，必须额外包含每月周期的条目
    if (scope == PeriodScope.yearly) {
      final monthlyItems = catalog.adviceList.where((a) {
        if (!basePass(a)) return false;
        final trig = trigger.effectiveTriggerOf(a);
        return trig.mode == TriggerMode.cadence &&
            trig.cadenceScopeKey == 'monthly';
      });
      for (final a in monthlyItems) {
        addAdvice(a);
      }
    }

    // 加入当前 scope 本身的周期建议
    final currentScopeItems = catalog.adviceList.where((a) {
      if (!basePass(a)) return false;

      final trig = trigger.effectiveTriggerOf(a);
      switch (trig.mode) {
        case TriggerMode.cadence:
          return trig.cadenceScopeKey == scope.name;
        case TriggerMode.daily:
          return false;
        case TriggerMode.windowed:
          return scope == PeriodScope.yearly;
        case TriggerMode.dormant:
          return false;
      }
    });

    for (final a in currentScopeItems) {
      addAdvice(a);
    }

    // 已经打卡完成的排在下面（未完成优先，已完成沉底）
    list.sort((a, b) {
      final aDone = checkin.cardState(scope, a.id).isDone ? 1 : 0;
      final bDone = checkin.cardState(scope, b.id).isDone ? 1 : 0;
      return aDone.compareTo(bDone);
    });

    return list;
  }

  /// 根据聚焦视窗（中心时刻前后各 windowMinutes 分钟，L7 engines.json）动态筛选属于该视窗的建议流（当下 ⊆ 今天）
  List<Advice> advicesForWindow(StreamInputs i, DateTime centerTime) {
    final streamCfg = catalog.engines.stream;
    final windowStart = centerTime.subtract(
      Duration(minutes: streamCfg.windowMinutes),
    );
    final windowEnd = centerTime.add(Duration(minutes: streamCfg.windowMinutes));
    final winStartMin = windowStart.hour * 60 + windowStart.minute;
    final winEndMin = windowEnd.hour * 60 + windowEnd.minute;

    final mCenter = centerTime.hour * 60 + centerTime.minute;
    final centerHour = centerTime.hour;

    // 当下 严格属于 今天 的子集 (当下 ⊆ 今天)
    final todayList = todayAdvices(i, centerTime);

    // 筛选严格与视窗 [centerTime±windowMinutes] 发生时段交叠的建议
    final matched = todayList.where((a) {
      final trig = trigger.effectiveTriggerOf(a);
      if (trig.mode == TriggerMode.dormant) return false;

      // 建议原始 cron 和用户提醒时间共同构成精确展示锚点。
      // 一旦存在精确锚点，就不再用宽泛的 dailyPeriods 扩大展示范围。
      final anchors = trigger.displayAnchorsOf(a);
      if (anchors.isNotEmpty) {
        for (final anchor in anchors) {
          if (winStartMin <= winEndMin) {
            if (anchor >= winStartMin && anchor <= winEndMin) return true;
          } else {
            if (anchor >= winStartMin || anchor <= winEndMin) return true;
          }
        }
        return false;
      }

      // 自建待办时点匹配
      if (a.chapter == '我的自建待办') {
        final todo = i.userTodos.cast<UserTodoItem?>().firstWhere(
          (t) => t?.title == a.title,
          orElse: () => null,
        );
        if (todo != null && todo.triggerTime != null) {
          final parts = todo.triggerTime!.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            final tMin = h * 60 + m;
            if (winStartMin <= winEndMin) {
              if (tMin >= winStartMin && tMin <= winEndMin) return true;
            } else {
              if (tMin >= winStartMin || tMin <= winEndMin) return true;
            }
          }
        }
      }

      // 只有没有精确触发时刻时，才退回到手动配置的宽泛浮出时段。
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

      // 若未设置具体时段（全天守护），但在今日流中
      if (trig.dailyPeriods.isEmpty) {
        return true;
      }

      return false;
    }).toList();

    // 按照与中心时刻的相关性与精准锚点排序
    matched.sort((a, b) {
      // 已经打卡完成的排在下面（未完成优先充当 Hero，全部完成才轮到已完成）
      final aDone = checkin.cardState(PeriodScope.today, a.id).isDone ? 1 : 0;
      final bDone = checkin.cardState(PeriodScope.today, b.id).isDone ? 1 : 0;
      if (aDone != bDone) {
        return aDone.compareTo(bDone);
      }

      int score(Advice adv) {
        int s = 0;
        final trig = trigger.effectiveTriggerOf(adv);

        // 如果建议配置了自定义时段，距离 centerTime 越近权重越高（距离标尺来自 L7）
        for (final pk in trig.dailyPeriods) {
          final custom = PeriodDefinition.parseCustomPeriod(pk);
          if (custom != null) {
            final customMid = (custom.$1 + custom.$2) ~/ 2;
            final dist = (customMid - mCenter).abs();
            s += (streamCfg.customPeriodDistanceScale - dist).clamp(
              0,
              streamCfg.customPeriodDistanceScale,
            );
          }
        }

        final badge = adv.timingBadge;
        final title = adv.title;

        // 针对不同时段的关键行动加权（时段-关键词加权表数据化于 L7 engines.json，
        // 与原 if-else 链同序、首窗命中即止、组内任一命中加一次 boost）
        for (final window in streamCfg.boostWindows) {
          if (!window.covers(centerHour)) continue;
          for (final group in window.boosts) {
            if (group.matches(badge, title)) s += group.boost;
          }
          break; // 首个命中窗口即止（窗口互斥）
        }
        return s;
      }

      return score(b).compareTo(score(a));
    });

    return matched;
  }

  /// 真实动态时段建议流（严格准入：绝不塞入无明确时段的偶发建议）。
  /// 注：当前 UI 无引用，仅存量 widget_test 消费；删除与否待测试修复后裁决。
  List<Advice> periodAdvicesOf(StreamInputs i, String periodKey, DateTime now) {
    final list = catalog.adviceList.where((a) {
      if (i.excludedIds.contains(a.id) || !i.topicAllowed(a)) return false;
      if (i.formedHabitIds.contains(a.id)) return false;
      if (i.profile.prunedOnly && !_matchPersona(a, i)) return false;

      // 应急/急救建议严禁进入日常时段流
      if (a.isEmergencyOrIncident && !trigger.hasCustom(a.id)) {
        return false;
      }

      final trig = trigger.effectiveTriggerOf(a);
      if (trig.mode == TriggerMode.dormant ||
          trig.mode == TriggerMode.cadence) {
        return false; // 严禁进入时钟时段流
      }

      if (trig.mode == TriggerMode.daily) {
        final anchors = trigger.displayAnchorsOf(a);
        if (anchors.isNotEmpty) {
          return anchors.any(
            (minute) => trigger.minuteInPeriod(minute, periodKey),
          );
        }
        return trig.dailyPeriods.contains(periodKey);
      }

      if (trig.mode == TriggerMode.windowed && trig.targetDate != null) {
        final target = DateTime.tryParse(trig.targetDate!);
        if (target != null) {
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
        if (i.excludedIds.contains(a.id)) return false;
        if (a.isEmergencyOrIncident && !trigger.hasCustom(a.id)) {
          return false;
        }
        final trig = trigger.effectiveTriggerOf(a);
        if (trig.mode != TriggerMode.daily) return false;
        return trig.dailyPeriods.contains(periodKey);
      }).toList();
    }
    return list;
  }

  /// 全量应急/急救/突发处置条目（供紧急面板或突发模式使用，如中暑、骨折、海姆立克等）
  List<Advice> emergencyAdvices() {
    return catalog.adviceList.where((a) => a.isEmergencyOrIncident).toList();
  }
}
