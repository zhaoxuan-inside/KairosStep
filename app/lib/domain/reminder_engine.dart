import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/catalog.dart';
import '../models/advice.dart';
import 'checkin_engine.dart';
import 'trigger_engine.dart';

/// 弹窗提示数据包：包含触发建议元信息与提醒时间文本。
@immutable
class ReminderAlert {
  const ReminderAlert({
    required this.advice,
    required this.time,
    required this.formattedTime,
  });

  final Advice advice;
  final DateTime time;
  final String formattedTime;
}

/// 内部注册的时刻条目
class _RegisteredReminder {
  const _RegisteredReminder({
    required this.adviceId,
    required this.hour,
    required this.minute,
  });

  final int adviceId;
  final int hour;
  final int minute;
}

/// 通知推送引擎——应用内弹窗出口 (Reminder Engine，原 Reminder Registry)
///
/// 架构优势：
/// 1. 彻底避免每次轮询全量线性扫描 737 条大库；
/// 2. 仅对当前画像有效且已开启提醒的 5~15 条活跃建议进行按需注册；
/// 3. 到达提醒时间点时精准弹出应用内提示卡，支持立即打卡、稍后提醒与今日忽略。
class ReminderEngine extends ChangeNotifier {
  ReminderEngine({
    required this.catalog,
    required this.trigger,
    required this.checkin,
    required this.onStoreChange,
  }) {
    _startTicker();
  }

  final Catalog catalog;
  final TriggerEngine trigger;
  final CheckinEngine checkin;

  /// 打卡完成后的 store 广播（今日流/角标刷新）。
  final void Function() onStoreChange;

  Timer? _ticker;
  final List<_RegisteredReminder> _registeredList = [];
  final Set<String> _suppressedKeys = {};

  ReminderAlert? _currentAlert;
  ReminderAlert? get currentAlert => _currentAlert;

  int get registeredCount => _registeredList.length;

  /// 启动心跳定时器（秒数来自 L7 engines.json）
  void _startTicker() {
    _ticker?.cancel();
    final seconds = catalog.engines.reminder.tickerSeconds;
    _ticker = Timer.periodic(Duration(seconds: seconds), (_) {
      checkCurrentTick(DateTime.now());
    });
  }

  /// 重新注册活跃建议的提醒时间点
  /// 仅传入经过画像剪枝后的活跃建议（通常仅 5~15 条），开销极低
  void registerActiveReminders(List<Advice> activeAdvices) {
    _registeredList.clear();

    for (final a in activeAdvices) {
      final trig = trigger.effectiveTriggerOf(a);
      if (trig.mode != TriggerMode.daily && trig.mode != TriggerMode.windowed) {
        continue;
      }

      for (final timeStr in trig.reminderTimes) {
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          _registeredList.add(
            _RegisteredReminder(adviceId: a.id, hour: h, minute: m),
          );
        }
      }
    }

    // 按小时和分钟排序
    _registeredList.sort((a, b) {
      if (a.hour != b.hour) return a.hour.compareTo(b.hour);
      return a.minute.compareTo(b.minute);
    });

    notifyListeners();
  }

  /// 检测给定时刻是否命中提醒点（精确到分钟）
  void checkCurrentTick(DateTime now) {
    if (_currentAlert != null) return; // 已有未关闭弹窗时不重复打扰

    // 移动端夜间统一静默（时段来自 L7 engines.json），避免深夜提醒打扰睡眠。
    if (catalog.engines.reminder.quietHours.covers(now.hour)) return;

    final nowHour = now.hour;
    final nowMinute = now.minute;
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final r in _registeredList) {
      if (r.hour == nowHour && r.minute == nowMinute) {
        final alertKey = '${todayKey}_${r.hour}:${r.minute}_${r.adviceId}';
        if (_suppressedKeys.contains(alertKey)) continue;

        // 检查该建议在今日是否已经打卡完成，已完成则无需重复弹窗提醒
        final cardState = checkin.cardState(PeriodScope.today, r.adviceId);
        if (cardState.isDone) {
          _suppressedKeys.add(alertKey);
          continue;
        }

        final advice = catalog.adviceById(r.adviceId);
        if (advice != null) {
          _suppressedKeys.add(alertKey);
          final formattedTime =
              '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
          _currentAlert = ReminderAlert(
            advice: advice,
            time: now,
            formattedTime: formattedTime,
          );
          notifyListeners();
          break;
        }
      }
    }
  }

  /// 立即完成打卡
  void completeCurrentAlert() {
    final alert = _currentAlert;
    if (alert == null) return;
    checkin.toggleDone(PeriodScope.today, alert.advice.id, true);
    onStoreChange();
    _currentAlert = null;
    notifyListeners();
  }

  /// 稍后提醒（默认分钟数来自 L7 engines.json）
  void snoozeCurrentAlert({int? minutes}) {
    final alert = _currentAlert;
    if (alert == null) return;

    final targetTime = DateTime.now().add(
      Duration(minutes: minutes ?? catalog.engines.reminder.snoozeMinutes),
    );
    _registeredList.add(
      _RegisteredReminder(
        adviceId: alert.advice.id,
        hour: targetTime.hour,
        minute: targetTime.minute,
      ),
    );

    _currentAlert = null;
    notifyListeners();
  }

  /// 忽略当前弹窗（今天不再对此时间点提醒）
  void dismissCurrentAlert() {
    _currentAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// 存量类型名兼容（shell.dart 等引用零改动）。
typedef ReminderRegistry = ReminderEngine;
