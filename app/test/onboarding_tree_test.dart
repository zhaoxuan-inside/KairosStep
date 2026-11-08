import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/gatekeeper_engine.dart';
import 'package:kairo_step/domain/profile_engine.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/ui/onboarding/onboarding_view.dart';
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

  Set<String> visible(Map<String, Set<String>> answers) =>
      engine.onboarding.visibleQuestions(answers).map((q) => q.id).toSet();

  test('unknown parents do not open details; males do not enter self-pregnancy branch', () {
    expect(visible({}), isNot(contains('pregnancy')));
    expect(
      visible({
        'gender': {'male'},
      }),
      isNot(contains('pregnancy')),
    );
    expect(
      visible({
        'gender': {'female'},
      }),
      contains('pregnancy'),
    );
    expect(visible({}), isNot(contains('children')));
    expect(
      visible({
        'family_context': {'none'},
      }),
      isNot(contains('children')),
    );
    expect(
      visible({
        'family_context': {'children'},
      }),
      contains('children'),
    );
    expect(
      visible({
        'health_context': {'none'},
      }),
      isNot(contains('medications')),
    );
    expect(
      visible({
        'health_context': {'medications'},
      }),
      contains('medications'),
    );
  });

  test(
    'root questions precede detailed branches and tree metadata is valid',
    () {
      engine.onboarding.validateTree();
      final questions = engine.onboarding.visibleQuestions({
        'gender': {'female'},
        'family_context': {'children', 'pets'},
        'health_context': {'weight', 'chronic'},
        'work_status': {'employed'},
        'living_type': {'rent'},
      });
      var reachedDetail = false;
      for (final q in questions) {
        if (q.parentId != null) {
          reachedDetail = true;
          expect(
            questions.indexWhere((parent) => parent.id == q.parentId),
            lessThan(questions.indexOf(q)),
          );
        } else {
          expect(reachedDetail, isFalse);
        }
      }
      final q = engine.onboarding.questions.first;
      final cycle = OnboardingQuestion(
        id: q.id,
        layer: q.layer,
        tier: q.tier,
        required: false,
        kind: q.kind,
        prompt: q.prompt,
        skipAllowed: true,
        softOnly: false,
        options: q.options,
        parentId: q.id,
      );
      final broken = OnboardingConfig(
        pruning: engine.onboarding.pruning,
        layers: engine.onboarding.layers,
        questions: [cycle],
      );
      expect(broken.validateTree, throwsFormatException);
    },
  );

  test(
    'changing parents clears stale fields and answers from a saved profile',
    () {
      final old = engine.replayDraft({
        'gender': {'female'},
        'pregnancy': {'expecting'},
        'family_context': {'children', 'pets'},
        'children': {'infant'},
        'pets': {'yes'},
        'health_context': {'chronic'},
        'chronic': {'hypertension'},
      });
      expect(old.isPregnantOrPlanning, isTrue);
      expect(old.hasChildren, isTrue);
      final changed = engine.replayDraft({
        'gender': {'male'},
        'pregnancy': {'expecting'},
        'family_context': {'pets'},
        'children': {'infant'},
        'pets': {'yes'},
        'health_context': {'none'},
        'chronic': {'hypertension'},
      }, base: old);
      expect(changed.isPregnantOrPlanning, isFalse);
      expect(changed.hasChildren, isFalse);
      expect(changed.childAgeStage, 'none');
      expect(changed.hasHypertension, isFalse);
      expect(changed.roles, isNot(contains('孕产')));
      expect(changed.roles, isNot(contains('家长')));
      expect(changed.hasPets, isTrue);
      final reopened = engine.replayDraft({
        'family_context': {'children'},
      }, base: old);
      expect(
        reopened.childAgeStage,
        'none',
        reason:
            'a reopened branch must not resurrect its removed detail answer',
      );
      expect(changed.onboardingAnswers.keys, isNot(contains('pregnancy')));
      expect(changed.onboardingAnswers.keys, isNot(contains('children')));
      expect(changed.onboardingAnswers.keys, isNot(contains('chronic')));
      expect(
        UserProfile.fromJson(changed.toJson()).onboardingAnswers,
        changed.onboardingAnswers,
      );
    },
  );

  test('shared facts survive a hidden sibling reset; clearing a detail is effective', () {
    final p = engine.replayDraft({
      'health_context': {'medications'},
      'medications': {'gastro', 'weight_loss'},
    });
    expect(p.hasGastroAcidOrStomach, isTrue);
    expect(p.hasWeightLossGoal, isTrue);
    final cleared = engine.replayDraft({
      'health_context': {'medications'},
      'medications': <String>{},
    }, base: p);
    expect(cleared.medications, isEmpty);
    expect(cleared.hasGastroAcidOrStomach, isFalse);
    expect(cleared.hasWeightLossGoal, isFalse);
    final unknown = engine.replayDraft({}, base: p);
    expect(
      unknown.medications,
      p.medications,
      reason: 'unanswered is not a negative answer',
    );
  });

  testWidgets(
    'male first-run route skips pregnancy and only opens selected family details',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(catalog, await SharedPreferences.getInstance());
      await store.restore();
      await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('安心开启'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('男'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      var childVisited = false;
      for (var i = 0; i < 40; i++) {
        expect(find.text('你本人目前是否处于备孕或孕产阶段？'), findsNothing);
        if (find.text('画像已成形').evaluate().isNotEmpty) break;
        if (find.text('你目前涉及哪些家庭关系或照护责任？').evaluate().isNotEmpty) {
          await tester.tap(find.text('子女养育'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('下一题'));
        } else if (find.text('你的孩子年龄段').evaluate().isNotEmpty) {
          childVisited = true;
          await tester.tap(find.text('婴幼儿期（0-3 岁）'));
          await tester.pumpAndSettle(const Duration(milliseconds: 600));
        } else {
          await tester.tap(find.text('跳过此题'));
        }
        await tester.pumpAndSettle();
      }
      expect(childVisited, isTrue);
      await tester.tap(find.text('以此配置直接开启'));
      await tester.pumpAndSettle();
      expect(store.profile.hasChildren, isTrue);
      expect(store.profile.isPregnantOrPlanning, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'reconfiguring gender discards an old pregnancy answer and its facts',
    (tester) async {
      SharedPreferences.setMockInitialValues({'kHasCompletedOnboarding': true});
      final store = AppStore(catalog, await SharedPreferences.getInstance());
      await store.restore();
      store.profile = engine.replayDraft({
        'gender': {'female'},
        'pregnancy': {'expecting'},
      });
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
      await tester.tap(find.text('男'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('以此配置直接开启'));
      await tester.pumpAndSettle();
      expect(store.profile.gender, '男');
      expect(store.profile.isPregnantOrPlanning, isFalse);
      expect(
        store.profile.onboardingAnswers.keys,
        isNot(contains('pregnancy')),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
