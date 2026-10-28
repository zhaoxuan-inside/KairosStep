import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/models/topic_tree.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async => catalog = await Catalog.load());

  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(catalog, await SharedPreferences.getInstance());
  }

  test('all advice have valid leaf memberships and unique parent counts', () {
    expect(catalog.topics.roots.length, 6);
    expect(catalog.adviceList.length, 767);
    for (final item in catalog.adviceList) {
      for (final leaf in item.topicPaths) {
        expect(catalog.topics.byPath[leaf]!.children, isEmpty);
        for (final path in TopicTree.ancestorsOf(leaf)) {
          expect(catalog.topics.adviceIdsUnder(path), contains(item.id));
        }
      }
    }
    final counts = catalog.topics.countsFor(catalog.adviceList);
    expect(counts['health'], catalog.underTopic('health').length);
    expect(
      catalog.underTopic('health').map((a) => a.id).toSet().length,
      catalog.underTopic('health').length,
    );
    expect(catalog.underTopic('healthcare'), isEmpty);
  });

  test('parent names, aliases, details and multiple terms are searchable', () {
    expect(catalog.search('居家安全').map((a) => a.id), containsAll([3, 13]));
    expect(catalog.search('刷屏').map((a) => a.id), contains(137));
    expect(catalog.search('高血压没感觉也要管').map((a) => a.id), contains(7));
    expect(catalog.search('睡眠 节律').map((a) => a.id), contains(98));
    expect(catalog.search('头盔', topicPath: 'health'), isEmpty);
    expect(
      catalog.search('', topicPath: 'daily/commute').map((a) => a.id),
      contains(1),
    );
    expect(catalog.search(''), isEmpty);
    expect(catalog.search('安全', topicPath: 'unknown'), isEmpty);
  });

  test(
    'pruning removes a route, preserves other routes and is persisted',
    () async {
      final first = await store();
      first.excludeTopic('daily/home_safety');
      expect(first.matchesTopicPreferences(catalog.byId[3]!), isTrue);
      expect(
        catalog
            .search(
              '',
              topicPath: 'daily/home_safety',
              hiddenTopics: first.excludedTopicPaths,
            )
            .map((a) => a.id),
        isNot(contains(3)),
      );
      first.excludeTopic('daily');
      expect(first.excludedTopicPaths, {'daily'});
      expect(first.matchesTopicPreferences(catalog.byId[3]!), isFalse);
      expect(first.matchesTopicPreferences(catalog.byId[98]!), isTrue);
      final restored = AppStore(catalog, first.prefs);
      await restored.restore();
      expect(restored.excludedTopicPaths, {'daily'});
      restored.excludeTopic('health');
      expect(restored.matchesTopicPreferences(catalog.byId[98]!), isFalse);
      // Explicit search and the emergency panel remain available for helping others.
      expect(catalog.search('安全带').map((a) => a.id), contains(1));
      expect(restored.emergencyAdvices.map((a) => a.id), contains(397));
      restored.restoreAllTopics();
      expect(restored.excludedTopicPaths, isEmpty);
      expect(restored.matchesTopicPreferences(catalog.byId[98]!), isTrue);
      expect(() => restored.excludeTopic('unknown'), throwsArgumentError);
    },
  );

  test(
    'branch exclusions apply to daily streams even in full library mode',
    () async {
      final subject = await store();
      subject.profile = const UserProfile(isSmoker: true, prunedOnly: false);
      expect(subject.todayAdvices.map((a) => a.id), contains(52));
      subject.excludeTopic('health/mental');
      expect(subject.todayAdvices.map((a) => a.id), isNot(contains(52)));
      subject.restoreTopic('health/mental');
      expect(subject.todayAdvices.map((a) => a.id), contains(52));
    },
  );

  test('legacy records work and invalid paths fail instead of silently disappearing', () {
    final legacy = Advice.fromJson({
      'id': 9000,
      'c': 'test',
      't': 'test',
      'tree_path': 'daily/lifestyle/diet',
    });
    expect(legacy.topicPaths, ['daily/lifestyle/diet']);
    expect(() => TopicTree.fromJson({}, [legacy]), throwsFormatException);
  });

  test('passengers, smoke alarms and housing fund are not gated by asset ownership', () async {
    final subject = await store();
    subject.profile = const UserProfile(
      hasCar: false,
      hasPipedGas: false,
      hasMortgage: false,
    );
    for (final id in [1, 3, 143]) {
      expect(
        subject.matchPersona(catalog.byId[id]!),
        isTrue,
        reason: 'advice $id',
      );
    }
  });

  testWidgets('tree can hide, restore and select a parent at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final subject = await store();
    subject.completeOnboarding(const UserProfile());
    await tester.pumpWidget(KairosApp(catalog: catalog, store: subject));
    await tester.pumpAndSettle();
    await tester.tap(find.text('库'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按主题分类查找与剪枝'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理剪枝'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-toggle-health')));
    await tester.pumpAndSettle();
    expect(subject.excludedTopicPaths, contains('health'));
    await tester.tap(find.byKey(const ValueKey('topic-toggle-health')));
    await tester.pumpAndSettle();
    expect(subject.excludedTopicPaths, isEmpty);
    await tester.tap(find.byKey(const ValueKey('topic-select-daily')));
    await tester.pumpAndSettle();
    expect(find.text('日常与起居'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
