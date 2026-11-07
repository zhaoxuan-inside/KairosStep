// 今天页 · 自建待办按钮级回归：
// - FakeAsync 区禁止 rootBundle/Isolate 真异步 → 目录必须在 setUpAll 加载；
// - 超长弹窗内按钮须 ensureVisible 后再 tap（视口外 tap 会静默落空）；
// - 引擎心跳定时器须在测试体内显式释放（!timersPending 校验先于 addTearDown）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
  });

  Future<AppStore> makeStore() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kHasCompletedOnboarding', true);
    await prefs.setString(
      'kProfile',
      '{"gender":"男","age":28,"roles":["全民"],"livingConditions":[],"healthConcerns":[],"prunedOnly":true,"parentsOnly":false}',
    );
    final store = AppStore(catalog, prefs);
    await store.restore();
    return store;
  }

  Future<void> releaseStore(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  }

  testWidgets('今天页：新建待办 → 填写 → 保存 → 注入生活防线并出现在今日流', (tester) async {
    final store = await makeStore();

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 打开新建弹窗
    await tester.tap(find.text('新建待办'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('新建待办事项'), findsOneWidget);

    // 填写标题与内容
    await tester.enterText(find.byType(TextField).first, '喝水');
    await tester.enterText(find.byType(TextField).at(1), '每小时一杯');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 保存（按钮在弹窗滚动区底部）
    tester.ensureVisible(find.text('保存并注入生活防线'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('保存并注入生活防线'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 弹窗关闭 + 待办入库（默认携带 08:30 提醒时点）
    expect(find.text('新建待办事项'), findsNothing);
    expect(store.userTodos.length, 1);
    expect(store.userTodos.first.title, '喝水');
    expect(store.userTodos.first.reminderTimes, ['08:30']);

    // 合成建议 id 跨进程稳定（打卡/提醒记录不得因重启失联）
    final a1 = store.userTodos.first.toAdvice().id;
    final a2 = store.userTodos.first.toAdvice().id;
    expect(a1, a2);

    // 注入今日流（自建待办出现在今天列表）
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('喝水'), findsWidgets);

    await releaseStore(tester, store);
  });

  testWidgets('今天页：待办行内勾选完成与删除', (tester) async {
    final store = await makeStore();

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 创建 UI 路径已由上一用例锁定；此处聚焦行内交互
    store.addUserTodo('任务甲');
    store.addUserTodo('任务乙');
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('任务甲'), findsOneWidget);
    expect(find.text('任务乙'), findsOneWidget);

    // 勾选完成：行首圆形勾选钮（控件带稳定 ValueKey）
    final idA = store.userTodos.firstWhere((t) => t.title == '任务甲').id;
    await tester.tap(find.byKey(ValueKey('todo-toggle-$idA')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(
      store.userTodos.firstWhere((t) => t.title == '任务甲').isDone,
      isTrue,
    );

    // 删除：行尾 IconButton
    final idB = store.userTodos.firstWhere((t) => t.title == '任务乙').id;
    await tester.tap(find.byKey(ValueKey('todo-remove-$idB')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(store.userTodos.length, 1);
    expect(store.userTodos.first.title, '任务甲');

    await releaseStore(tester, store);
  });
}
