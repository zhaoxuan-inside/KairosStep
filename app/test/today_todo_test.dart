// 今天页 · 自建待办按钮级回归：
// - FakeAsync 区禁止 rootBundle/Isolate 真异步 → 目录必须在 setUpAll 加载；
// - 超长弹窗内按钮须 ensureVisible 后再 tap（视口外 tap 会静默落空）；
// - 引擎心跳定时器须在测试体内显式释放（!timersPending 校验先于 addTearDown）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/ui/cards/advice_card.dart';
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

    // 注入今日流：待办以普通建议卡混入（流内懒加载，滚动直到卡片被构建）
    await tester.scrollUntilVisible(
      find.text('喝水'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('喝水'), findsWidgets);

    await releaseStore(tester, store);
  });

  testWidgets('今天页：自建待办以普通建议卡进流，叉号即删除', (tester) async {
    final store = await makeStore();

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 创建 UI 路径已由上一用例锁定；此处聚焦卡片形态的展示与交互
    store.addUserTodo('任务甲');
    store.addUserTodo('任务乙');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 独立专区已移除：待办以普通建议卡出现在今日流（懒加载，滚动至卡片构建）
    expect(find.text('我的自建待办'), findsNothing, reason: '不再单设自建待办专区');
    await tester.scrollUntilVisible(
      find.text('任务甲'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('任务甲'), findsWidgets);

    // 完成态：卡片走普通打卡路径，并同步 UserTodoItem.isDone
    final idA = store.userTodos.firstWhere((t) => t.title == '任务甲').id;
    final cardA = find.ancestor(
      of: find.text('任务甲'),
      matching: find.byType(AdviceCard),
    ).first;
    final doneBtn = find.descendant(
      of: cardA,
      matching: find.textContaining('完成'),
    );
    await tester.ensureVisible(doneBtn.first);
    await tester.pumpAndSettle();
    await tester.tap(doneBtn.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
      store.userTodos.firstWhere((t) => t.id == idA).isDone,
      isTrue,
      reason: '卡片打卡应同步待办完成态',
    );

    // 删除：卡片叉号（tooltip 已语义化为「删除待办」）
    final crossB = find.descendant(
      of: find.ancestor(
        of: find.text('任务乙'),
        matching: find.byType(AdviceCard),
      ),
      matching: find.byTooltip('删除待办'),
    );
    await tester.ensureVisible(crossB.first);
    await tester.pumpAndSettle();
    await tester.tap(crossB.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(store.userTodos.length, 1);
    expect(store.userTodos.first.title, '任务甲');

    await releaseStore(tester, store);
  });
}
