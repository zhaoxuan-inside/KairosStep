// 通知出口抽象（REFACTOR_DESIGN §5.4）：应用内与系统通知是同一引擎的两个 sink。
// 领域层只依赖本接口；infra 层的 MobileNotificationService 是系统实现。
import '../../models/probe_model.dart';

abstract class NotificationSink {
  /// 通知通道是否就绪（权限/平台支持）。false 时引擎走应用内兜底。
  bool get isReady;

  Future<void> showProbe({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  /// 注册每天固定时刻的系统通知，让应用被挂起时仍能主动发起探查。
  Future<void> replaceDailyProbes(List<DailyProbeNotification> notifications);
}
