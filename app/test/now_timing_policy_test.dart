import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/state/now_timing_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 767 advices have a conservative default Now policy', () async {
    final catalog = await Catalog.load();
    expect(catalog.adviceList.length, 767);
    final dailyIds = catalog.adviceList
        .where((a) => a.tags.contains('每天') || a.tags.contains('每日多次'))
        .map((a) => a.id)
        .toSet();
    final reviewed = {
      ...NowTimingPolicy.todayOnlyDailyLabelIds,
      ...NowTimingPolicy.dormantDailyLabelIds,
      ...NowTimingPolicy.gatedDailyLabelIds,
      ...NowTimingPolicy.defaultDisplayMinutes.keys,
    };
    expect(reviewed, dailyIds);
    expect(
      NowTimingPolicy.defaultDisplayMinutes.keys.toSet().intersection(
        NowTimingPolicy.dormantDailyLabelIds,
      ),
      isEmpty,
    );
    for (final anchors in NowTimingPolicy.defaultDisplayMinutes.values) {
      expect(anchors, isNotEmpty);
      expect(anchors.every((minute) => minute >= 0 && minute < 1440), isTrue);
    }
  });

  test('Now only shows reviewed anchors without user times', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(await Catalog.load(), prefs);
    await store.restore();
    for (var minute = 0; minute < 1440; minute += 15) {
      final shown = store.advicesForWindow(
        DateTime(2026, 10, 30, minute ~/ 60, minute % 60),
      );
      expect(
        shown.every((a) => NowTimingPolicy.defaultDisplayMinutes.containsKey(a.id)),
        isTrue,
        reason: 'Unexpected default Now advice at minute $minute',
      );
    }
  });

  test('focus window is only 15 minutes either side of an anchor', () {
    expect(NowTimingPolicy.nearMinute(765, 780), isTrue);
    expect(NowTimingPolicy.nearMinute(764, 780), isFalse);
    expect(NowTimingPolicy.nearMinute(2, 1435), isTrue);
    expect(NowTimingPolicy.parseClockMinute('25:30'), isNull);
  });

  test('an explicit user time replaces the default display anchor', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(await Catalog.load(), prefs);
    await store.restore();
    store.setTriggerConfig(
      58,
      const CustomTriggerConfig(
        mode: TriggerMode.daily,
        reminderTimes: ['10:00'],
      ),
    );
    expect(
      store.advicesForWindow(DateTime(2026, 10, 30, 7, 30))
          .any((a) => a.id == 58),
      isFalse,
    );
    expect(
      store.advicesForWindow(DateTime(2026, 10, 30, 10))
          .any((a) => a.id == 58),
      isTrue,
    );
  });
}
