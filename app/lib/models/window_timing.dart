import 'advice.dart';

/// Calendar-day timing for an explicitly dated advice window.
class WindowTiming {
  const WindowTiming._(this.daysUntilTarget, this.leadDays);

  final int daysUntilTarget;
  final int leadDays;

  bool get isUpcoming => daysUntilTarget > leadDays;
  bool get isActive => daysUntilTarget >= 0 && !isUpcoming;
  bool get isOverdue => daysUntilTarget < 0;

  double get progress =>
      ((leadDays - daysUntilTarget) / leadDays).clamp(0.0, 1.0);

  static WindowTiming? fromConfig(CustomTriggerConfig config, DateTime now) {
    if (config.mode != TriggerMode.windowed || config.targetDate == null) {
      return null;
    }
    final target = DateTime.tryParse(config.targetDate!);
    if (target == null) return null;
    final todayDay = DateTime.utc(now.year, now.month, now.day);
    final targetDay = DateTime.utc(target.year, target.month, target.day);
    return WindowTiming._(
      targetDay.difference(todayDay).inDays,
      config.leadDays < 1 ? 1 : config.leadDays,
    );
  }
}
