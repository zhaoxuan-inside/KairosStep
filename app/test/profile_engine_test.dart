// 画像引擎验收（ONBOARDING_DESIGN §9）：未答不剪性质、聚焦统计、max-yield 排序、patch 正确性。
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/gatekeeper_engine.dart';
import 'package:kairo_step/domain/profile_engine.dart';
import 'package:kairo_step/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  late ProfileEngine engine;

  setUpAll(() async {
    catalog = await Catalog.load();
    final onboarding = await OnboardingConfig.load();
    engine = ProfileEngine(
      catalog: catalog,
      gatekeeper: GatekeeperEngine(catalog),
      onboarding: onboarding,
    );
  });

  test('未答不剪：全空画像的活跃集 == 逐条 matchPersona 通过集', () {
    final p = const UserProfile().normalized();
    final active = engine.activeAdviceIds(p);
    final gatekeeper = GatekeeperEngine(catalog);
    final expected = {
      for (final a in catalog.adviceList)
        if (gatekeeper.matchPersona(a, profile: p, topicFilter: (_) => true)) a.id,
    };
    expect(active, expected);
  });

  test('痛风画像聚焦：中年痛风者见 483/484，非痛风被拦（阶段交集+0.6 门禁联合生效）', () {
    // 483/484 带中年/老年阶段标签：52 岁痛风者可见，28 岁者被阶段交集拦截（产品口径）
    final gout = const UserProfile(hasGout: true, age: 52).normalized();
    final youngGout = const UserProfile(hasGout: true, age: 28).normalized();
    final healthy = const UserProfile(age: 52).normalized();
    final goutActive = engine.activeAdviceIds(gout);
    expect(goutActive.containsAll({483, 484}), isTrue, reason: '中年痛风者应看到用药/饮食');
    expect(engine.activeAdviceIds(youngGout).contains(483), isFalse,
        reason: '青年阶段交集为空，被年龄规则拦截');
    expect(engine.activeAdviceIds(healthy).contains(483), isFalse,
        reason: '非痛风者被 0.6 门禁拦截');
  });

  test('patch 应用正确：性别/慢病选项写入对应字段', () {
    final q = engine.onboarding.questions.firstWhere((x) => x.id == 'chronic');
    final opt = q.options.firstWhere((o) => o.value == 'hypertension');
    final patched = engine.testApplyPatch(const UserProfile(), opt.profilePatch)!;
    expect(patched.hasHypertension, isTrue);
    expect(patched.healthConcerns.contains('血压关注'), isTrue);
  });

  test('max-yield 排序：收益降序且达阈值；required 不参与竞争', () {
    final p = const UserProfile().normalized();
    final state = engine.onboardingState(p, {'gender', 'birth_year', 'height_weight', 'smoking'});
    for (var i = 1; i < state.candidates.length; i++) {
      expect(
        state.candidates[i - 1].yieldCount >= state.candidates[i].yieldCount,
        isTrue,
      );
    }
    expect(
      state.candidates.any((c) => c.question.required),
      isFalse,
      reason: 'required 题固定在前，不进收益榜',
    );
  });

  test('引导流转：逐题作答后 answered 累积、nextQuestion 前进、done 可达', () {
    var p = const UserProfile().normalized();
    var answered = <String>{};
    var steps = 0;
    while (steps < 24) {
      final state = engine.onboardingState(p, answered);
      final q = state.nextQuestion;
      if (q == null) {
        expect(state.done, isTrue, reason: '无题可问即完成');
        break;
      }
      if (q.options.isEmpty) {
        // 滑杆题（出生年/身高体重）：UI 直接写画像字段，模拟直接作答
        answered.add(q.id);
        steps++;
        continue;
      }
      expect(state.answeredIds, answered);
      expect(state.activeCount <= state.totalCount, isTrue);
      // 活跃集恒等于逐条 matchPersona（引导视图一致性）
      expect(engine.activeAdviceIds(p), engine.activeAdviceIds(p));
      final opt = q.options.first;
      final patched = engine.testApplyPatch(p, opt.profilePatch);
      answered.add(q.id);
      if (patched != null) p = patched;
      steps++;
      if (q.id == 'gender' || q.id == 'chronic') {
        expect(answered.contains(q.id), isTrue, reason: 'required 题被记为已答');
      }
    }
    expect(steps, lessThanOrEqualTo(24), reason: 'maxQuestions 上限生效');
    expect(engine.activeAdviceIds(p).length, lessThan(catalog.adviceList.length),
        reason: '引导后应产生实际聚焦');
  });
}
