/// Reviewed, low-interruption anchors for advice shown in Now without a user
/// configured reminder. These are display anchors, not notification times.
/// Every other catalog advice needs an explicit user time or a future context
/// signal before it can enter Now.
class NowTimingPolicy {
  static const focusRadiusMinutes = 15;

  // The 52 records tagged 每天/每日多次 were reviewed separately. A daily
  // label never implies an exact clock time.
  static const Set<int> todayOnlyDailyLabelIds = {
    7, 55, 56, 61, 63, 65, 66, 70, 72, 74, 75, 76, 79, 82, 83, 92,
    96, 97, 98, 100, 103, 104, 106, 137, 138, 482, 536, 537, 548,
    640, 687, 688,
  };

  // One-off or context-bound decisions must not become a daily task simply
  // because the source data has a daily frequency tag.
  static const Set<int> dormantDailyLabelIds = {
    52, 57, 80, 89, 112, 115, 128, 136, 139, 570,
  };

  // Already held back by the emergency/non-daily gate in effectiveTriggerOf.
  static const Set<int> gatedDailyLabelIds = {
    48, 78, 94, 496, 542, 546, 656,
  };

  static const Map<int, List<int>> defaultDisplayMinutes = {
    58: [7 * 60 + 30, 21 * 60 + 30], // 刷牙、清牙缝
    85: [12 * 60 + 45], // 午睡时长
    99: [13 * 60 + 45], // 14:00 咖啡因界限前
  };

  static bool nearMinute(int centerMinute, int anchorMinute) {
    final distance = (centerMinute - anchorMinute).abs();
    return distance <= focusRadiusMinutes ||
        1440 - distance <= focusRadiusMinutes;
  }

  static int? parseClockMinute(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }
}
