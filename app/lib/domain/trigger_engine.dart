// 触发计算引擎（REFACTOR_DESIGN §5.1）：触发方式/时间解析 + 用户自定义覆盖。
// 自 app_store.effectiveTriggerOf（原 :807-1025）整体迁移，逻辑逐字保留；
// 词表已在 Phase 1 数据化为 L6（等价性由 test/trigger_plan_equivalence_test.dart 守护），
// 本引擎是运行时的判定权威，Phase 4+ 将切换为 L6 查表 + 本引擎兜底。
// 依赖规则：只依赖 data/（catalog 配置）与 models/，不依赖 state/ui/prefs。
import '../data/catalog.dart';
import '../models/advice.dart';
import 'advice_identity.dart';

class TriggerEngine {
  TriggerEngine(this.catalog, {required this.onPersist});

  final Catalog catalog;

  /// 自定义触发变更后的持久化回调（state 层负责写 kCustomTriggers 并广播）。
  final void Function() onPersist;

  /// 用户自定义触发覆盖（adviceId → 配置），原 AppStore._customTriggers。
  final Map<int, CustomTriggerConfig> customTriggers = {};

  CustomTriggerConfig? triggerConfigOf(int id) =>
      customTriggers[canonicalAdviceId(id)];

  bool hasCustom(int id) => customTriggers.containsKey(canonicalAdviceId(id));

  /// 恢复（restore() 时由 store 调用，键已规范化）。
  void restoreFrom(Map<int, CustomTriggerConfig> restored) {
    customTriggers
      ..clear()
      ..addAll(restored);
    _effectiveCache.clear();
  }

  void set(int id, CustomTriggerConfig cfg) {
    final key = canonicalAdviceId(id);
    customTriggers[key] = cfg;
    _effectiveCache.remove(key);
    onPersist();
  }

  void reset(int id) {
    final key = canonicalAdviceId(id);
    customTriggers.remove(key);
    _effectiveCache.remove(key);
    onPersist();
  }

  /// 生效触发配置缓存：推断是纯函数（advice 静态字段 + 静态词表），仅在
  /// 自定义覆盖增删时失效。全流每次求值 737 条 × 文本拼接 + 数十次关键词
  /// 扫描，此前每次调用全量重算——今天页一次 build 调两遍，缓存后归零。
  final Map<int, CustomTriggerConfig> _effectiveCache = {};

  /// 获取建议生效的触发配置（有自定义取自定义，否则推断原生默认）。
  CustomTriggerConfig effectiveTriggerOf(Advice a) =>
      _effectiveCache[a.id] ??= _computeEffective(a);

  CustomTriggerConfig _computeEffective(Advice a) {
    if (customTriggers.containsKey(a.id)) {
      return customTriggers[a.id]!;
    }
    // 1. 静默储备架构门禁 (Dormant Gatekeeper)：
    // 突发急救、重大变故、身后事、残疾照护、法律红线、反面清单、合规防线
    // 以及非微习惯卡片形态（红线盖章、决策核对、办事步骤、情境拦截、应急直达、举证清单）
    // 原生推断一律为静默储备态（TriggerMode.dormant），严禁污染每日待办时间流！
    // 章节名单与形态名单数据化于 L7 gates.json（Phase 2）。
    final dormantChapters = catalog.gates.dormantChapters;
    final nonDailyActTypes = catalog.gates.dormantActTypes;

    if (a.isEmergencyOrIncident ||
        dormantChapters.contains(a.chapter) ||
        nonDailyActTypes.contains(a.actType)) {
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
        '午睡',
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
      final isNightSleep =
          [
            '夜里',
            '褪黑素',
            '安稳',
            '睡前',
            '刷牙',
            '洗漱',
            '失眠',
            '入眠',
            '23:00',
            '熬夜',
            '放松',
          ].any(text.contains) ||
          (text.contains('睡眠') &&
              !text.contains('午睡') &&
              !text.contains('小憩') &&
              !text.contains('下午困'));
      if (isNightSleep) {
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
      } else if (text.contains('午睡') ||
          text.contains('午休') ||
          text.contains('小憩') ||
          text.contains('打盹')) {
        // 午休/午睡必须在午睡前定点提醒，绝不能落在夜间
        reminderTimes.add('12:45');
      } else if (text.contains('饮水') ||
          text.contains('喝水') ||
          text.contains('补水') ||
          text.contains('白开水')) {
        reminderTimes.addAll(['09:30', '11:30', '14:30', '16:30']);
      } else if (text.contains('咖啡因') &&
          (text.contains('两点') || text.contains('下午'))) {
        reminderTimes.add('13:30');
      } else if ((text.contains('0 到 3 岁') || text.contains('中小学生')) &&
          text.contains('屏幕')) {
        reminderTimes.add('18:30');
      } else if (text.contains('睡前一小时') ||
          (text.contains('屏幕') && (text.contains('睡') || text.contains('夜')))) {
        // 睡前一小时（如 103 题：不看发光屏幕/墨水屏）提醒时间在 21:30，绝不能被"水"误伤
        reminderTimes.add('21:30');
      } else if (text.contains('散步') ||
          text.contains('运动') ||
          text.contains('慢跑') ||
          text.contains('快走')) {
        reminderTimes.add('19:00');
      } else if (text.contains('睡') ||
          text.contains('失眠') ||
          text.contains('褪黑素') ||
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

  // ── 展示锚点（供当下流与时段流使用；原 _parseTimeMinutes/_cronDailyAnchors/_displayAnchors/_minuteInPeriod） ──

  int? parseTimeMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// Returns concrete daily anchors from a simple five-field cron expression.
  /// Wildcards are intentionally ignored: they do not provide a useful display
  /// anchor and should fall back to the explicitly configured daily periods.
  List<int> cronDailyAnchors(String cron) {
    final fields = cron.trim().split(RegExp(r'\s+'));
    if (fields.length != 5) return const [];
    final minuteField = fields[0];
    final hourField = fields[1];
    if (minuteField == '*' || hourField == '*') return const [];

    List<int>? parseField(String field, int min, int max) {
      final values = <int>{};
      for (final part in field.split(',')) {
        final range = part.split('-');
        if (range.length == 1) {
          final value = int.tryParse(range[0]);
          if (value == null || value < min || value > max) return null;
          values.add(value);
        } else if (range.length == 2) {
          final start = int.tryParse(range[0]);
          final end = int.tryParse(range[1]);
          if (start == null ||
              end == null ||
              start < min ||
              end > max ||
              start > end) {
            return null;
          }
          values.addAll([for (var v = start; v <= end; v++) v]);
        } else {
          return null;
        }
      }
      return values.toList()..sort();
    }

    final minutes = parseField(minuteField, 0, 59);
    final hours = parseField(hourField, 0, 23);
    if (minutes == null || hours == null) return const [];
    return [
      for (final h in hours)
        for (final m in minutes) h * 60 + m,
    ];
  }

  /// 用户提醒时刻 + 原始 cron 锚点，升序合并。
  List<int> displayAnchorsOf(Advice a) {
    final trig = effectiveTriggerOf(a);
    final reminders = trig.reminderTimes
        .map(parseTimeMinutes)
        .whereType<int>()
        .toList();
    return {...reminders, ...cronDailyAnchors(a.cron)}.toList()..sort();
  }

  bool minuteInPeriod(int minute, String periodKey) {
    final def = PeriodDefinition.byKey(periodKey);
    if (def == null) {
      final custom = PeriodDefinition.parseCustomPeriod(periodKey);
      return custom != null &&
          PeriodDefinition.timeRangesOverlap(
            custom.$1,
            custom.$2,
            minute,
            minute + 1,
          );
    }
    return def.overlaps(minute, minute + 1);
  }
}
