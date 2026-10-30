import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DailyProbeNotification {
  const DailyProbeNotification({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
  final String payload;
}

/// 移动端主动探查通知通道。
///
/// 探查内容在调度器中按画像和当前时刻生成；这里仅负责把通知交给
/// Android/iOS，并把用户点击的 payload 回传给调度器。
class MobileNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneInitialized = false;

  bool get isReady => _initialized;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (!_isMobile) return;

    const androidSettings = AndroidInitializationSettings('ic_launcher');
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
      if (initialized != true) return;

      final androidPermission = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
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
    } catch (_) {
      // 通知权限被拒绝或平台不支持时，调度器会回退到应用内弹窗。
    }
  }

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
