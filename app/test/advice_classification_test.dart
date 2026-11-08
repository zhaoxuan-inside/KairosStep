import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/gatekeeper_engine.dart';
import 'package:kairo_step/domain/profile_engine.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/ui/library/classified_advice_list.dart';
import 'package:kairo_step/ui/onboarding/onboarding_view.dart';
import 'package:kairo_step/ui/cards/advice_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  late ProfileEngine engine;
  setUpAll(() async {
    catalog = await Catalog.load();
    engine = ProfileEngine(
      catalog: catalog,
      gatekeeper: GatekeeperEngine(catalog),
      onboarding: catalog.onboarding,
    );
  });

  test('published classification covers 737 advice and matches source topics/plans', () {
    final plans = {
      for (final row
          in (jsonDecode(
                File('assets/data/triggers/advice_trigger.json')
                    .readAsStringSync(),
              )['list']
              as List))
        row['id']: row,
    };
    for (final a in catalog.adviceList) {
      final c = a.classification!;
      expect(c.primaryTopic, a.topicPaths.first);
      expect(c.topicPaths, a.topicPaths);
      expect(
        c.lane,
        plans[a.id]['emergency'] == true ? 'emergency' : plans[a.id]['mode'],
      );
      expect(a.facets.effectiveTags, isNot(contains('通用')));
      expect(a.facets.effectiveTags, isNot(contains('泛指')));
    }
    final groups = classifyAdvice(catalog.adviceList);
    final ids = groups.expand((g) => g.items.map((a) => a.id)).toList();
    expect(ids.length, 737);
    expect(ids.toSet().length, 737);
  });

  test('old profiles stay unrestricted; topic choices round-trip and clear without residue', () {
    expect(UserProfile.fromJson({}).focusTopics, isEmpty);
    final p = engine.replayDraft(
      {},
      sliderPatches: {
        'focus_topics': {
          'focusTopics': ['daily/commute/vehicle'],
        },
      },
    );
    expect(UserProfile.fromJson(p.toJson()).focusTopics, p.focusTopics);
    final expected = engine
        .activeAdviceIds(ProfileEngine.onboardingBaseline)
        .where(
          (id) =>
              catalog.byId[id]!.topicPaths.contains('daily/commute/vehicle'),
        )
        .toSet();
    expect(engine.activeAdviceIds(p), expected);
    expect(expected, isNotEmpty);
    final cleared = engine.replayDraft(
      {},
      base: p,
      sliderPatches: {
        'focus_topics': {'focusTopics': <String>[]},
      },
    );
    expect(
      engine.activeAdviceIds(cleared),
      engine.activeAdviceIds(ProfileEngine.onboardingBaseline),
    );
  });

  test(
    'cross-list focus and hidden routes must match the same membership',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(catalog, await SharedPreferences.getInstance());
      store.profile = store.profile.copyWith(
        focusTopics: ['daily/home_safety'],
      );
      expect(store.matchesTopicPreferences(catalog.byId[3]!), isTrue);
      store.excludeTopic('daily/home_safety');
      expect(store.matchesTopicPreferences(catalog.byId[3]!), isFalse);
      final groups = classifyAdvice([
        catalog.byId[3]!,
      ], selectedTopic: 'daily/housing');
      expect(groups.single.path, 'daily/housing/facility');
      final restored = AppStore(catalog, await SharedPreferences.getInstance());
      await restored.restore();
      expect(restored.profile.focusTopics, store.profile.focusTopics);
      store.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'reconfigure restores and clears concrete topics in the real onboarding view',
    (tester) async {
      SharedPreferences.setMockInitialValues({'kHasCompletedOnboarding': true});
      final store = AppStore(catalog, await SharedPreferences.getInstance());
      await store.restore();
      store.profile = store.profile.copyWith(
        focusTopics: ['daily/commute/vehicle'],
      );
      await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => OnboardingView(
                isReconfiguring: true,
                initialProfile: store.profile,
              ),
            ),
          );
      await tester.pumpAndSettle();
      final pages = tester.widget<PageView>(find.byType(PageView));
      pages.controller!.jumpToPage(
        catalog.onboarding.layers.indexWhere((l) => l.key == 'interest'),
      );
      await tester.pumpAndSettle();
      expect(find.text('清空 1 项选择'), findsOneWidget);
      await tester.ensureVisible(find.text('清空 1 项选择'));
      await tester.tap(find.text('清空 1 项选择'));
      await tester.pumpAndSettle();
      expect(find.text('暂不限定主题'), findsOneWidget);
      await tester.tap(find.text('以此配置直接开启'));
      await tester.pumpAndSettle();
      expect(store.profile.focusTopics, isEmpty);
      expect(store.profile.roles, isNot(contains('程序员')));
      expect(store.profile.roles, isNot(contains('创业者')));
      expect(store.profile.medications, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'library groups start collapsed and paginate real advice cards at 20',
    (tester) async {
      SharedPreferences.setMockInitialValues({'kHasCompletedOnboarding': true});
      final store = AppStore(catalog, await SharedPreferences.getInstance());
      await store.restore();
      final groups = classifyAdvice(catalog.adviceList)
        ..sort((a, b) => b.items.length.compareTo(a.items.length));
      final group = groups.first;
      expect(group.items.length, greaterThan(20));
      await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: ClassifiedAdviceList(
                  groups: [group],
                  topics: catalog.topics,
                ),
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.byType(AdviceCard), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('advice-domain-${group.path.split('/').first}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdviceCard), findsNothing);
      await tester.tap(find.byKey(ValueKey('advice-group-${group.key}')));
      await tester.pumpAndSettle();
      expect(find.byType(AdviceCard), findsNWidgets(20));
      final firstPage = tester
          .widgetList<AdviceCard>(find.byType(AdviceCard))
          .map((w) => w.advice.id)
          .toSet();
      await tester.ensureVisible(find.text('下一页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一页'));
      await tester.pumpAndSettle();
      final secondPage = tester
          .widgetList<AdviceCard>(find.byType(AdviceCard))
          .map((w) => w.advice.id)
          .toSet();
      expect(secondPage.length, lessThanOrEqualTo(20));
      expect(secondPage.intersection(firstPage), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
