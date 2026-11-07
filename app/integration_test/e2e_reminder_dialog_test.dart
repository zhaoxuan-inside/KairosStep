// 提醒投递 E2E：自建待办（提醒 08:30）→ 时钟协同到点 → 应用内提醒对话框
// →「立即打卡」完成闭环。
//
// 投递路径说明（REFACTOR_DESIGN §5.4，应用内与系统通知是同一引擎的两个 sink）：
// 提醒时刻由 ReminderEngine 心跳（10s）判定，应用在前台时呈现不可忽略的
// 应用内提醒对话框（避免整屏打扰）；系统级通知用于主动探查
// （9:30/14:15/20:00 档，zonedSchedule，见 e2e_probe_notification 流程）。
//
// 运行：宿主把时钟设为次日 08:29:20 附近（如 adb shell date 11200829202026.00），
// 测试内创建提醒待办后轮询等待 08:30 到点。
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
    '提醒到点：应用内提醒对话框出现并可立即打卡',
    (tester) async {
      prefs = await SharedPreferences.getInstance();
      store = AppStore(catalog, prefs);
      await store.restore();
      if (!store.hasProfile) {
        store.completeOnboarding(const UserProfile());
      }
      await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 创建未完成的 08:30 提醒待办（独立标题避免与历史数据撞名）
      store.addUserTodoItem(UserTodoItem(
        id: UserTodoItem.newId(),
        title: 'E2E 提醒验证待办',
        createdAt: DateTime.now(),
        triggerTime: '08:30',
        reminderTimes: const ['08:30'],
        frequency: 'daily',
      ));
      final todo = store.userTodos.lastWhere((t) => t.title == 'E2E 提醒验证待办');
      expect(todo.isDone, isFalse);
      final syn = todo.toAdvice();
      final eff = store.triggerEngine.effectiveTriggerOf(syn);
      // ignore: avoid_print
      print('[REMINDER] syn=${syn.id} mode=${eff.mode} '
          'times=${eff.reminderTimes} inStream='
          '${store.todayAdvices.any((a) => a.id == syn.id)} '
          'registered=${store.reminderRegistry.registeredCount} '
          'todayLen=${store.todayAdvices.length}');
      // ignore: avoid_print
      print('[REMINDER] 待办已创建（提醒 08:30），等待时钟到点 ...');

      // 等待宿主把时钟推进到 08:30（轮询，上限 12 分钟）
      var reached = false;
      for (var i = 0; i < 144; i++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        final now = DateTime.now();
        if (now.hour == 8 && now.minute >= 30) {
          reached = true;
          break;
        }
        if (now.hour > 8 && now.hour < 23) {
          reached = true;
          break;
        }
        if (i % 6 == 0) {
          // ignore: avoid_print
          print('[REMINDER] 等待中：${now.toIso8601String()}');
        }
      }
      expect(reached, isTrue, reason: '宿主应把时钟推进到 08:30 之后');

      // 心跳 10s 内应弹出应用内提醒对话框（不可忽略：立即打卡 / 稍后 10 分钟）
      var dialogUp = false;
      var manualProbed = false;
      for (var i = 0; i < 15 && !dialogUp; i++) {
        await tester.pump(const Duration(seconds: 2));
        dialogUp = find.text('立即打卡').evaluate().isNotEmpty &&
            find.textContaining('提醒').evaluate().isNotEmpty;
        if (i == 6 && !manualProbed) {
          manualProbed = true;
          // 诊断：手动喂一跳，区分「ticker 未跳」与「注册/匹配问题」
          store.reminderRegistry.checkCurrentTick(DateTime.now());
          // ignore: avoid_print
          print('[REMINDER] manual tick -> currentAlert='
              '${store.reminderRegistry.currentAlert != null}');
        }
        if (i % 3 == 0) {
          // ignore: avoid_print
          print('[REMINDER] check#$i now=${DateTime.now().toIso8601String()} '
              'currentAlert=${store.reminderRegistry.currentAlert != null} '
              'registered=${store.reminderRegistry.registeredCount}');
        }
      }
      expect(dialogUp, isTrue, reason: '08:30 提醒应弹出应用内提醒对话框');
      // ignore: avoid_print
      print('[REMINDER] 提醒对话框已出现');

      // 「立即打卡」完成闭环（合成建议 id 来自 item.toAdvice()）
      final syntheticId = todo.toAdvice().id;
      await tester.tap(find.text('立即打卡'), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(store.cardState(PeriodScope.today, syntheticId).isDone, isTrue,
          reason: '提醒对话框「立即打卡」完成打卡闭环');
      expect(find.text('立即打卡'), findsNothing, reason: '打卡后对话框关闭');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      store.dispose();
    },
    timeout: Timeout(const Duration(minutes: 20)),
  );
}
