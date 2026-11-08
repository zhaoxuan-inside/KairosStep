import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/engine_config.dart';
import 'probe_binding_engine.dart';
import '../models/advice.dart';
import '../models/probe_model.dart';
import 'delivery/notification_sink.dart';

/// 主动探测调度器模块 (Proactive Probe Scheduler)
///
/// 架构职责：
/// 1. 负责收集与注册当前画像下所有建议应该有的主动探查内容（按分类归并索引）；
/// 2. 依据规则触发通知信号：
///    - 必须的信号（Mandatory Signal：急救、突发高危）立即通知；
///    - 非必须的常规信号（Routine Signal：活动情境、身体微体征、心情关怀）进行合并通知；
/// 3. 严格控制通知频率（防打扰冷却机制、每日上限、深夜免打扰），避免过度打扰用户。
class ProbeEngine extends ChangeNotifier {
  ProbeEngine(this._notifications, this._config, {required this.probes}) {

    _startTicker();
  }

  /// 通知出口（系统通知实现；不可用时任回退应用内弹窗）
  final NotificationSink _notifications;

  /// L7 探查内容（probes.json）：绑定规则 + 题目模板 + 每日通知
  final ProbeContent probes;

  /// 绑定引擎（配置驱动，解析顺序与原实现一致）
  late final AdviceProbeBindingEngine _bindingEngine = AdviceProbeBindingEngine(
    probes.bindings,
  );

  /// 对外暴露绑定判定（测试与调试用）
  AdviceProbeSpec bindingSpecFor(Advice advice) => _bindingEngine.specFor(advice);

  /// L7 引擎配置（engines.json probe 段）：限频、静默、探查窗口、系统级通知时刻
  final ProbeEngineConfig _config;

  Timer? _ticker;

  // 内部注册的探查条目表（按类别归并）
  final Map<ProbeCategory, List<Advice>> _categoryAdvices = {};
  UserProfile? _currentProfile;

  // 频次控制与防打扰状态
  DateTime? _lastRoutineProbeTime;
  int _todayProbeCount = 0;
  String _lastRecordedDay = '';
  bool _dismissedForToday = false;
  DateTime? _snoozedUntil;

  // 频率控制参数来自 L7 engines.json（见 _config；原 static const 已外置）

  // 当前等待 UI 处理的探查通知数据包
  ProbePayload? _currentPayload;
  ProbePayload? get currentPayload => _currentPayload;
  final Map<String, ProbePayload> _pendingNotifications = {};
  final Set<String> _scheduledKinds = {};

  int get registeredAdviceCount =>
      _categoryAdvices.values.fold(0, (acc, list) => acc + list.length);

  void _startTicker() {
    _ticker?.cancel();
    // 每 10 分钟检查一次，避免高频轮询打扰设备和用户。
    _ticker = Timer.periodic(Duration(minutes: _config.tickerMinutes), (_) {
      checkScheduledProbes(DateTime.now());
    });
  }

  /// 注册当前活跃建议及其主动探查方式
  void registerAdvices(List<Advice> activeAdvices, UserProfile profile) {
    _currentProfile = profile;
    _categoryAdvices.clear();

    for (final a in activeAdvices) {
      final spec = _bindingEngine.specFor(a);
      _categoryAdvices.putIfAbsent(spec.category, () => []).add(a);
    }

    _syncDailySystemNotifications();

    // 注册完成后立即做一次判断，避免用户恰好在探查窗口内打开应用却要等满 10 分钟。
    checkScheduledProbes(DateTime.now());
  }

  void _syncDailySystemNotifications() {
    _scheduledKinds.clear();
    if (!_notifications.isReady) return;

    // 每日系统通知的时刻/文案/触发类别来自 L7 probes.json
    final dn = probes.dailyNotifications;
    final items = <DailyProbeNotification>[];
    final roles = _currentProfile?.roles ?? const <String>[];

    final morning = dn['morning']!;
    if ((_categoryAdvices[ProbeCategory.activity] ?? const []).isNotEmpty) {
      _scheduledKinds.add('probe_morning');
      items.add(morning.toNotification(roleBody: morning.body ?? ''));
    }
    final afternoon = dn['afternoon']!;
    if ((_categoryAdvices[ProbeCategory.body] ?? const []).isNotEmpty) {
      _scheduledKinds.add('probe_afternoon');
      items.add(afternoon.toNotification(roleBody: afternoon.body ?? ''));
    }
    final evening = dn['evening']!;
    if ((_categoryAdvices[ProbeCategory.mood] ?? const []).isNotEmpty ||
        (_categoryAdvices[ProbeCategory.weight] ?? const []).isNotEmpty) {
      _scheduledKinds.add('probe_evening');
      final roleBody = roles.contains('上班族') || roles.contains('程序员')
          ? evening.roleBodies['worker']!
          : roles.contains('学生')
          ? evening.roleBodies['student']!
          : evening.roleBodies['default']!;
      items.add(evening.toNotification(roleBody: roleBody));
    }
    unawaited(_notifications.replaceDailyProbes(items));
  }

  /// 周期性心跳检查调度规则
  void checkScheduledProbes(DateTime now) {
    if (_currentPayload != null) return; // 已有待处理探查，不覆盖

    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (_lastRecordedDay != todayStr) {
      _lastRecordedDay = todayStr;
      _todayProbeCount = 0;
      _dismissedForToday = false;
    }

    if (_dismissedForToday) return;

    // 检查稍后提醒延迟
    if (_snoozedUntil != null && now.isBefore(_snoozedUntil!)) {
      return;
    }

    // 用户设定的夜间静默优先于所有常规探查通知。
    if (_isQuietHours(now)) return;

    // 1. 检查是否有必须立即通知的高危紧急信号（仍受夜间静默保护）
    final mandatoryPayload = _checkMandatorySignals(now);
    if (mandatoryPayload != null) {
      _currentPayload = mandatoryPayload;
      notifyListeners();
      return;
    }

    // 2. 检查非必须常规信号（必须严格检查免打扰、每日上限与冷却时间）
    if (_shouldSuppressRoutine(now)) {
      return;
    }

    // 3. 按照时段生成合并探查通知
    final routinePayload = _generateRoutineProbeIfDue(now);
    if (routinePayload != null) {
      _pendingNotifications[routinePayload.id] = routinePayload;
      _lastRoutineProbeTime = now;
      _todayProbeCount++;
      _sendMobileNotification(routinePayload, now);
    }
  }

  void _sendMobileNotification(ProbePayload payload, DateTime now) {
    if (!_notifications.isReady) {
      // 桌面、Web 或通知权限不可用时，保留应用内弹窗兜底。
      _currentPayload = payload;
      notifyListeners();
      return;
    }

    final kind = payload.id.split('_').take(2).join('_');
    if (_scheduledKinds.contains(kind)) return;
    final role = _currentProfile?.roles ?? const <String>[];
    final body = switch (kind) {
      'probe_morning' => '现在是 ${_formatHour(now)}，告诉我你正在工作、学习、运动还是通勤。',
      'probe_afternoon' => '状态探查：今天身体和用眼感觉怎么样？',
      'probe_evening' when role.contains('上班族') || role.contains('程序员') =>
        '下班后了，用几十秒告诉我今天的工作感受。',
      'probe_evening' when role.contains('学生') => '晚间了，用几十秒告诉我今天的学习压力。',
      _ => '用几十秒告诉我今天的状态，帮我校准接下来的建议。',
    };
    _notifications.showProbe(
      id: payload.id.hashCode & 0x7fffffff,
      title: payload.title,
      body: body,
      payload: payload.id,
    );
  }

  String _formatHour(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  /// 用户点击系统通知后才打开探查弹窗；应用被系统回收时按通知类型重建题目。
  void handleNotificationTap(String? notificationId) {
    if (notificationId == null || notificationId.isEmpty) return;
    final pending = _pendingNotifications.remove(notificationId);
    final now = DateTime.now();
    final payload = pending ?? _payloadForNotificationId(notificationId, now);
    if (payload == null) return;
    _currentPayload = payload;
    notifyListeners();
  }

  ProbePayload? _payloadForNotificationId(String id, DateTime now) {
    if (id.startsWith('probe_morning_')) return createMorningContextProbe(now);
    if (id.startsWith('probe_afternoon_')) return createAfternoonBodyProbe(now);
    if (id.startsWith('probe_evening_')) {
      return createEveningMoodAndActivityProbe(now);
    }
    return null;
  }

  /// 检查必须立即通知的紧急信号
  ProbePayload? _checkMandatorySignals(DateTime now) {
    // 检查是否有突发紧急条目在当前处于高危急救状态
    final urgentAdvices = _categoryAdvices[ProbeCategory.urgent] ?? const [];
    if (urgentAdvices.isEmpty) return null;

    // 只有在特定紧急探查被显式触发时抛出（日常默认不随意弹出紧急急救）
    return null;
  }

  /// 触发必须立即通知的紧急信号（例如通过手动测试、紧急按钮或传感器触发）
  void triggerMandatoryEmergencySignal(Advice urgentAdvice) {
    final spec = _bindingEngine.specFor(urgentAdvice);
    _currentPayload = ProbePayload(
      id: 'mandatory_${urgentAdvice.id}_${DateTime.now().millisecondsSinceEpoch}',
      signalLevel: ProbeSignalLevel.mandatory,
      categories: [ProbeCategory.urgent],
      title: '🚨 紧急生命安全防线预警',
      description: urgentAdvice.title,
      questions: [
        ProbeQuestion(
          id: 'q_urgent_${urgentAdvice.id}',
          category: ProbeCategory.urgent,
          title: spec.promptQuestion,
          options: [
            ProbeOption(
              key: 'urgent_confirm',
              label: '立即查看黄金急救指南',
              emoji: '⚠️',
              description: spec.responseGuidance,
              associatedAdviceIds: [urgentAdvice.id],
            ),
            ProbeOption(
              key: 'urgent_call',
              label: '紧急呼救 120 / 110',
              emoji: '📞',
              associatedAdviceIds: [urgentAdvice.id],
            ),
          ],
        ),
      ],
      boundAdvices: [urgentAdvice],
      createdAt: DateTime.now(),
      isMerged: false,
    );
    notifyListeners();
  }

  /// 判断是否需要抑制常规非必须探查
  bool _shouldSuppressRoutine(DateTime now) {
    // 规则 A: 深夜免打扰 (23:00 ~ 05:00)
    if (_isQuietHours(now)) return true;

    // 规则 B: 每日最大主动探查频次控制
    if (_todayProbeCount >= _config.maxDailyRoutine) {
      return true;
    }

    // 规则 C: 冷却时间控制 (两次非紧急探查至少间隔 cooldownMinutes 分钟)
    if (_lastRoutineProbeTime != null) {
      final elapsed = now.difference(_lastRoutineProbeTime!).inMinutes;
      if (elapsed < _config.cooldownMinutes) {
        return true;
      }
    }

    return false;
  }

  bool _isQuietHours(DateTime now) => _config.quietHours.covers(now.hour);

  /// 按时段聚合与合并生成非必须常规探查（探查窗口来自 L7 engines.json）
  ProbePayload? _generateRoutineProbeIfDue(DateTime now) {
    final isMorningSlot = _config.routineWindows[0].isDue(now.hour, now.minute);
    final isAfternoonSlot = _config.routineWindows.length > 1
        ? _config.routineWindows[1].isDue(now.hour, now.minute)
        : false;
    final isEveningSlot = _config.routineWindows.length > 2
        ? _config.routineWindows[2].isDue(now.hour, now.minute)
        : false;

    if (isMorningSlot) {
      if ((_categoryAdvices[ProbeCategory.activity] ?? const []).isEmpty) {
        return null;
      }
      return createMorningContextProbe(now);
    } else if (isAfternoonSlot) {
      if ((_categoryAdvices[ProbeCategory.body] ?? const []).isEmpty) {
        return null;
      }
      return createAfternoonBodyProbe(now);
    } else if (isEveningSlot) {
      if ((_categoryAdvices[ProbeCategory.mood] ?? const []).isEmpty &&
          (_categoryAdvices[ProbeCategory.weight] ?? const []).isEmpty) {
        return null;
      }
      return createEveningMoodAndActivityProbe(now);
    }

    return null;
  }

  /// 上午：合并当前活动情境探查（题目模板来自 L7 probes.json）
  ProbePayload createMorningContextProbe(DateTime now) =>
      _payloadFromTemplate(probes.questions['morning']!, now);

  /// 下午：合并身体微体征与疲劳状态探查
  ProbePayload createAfternoonBodyProbe(DateTime now) =>
      _payloadFromTemplate(probes.questions['afternoon']!, now);

  /// 傍晚/晚间：合并探查（心情关照 + 画像角色追问 + 减重/体形咨询）
  ProbePayload createEveningMoodAndActivityProbe(DateTime now) {
    final t = probes.questions['evening']!;
    final roleQ = t.roleQuestion!;
    final roleQuestion = roleQ.toQuestionSpec(roleQ.variantFor(_currentProfile));
    return _payloadFromTemplate(t, now, roleQuestion: roleQuestion);
  }

  ProbePayload _payloadFromTemplate(
    ProbeSlotTemplate t,
    DateTime now, {
    ProbeQuestionSpec? roleQuestion,
  }) {
    final questions = <ProbeQuestion>[
      if (roleQuestion != null) roleQuestion.toQuestion(),
      for (final q in t.questions) q.toQuestion(),
    ];
    return ProbePayload(
      id: 'probe_${t.key}_${now.millisecondsSinceEpoch}',
      signalLevel: t.signalLevel,
      categories: t.categories,
      title: t.title,
      description: t.description,
      questions: questions,
      boundAdvices: _getAdvicesForCategories(t.categories),
      createdAt: now,
      isMerged: t.isMerged,
    );
  }

  List<Advice> _getAdvicesForCategories(List<ProbeCategory> categories) {
    final result = <Advice>[];
    for (final c in categories) {
      final list = _categoryAdvices[c] ?? const [];
      result.addAll(list);
    }
    return result;
  }

  /// 关闭当前探查弹窗
  void dismissCurrentPayload() {
    _currentPayload = null;
    notifyListeners();
  }

  /// 稍后提醒（推迟指定分钟数）
  void snoozeCurrentPayload({int minutes = 20}) {
    _snoozedUntil = DateTime.now().add(Duration(minutes: minutes));
    _currentPayload = null;
    notifyListeners();
  }

  /// 今日不再主动探查（用户主动选择）
  void dismissForToday() {
    _dismissedForToday = true;
    _currentPayload = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// 存量类型名兼容（active_probe_dialog 等引用零改动）。
typedef ProbeScheduler = ProbeEngine;
