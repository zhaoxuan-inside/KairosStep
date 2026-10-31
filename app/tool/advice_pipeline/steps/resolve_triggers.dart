// 步骤 ④ resolve_triggers：离线复刻 app_store.effectiveTriggerOf（:807-1025）的
// 原生默认触发推断，把结论回写为 L6 触发数据。
// 等价性由 test/trigger_plan_equivalence_test.dart 逐条证明：本文件逻辑必须与
// Dart 运行时逐字对齐——修改任一侧都必须跑等价性测试。

const _dormantChapters = {
  '紧急情况：先做什么',
  '遭遇重大打击之后',
  '人走了以后要办什么',
  '残疾之后怎么活',
  '反面清单',
  '别把自己搭进去：法律与财产安全',
  '普通人容易踩的法律红线',
  '创业与做生意：别把家底赔进去',
  '做一个网站或平台：资质、备案和服务器',
  '在职、离职和工伤',
  '看病：怎么少花钱少走弯路',
  '没钱的时候怎么活',
  '租房与买房',
};

const _nonDailyActTypes = {
  'redline-stamp',
  'decision-check',
  'process-steps',
  'context-guard',
  'emergency-action',
  'evidence-checklist',
};

/// 复刻 `isEmergencyOrIncident`（models/advice.dart:193）。
bool isEmergencyOrIncident(List<String> tags) {
  return tags.contains('突发事件') &&
      (tags.contains('事中') || tags.contains('事后'));
}

/// 返回 L6 单条触发计划（字段名对齐 CustomTriggerConfig 语义）。
Map<String, dynamic> resolveTrigger({
  required int id,
  required String title,
  required List<String> tags,
  required String timingBadge,
  required String chapter,
  required String actType,
}) {
  final emergency = isEmergencyOrIncident(tags);

  // 1. 静默储备架构门禁 (Dormant Gatekeeper)
  if (emergency ||
      _dormantChapters.contains(chapter) ||
      _nonDailyActTypes.contains(actType)) {
    return {'id': id, 'mode': 'dormant', 'emergency': emergency};
  }

  // 2. 原生推断 daily
  if (tags.contains('每天') || tags.contains('每日多次')) {
    final periods = <String>[];
    final text = '$title ${tags.join(" ")} $timingBadge $chapter';
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
      // 睡前一小时提醒在 21:30，绝不能被"水"误伤
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

    return {
      'id': id,
      'mode': 'daily',
      'dailyPeriods': periods,
      'reminderTimes': reminderTimes,
      'emergency': emergency,
    };
  }

  // 3. 周期循环 cadence
  if (tags.contains('每周')) {
    return {
      'id': id,
      'mode': 'cadence',
      'cadenceScopeKey': 'weekly',
      'emergency': emergency,
    };
  }
  if (tags.contains('每月')) {
    return {
      'id': id,
      'mode': 'cadence',
      'cadenceScopeKey': 'monthly',
      'emergency': emergency,
    };
  }
  if (tags.contains('每年') || tags.contains('筛查') || tags.contains('日历时点')) {
    return {
      'id': id,
      'mode': 'cadence',
      'cadenceScopeKey': 'yearly',
      'emergency': emergency,
    };
  }

  // 4. 其余均为静默储备态
  return {'id': id, 'mode': 'dormant', 'emergency': emergency};
}

List<Map<String, dynamic>> buildTriggerPlans(List<Map<String, dynamic>> advices) {
  final plans = <Map<String, dynamic>>[];
  for (final a in advices) {
    plans.add(
      resolveTrigger(
        id: (a['id'] as num).toInt(),
        title: a['t'] as String? ?? '',
        tags: ((a['tags'] as List?) ?? const []).cast<String>(),
        timingBadge: a['timing_badge'] as String? ?? '日常 · 建议',
        chapter: a['c'] as String? ?? '',
        actType: a['act_type'] as String? ?? 'quick-checkin',
      ),
    );
  }
  plans.sort((x, y) => (x['id'] as int).compareTo(y['id'] as int));
  return plans;
}
