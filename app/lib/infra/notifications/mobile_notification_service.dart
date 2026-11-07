import 'package:flutter/foundation.dart';

import '../../domain/delivery/notification_sink.dart';
import '../../models/probe_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


/// 移动端主动探查通知通道。
///
/// 探查内容在调度器中按画像和当前时刻生成；这里仅负责把通知交给
/// Android/iOS，并把用户点击的 payload 回传给调度器。
class MobileNotificationService implements NotificationSink {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneInitialized = false;

  @override
  bool get isReady => _initialized;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (!_isMobile) return;

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      final initialized = await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          onTap(response.payload);
        },
      );
      // 初始化链路留痕（debug 可见）：通道静默失效无从排查
      debugPrint('[notify-init] plugin.initialize=$initialized');
      if (initialized != true) return;

      final androidPermission = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      debugPrint('[notify-init] requestNotificationsPermission='
          '$androidPermission');
      final iosPermission = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = androidPermission != false && iosPermission != false;
      if (_initialized) {
        tz.initializeTimeZones();
        try {
          final timezoneName = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(timezoneName));
        } catch (_) {
          // timezone.local 默认值仍可用于设备不提供名称的情况。
        }
        _timezoneInitialized = true;
      }
    } catch (e, s) {
      // 通知权限被拒绝或平台不支持时，调度器会回退到应用内弹窗。
      // 但初始化异常需要留痕（debug 下可见），否则通道静默失效无从排查。
      debugPrint('[KairosCrash][notify-init] $e\n$s');
    }
  }

  @override
  Future<void> showProbe({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) return;

    const android = AndroidNotificationDetails(
      'kairos_probe',
      '主动探查',
      channelDescription: '根据作息和用户画像发出的主动探查通知',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: android, iOS: ios),
        payload: payload,
      );
    } catch (_) {
      // 权限在系统设置中被撤回时，静默交给调度器的应用内兜底路径。
    }
  }

  /// 注册每天固定时刻的系统通知，让应用被挂起时仍能主动发起探查。
  @override
  Future<void> replaceDailyProbes(
    List<DailyProbeNotification> notifications,
  ) async {
    if (!_initialized || !_timezoneInitialized) return;

    try {
      await _plugin.cancel(9101);
      await _plugin.cancel(9102);
      await _plugin.cancel(9103);
      for (final item in notifications) {
        final now = tz.TZDateTime.now(tz.local);
        var scheduled = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          item.hour,
          item.minute,
        );
        if (!scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          item.id,
          item.title,
          item.body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'kairos_probe',
              '主动探查',
              channelDescription: '根据作息和用户画像发出的主动探查通知',
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: item.payload,
        );
      }
    } catch (_) {
      // 某些系统关闭后台调度时，前台十分钟检查仍可继续工作。
    }
  }
}
