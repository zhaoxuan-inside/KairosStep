import 'dart:convert';
import 'dart:io';

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
  setUpAll(() async => catalog = await Catalog.load());

  Future<AppStore> mount(WidgetTester tester, int id) async {
    SharedPreferences.setMockInitialValues({'kHasCompletedOnboarding': true});
    final store = AppStore(catalog, await SharedPreferences.getInstance());
    await store.restore();
    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: SingleChildScrollView(
                child: AdviceCard(
                  advice: catalog.byId[id]!,
                  scope: PeriodScope.today,
                ),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    return store;
  }

  test('all 737 advice have explicit matched interactions without changing trigger inputs', () {
    expect(
      catalog.displayBindings.byAdvice.keys.toSet(),
      catalog.byId.keys.toSet(),
    );
    expect(catalog.interactionCounts.values.reduce((a, b) => a + b), 737);
    final original =
        (jsonDecode(File('data-src/advice.json').readAsStringSync())['list']
            as List);
    for (final raw in original) {
      final a = catalog.byId[raw['id']]!;
      expect(a.actType, raw['act_type']);
      final plan = catalog.displayBindings.bindingOf(a.id)!;
      expect(plan.stringListParam('items'), isNotEmpty);
      expect(
        plan.stringListParam('items').every((s) => s.trim().isNotEmpty),
        isTrue,
      );
      if (plan.style == 'slider-calc') expect(plan.override, 'record');
      if (plan.style == 'windowed-cadence') expect(plan.override, 'deadline');
    }
    expect(catalog.displayBindings.bindingOf(292)!.style, 'emergency-action');
    expect(catalog.displayBindings.bindingOf(745)!.style, 'redline-stamp');
    expect(
      catalog.displayBindings.bindingOf(516)!.stringListParam('items').length,
      5,
    );
  });

  testWidgets(
    'blood pressure starts empty, validates input and persists real observations beyond scope rollover',
    (tester) async {
      final store = await mount(tester, 7);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.tap(find.text('保存本次实际记录'));
      await tester.pumpAndSettle();
      expect(store.interactionData(7)['records'], isNull);
      expect(find.text('请输入实际数值'), findsNWidgets(2));
      await tester.enterText(find.byKey(const ValueKey('record-7-sys')), '128');
      await tester.enterText(find.byKey(const ValueKey('record-7-dia')), '82');
      await tester.tap(find.text('保存本次实际记录'));
      await tester.pumpAndSettle();
      final records = store.interactionData(7)['records'] as List;
      expect(records.single['values'], {'sys': 128.0, 'dia': 82.0});
      store.checkPeriodRollover(DateTime.now().add(const Duration(days: 8)));
      expect(store.interactionData(7)['records'], records);
      final restored = AppStore(catalog, await SharedPreferences.getInstance());
      await restored.restore();
      expect(restored.interactionData(7)['records'], records);
      restored.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'driving rule has no alcohol calculator and read confirmation is not completion',
    (tester) async {
      final store = await mount(tester, 256);
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('代谢完毕'), findsNothing);
      await tester.tap(find.text('标记已阅读'));
      await tester.pumpAndSettle();
      expect(store.cardState(PeriodScope.today, 256).isDone, isFalse);
      expect(find.text('已标记阅读 · 点击撤销'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      store.checkPeriodRollover(DateTime.now().add(const Duration(days: 2)));
      expect(store.interactionData(256)['readAcknowledged'], isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'emergency instruction uses contextual help rather than simulated stop payment',
    (tester) async {
      final store = await mount(tester, 397);
      expect(find.text('拨打 120'), findsOneWidget);
      expect(find.text('打开紧急求助'), findsOneWidget);
      expect(find.text('立即止付'), findsNothing);
      expect(find.text('已按指引处理完毕'), findsNothing);
      expect(store.cardState(PeriodScope.today, 397).isDone, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'deadline viewing never creates an anchor or an invented fourteen-day period',
    (tester) async {
      final store = await mount(tester, 130);
      expect(store.windowAnchorOf(130), isNull);
      expect(find.text('未设置'), findsOneWidget);
      expect(find.textContaining('/14'), findsNothing);
      store.setInteractionValue(
        130,
        'deadline:自行确认的截止日期',
        DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      );
      await tester.pumpAndSettle();
      expect(find.text('未设置'), findsNothing);
      expect(store.cardState(PeriodScope.today, 130).isDone, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'seat-belt checks have no preconfirmed occupied seats and support real completion',
    (tester) async {
      final store = await mount(tester, 1);
      expect(find.textContaining('四座全部锁止'), findsNothing);
      expect(store.cardState(PeriodScope.today, 1).isDone, isFalse);
      for (final label
          in catalog.displayBindings.bindingOf(1)!.stringListParam('items')) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(store.cardState(PeriodScope.today, 1).isDone, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
