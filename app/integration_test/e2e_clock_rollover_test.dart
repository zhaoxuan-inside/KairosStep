// 跨天/跨周打卡重置 E2E（单进程时钟协同方案）。
//
// 背景：`flutter test` 每次运行会重装应用并清空数据，无法跨进程接力。
// 因此本文件在**一次运行内**完成三个阶段，用「等待设备时钟推进」与宿主协同：
//   P0 setup：打卡今日 1 条 + 每周 1 条（store 真值 + 持久化）。
//   P1 跨天：宿主把时钟 +1 天（同周内）→ 进程内重启 → 今日清零、每周保留。
//   P2 跨周：宿主再把时钟 +7 天 → 进程内重启 → 每周清零。
// 周纪元按周一起算（checkin_engine.scopeEpochKey → 'w_<周一>'），
// 初始时钟由宿主设为周三，+1 天不跨周、+8 天必跨周，断言完全确定。
//
// 断言用 cardState（直接读持久化打卡表，不受当日流内容变化影响）。
// 运行：宿主先 `adb shell date 111111002026.00`（周三 11:00），
//       再 `flutter test integration_test/e2e_clock_rollover_test.dart -d emulator-5554`，
//       看到日志 WAIT-DAY 后 +1 天，WAIT-WEEK 后再 +7 天。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/user.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late Catalog catalog;
  late AppStore store;
  late SharedPreferences prefs;

  setUpAll(() async {
    catalog = await Catalog.load();
  });

  Future<void> restartApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    store.dispose();
    store = AppStore(catalog, prefs);
    await store.restore();
    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  void markDone(PeriodScope scope, int id) {
    store.updateCard(scope, id, (st) {
      st.doneParts.add('__e2e_clock__');
      st.completionRatio = 1;
    });
  }

  /// 等待设备时钟推进到 t0 + [days] 天（宿主改时钟后立即返回）。
  Future<void> waitClockAhead(DateTime t0, int days, String tag) async {
    final target = t0.add(Duration(days: days));
    // ignore: avoid_print
    print('[$tag] 等待宿主把时钟推进到 ${target.toIso8601String()} ...');
    var waited = 0;
    while (DateTime.now().isBefore(target)) {
      await Future<void>.delayed(const Duration(seconds: 5));
      waited += 5;
      if (waited % 60 == 0) {
        // ignore: avoid_print
        print('[$tag] 已等待 ${waited}s，当前时钟 ${DateTime.now().toIso8601String()}');
      }
    }
    // ignore: avoid_print
    print('[$tag] 时钟已推进：${DateTime.now().toIso8601String()}');
  }

  testWidgets(
    'P0 打卡 setup → P1 跨天今日清零/每周保留 → P2 跨周每周清零',
    (tester) async {
      final t0 = DateTime.now();
      // ignore: avoid_print
      print('[P0] 起始时钟 ${t0.toIso8601String()}（宿主应已设为周三）');

      prefs = await SharedPreferences.getInstance();
      store = AppStore(catalog, prefs);
      await store.restore();
      if (!store.hasProfile) {
        store.completeOnboarding(const UserProfile());
      }
      await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ── P0：打卡今日 + 每周 ──
      final todayList = store.todayAdvices;
      expect(todayList, isNotEmpty, reason: '今日流应有条目');
      final todayId = todayList.first.id;
      markDone(PeriodScope.today, todayId);

      final weeklyList = store.cycleAdvicesOf(PeriodScope.weekly);
      expect(weeklyList, isNotEmpty, reason: '每周流应有条目');
      final weeklyId = weeklyList.first.id;
      markDone(PeriodScope.weekly, weeklyId);

      expect(store.cardState(PeriodScope.today, todayId).isDone, isTrue,
          reason: 'P0 今日打卡生效');
      expect(store.cardState(PeriodScope.weekly, weeklyId).isDone, isTrue,
          reason: 'P0 每周打卡生效');
      expect(prefs.getString('kScope.today'), isNotNull);
      expect(prefs.getString('kScope.weekly'), isNotNull);
      // ignore: avoid_print
      print('[P0-DONE] 今日 #$todayId / 每周 #$weeklyId 已打卡并落盘');

      // ── P1：宿主 +1 天（同周内）→ 今日清零、每周保留 ──
      await waitClockAhead(t0, 1, 'WAIT-DAY');
      await restartApp(tester);
      expect(store.hasProfile, isTrue, reason: '画像跨天保持');
      expect(store.cardState(PeriodScope.today, todayId).isDone, isFalse,
          reason: '跨天后今日打卡清零（kScopeEpoch.today 换代清空）');
      expect(store.countersOf(PeriodScope.today).$1, 0,
          reason: '今日完成计数归零');
      expect(store.cardState(PeriodScope.weekly, weeklyId).isDone, isTrue,
          reason: '同周内 +1 天，每周打卡保留（周纪元按周一起算）');
      // ignore: avoid_print
      print('[P1-DONE] 跨天：今日清零 ✓ 每周保留 ✓');

      // ── P2：宿主再 +7 天（跨周）→ 每周清零 ──
      await waitClockAhead(t0, 8, 'WAIT-WEEK');
      await restartApp(tester);
      expect(store.cardState(PeriodScope.weekly, weeklyId).isDone, isFalse,
          reason: '跨周后每周打卡清零（kScopeEpoch.weekly 换代清空）');
      // ignore: avoid_print
      print('[P2-DONE] 跨周：每周清零 ✓');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      store.dispose();
    },
    timeout: Timeout(const Duration(minutes: 25)),
  );
}
