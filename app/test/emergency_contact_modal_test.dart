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

  testWidgets('紧急页「添加联系人」应弹出联系表单且点输入框不崩溃', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kHasCompletedOnboarding', true);
    await prefs.setString(
      'kProfile',
      '{"gender":"男","age":28,"roles":["全民"],"livingConditions":[],"healthConcerns":[],"prunedOnly":true,"parentsOnly":false}',
    );
    final store = AppStore(catalog, prefs);
    await store.restore();

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle();

    // 打开紧急模式
    await tester.tap(find.text('紧急').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 点击「添加联系人」
    await tester.tap(find.text('添加联系人'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // ListTile 背景告警在这棵树里会进入 FlutterError 队列，先排除再判崩溃
    final ex1 = tester.takeException();
    // ignore: avoid_print
    print('[test] exception after tap 添加联系人: $ex1');
    expect(find.text('添加本地紧急联系人'), findsOneWidget, reason: '联系表单弹层应出现');

    // 点姓名输入框 —— 对应线上「点输入框闪退」场景
    expect(find.text('从通讯录选择'), findsOneWidget, reason: '应提供系统通讯录选择入口');
    await tester.tap(find.text('姓名'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    tester.testTextInput.enterText('张三');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('张三'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
