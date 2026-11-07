// 探查系统通知 E2E（真通知通道）。
//
// 画像「上班族」保证 activity/body 类绑定建议活跃；初始化真实
// MobileNotificationService（权限由宿主 adb 预授/轮询授予）；
// 时钟由宿主设到午后探查窗口（14:15-15:00），resumed + 立即检查触发
// showProbe → 系统通知（id 9102 或探查 id）。系统侧由宿主 dumpsys +
// 通知栏截图验证（测试保持存活 60s 供宿主取证）。
//
// 运行：宿主 `adb shell date 112014202026.00`（14:20，窗口内）；
//       安装后 60s 内轮询 `pm grant ... POST_NOTIFICATIONS`；
//       测试运行期间 `dumpsys notification` 取证。
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

  testWidgets(
    '探查窗口内 showProbe 发出系统通知',
    (tester) async {
      prefs = await SharedPreferences.getInstance();
      store = AppStore(catalog, prefs);
      await store.restore();
      if (!store.hasProfile) {
        store.completeOnboarding(const UserProfile(roles: ['上班族']));
      }
      // 初始化真实通知通道（与 main.dart 相同路径；权限由宿主后台轮询授予，
      // 授权落地前的请求会弹系统对话框并以 false 返回——这里重试直到就绪）
      for (var i = 0;
          i < 30 && !store.mobileNotificationService.isReady;
          i++) {
        await store.mobileNotificationService.initialize(onTap: (_) {});
        if (!store.mobileNotificationService.isReady) {
          await Future<void>.delayed(const Duration(seconds: 4));
        }
      }
      // ignore: avoid_print
      print('[PROBE] notification isReady='
          '${store.mobileNotificationService.isReady}');

      await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final now = DateTime.now();
      // ignore: avoid_print
      print('[PROBE] now=${now.toIso8601String()}（宿主应已设到 14:15-15:00 窗口）');

      // 诊断：当前画像下各探查类别的活跃建议数（决定哪些窗口能生成探查）
      final catCount = <String, int>{};
      for (final a in store.todayAdvices) {
        final c = store.probeScheduler.bindingSpecFor(a).category.name;
        catCount[c] = (catCount[c] ?? 0) + 1;
      }
      // ignore: avoid_print
      print('[PROBE] categoryCounts=$catCount '
          'registered=${store.probeScheduler.registeredAdviceCount}');

      // resumed 路径：立即检查一次探查（app.dart 生命周期同款）
      store.probeScheduler.checkScheduledProbes(DateTime.now());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final hasInApp = store.probeScheduler.currentPayload != null;
      // ignore: avoid_print
      print('[PROBE] currentPayload=$hasInApp '
          '（通知就绪时走系统通知，payload 在用户点击后注入）');

      // 给宿主留 60s 取证窗口（dumpsys + 通知栏截图），期间保持存活
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // ignore: avoid_print
      print('[PROBE] 取证窗口结束');

      // 系统通知已由 showProbe 投递（宿主 dumpsys 断言）；应用内不弹对话框
      // 是预期行为（通知就绪时点击通知才注入 payload）。
      expect(store.mobileNotificationService.isReady, isTrue,
          reason: '真实通知通道应初始化成功（权限已授予）');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      store.dispose();
    },
    timeout: Timeout(const Duration(minutes: 10)),
  );
}

// 诊断辅助（同文件内私有扩展）：打印画像下各探查类别的活跃建议数
