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

  Future<void> scenario(
    WidgetTester tester, {
    required Size logicalSize,
    required double bottomInset,
    required String name,
  }) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = Size(
      logicalSize.width * 3,
      logicalSize.height * 3,
    );
    addTearDown(tester.view.reset);

    final store = await makeStore();
    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(find.text('新建待办'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 模拟 autofocus 后软键盘弹出（物理像素）
    tester.view.viewInsets = FakeViewPadding(bottom: bottomInset * 3);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final ex = tester.takeException();
    // ignore: avoid_print
    print('[$name] exception=$ex');
    expect(ex, isNull, reason: '$name 打开弹窗+键盘时不应有框架异常');
    expect(find.text('新建自建待办 · 生活防线'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  }

  testWidgets('竖屏 360x640 + 键盘', (tester) async {
    await scenario(
      tester,
      logicalSize: const Size(360, 640),
      bottomInset: 300,
      name: 'portrait',
    );
  });

  testWidgets('小屏 320x568 + 大键盘', (tester) async {
    await scenario(
      tester,
      logicalSize: const Size(320, 568),
      bottomInset: 340,
      name: 'small',
    );
  });

  testWidgets('横屏 640x360 + 键盘', (tester) async {
    await scenario(
      tester,
      logicalSize: const Size(640, 360),
      bottomInset: 200,
      name: 'landscape',
    );
  });
}
