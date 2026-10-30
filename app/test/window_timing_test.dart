import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/models/window_timing.dart';

void main() {
  test('only an explicitly dated window has a countdown', () {
    final now = DateTime(2026, 10, 30);
    expect(
      WindowTiming.fromConfig(
        const CustomTriggerConfig(mode: TriggerMode.cadence),
        now,
      ),
      isNull,
    );
    expect(
      WindowTiming.fromConfig(
        const CustomTriggerConfig(mode: TriggerMode.windowed),
        now,
      ),
      isNull,
    );
  });

  test('countdown follows the target date and chosen reminder lead', () {
    const config = CustomTriggerConfig(
      mode: TriggerMode.windowed,
      targetDate: '2026-11-29',
      leadDays: 15,
    );

    final upcoming = WindowTiming.fromConfig(config, DateTime(2026, 10, 30))!;
    expect(upcoming.daysUntilTarget, 30);
    expect(upcoming.isUpcoming, isTrue);
    expect(upcoming.progress, 0);

    final start = WindowTiming.fromConfig(config, DateTime(2026, 11, 14))!;
    expect(start.daysUntilTarget, 15);
    expect(start.isActive, isTrue);
    expect(start.progress, 0);

    final due = WindowTiming.fromConfig(config, DateTime(2026, 11, 29))!;
    expect(due.daysUntilTarget, 0);
    expect(due.isActive, isTrue);
    expect(due.progress, 1);

    final overdue = WindowTiming.fromConfig(config, DateTime(2026, 11, 30))!;
    expect(overdue.daysUntilTarget, -1);
    expect(overdue.isOverdue, isTrue);
  });

  test('calendar days remain stable across daylight saving changes', () {
    const config = CustomTriggerConfig(
      mode: TriggerMode.windowed,
      targetDate: '2026-11-02',
      leadDays: 7,
    );
    final timing = WindowTiming.fromConfig(config, DateTime(2026, 10, 30, 23))!;
    expect(timing.daysUntilTarget, 3);
  });
}
