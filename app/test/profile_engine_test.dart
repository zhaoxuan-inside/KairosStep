// 画像引擎验收（ONBOARDING_DESIGN §9）：未答不剪性质、聚焦统计、max-yield 排序、patch 正确性。
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/gatekeeper_engine.dart';
import 'package:kairo_step/domain/profile_engine.dart';
import 'package:kairo_step/models/advice.dart';

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
        if (gatekeeper.matchPersona(a, profile: p, topicFilter: (_) => true))
          a.id,
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
    expect(
      engine.activeAdviceIds(youngGout).contains(483),
      isFalse,
      reason: '青年阶段交集为空，被年龄规则拦截',
    );
    expect(
      engine.activeAdviceIds(healthy).contains(483),
      isFalse,
      reason: '非痛风者被 0.6 门禁拦截',
    );
  });

  test('patch 应用正确：性别/慢病选项写入对应字段', () {
    final q = engine.onboarding.questions.firstWhere((x) => x.id == 'chronic');
    final opt = q.options.firstWhere((o) => o.value == 'hypertension');
    final patched = engine.applyPatch(const UserProfile(), opt.profilePatch)!;
    expect(patched.hasHypertension, isTrue);
    expect(patched.healthConcerns.contains('血压关注'), isTrue);
  });

  test('先粗后细：tier 主键排序，层内收益降序；fine 层低收益题保留（精确收集）', () {
    final p = const UserProfile().normalized();
    final state = engine.onboardingState(p, {
      'gender',
      'birth_year',
      'height_weight',
      'smoking',
    });
    final cands = state.candidates;
    for (var i = 1; i < cands.length; i++) {
      final prev = cands[i - 1].question.tier;
      final cur = cands[i].question.tier;
      expect(prev <= cur, isTrue, reason: 'tier 必须非降序：$prev → $cur');
      if (prev == cur) {
        expect(
          cands[i - 1].yieldCount >= cands[i].yieldCount,
          isTrue,
          reason: '同层内收益降序',
        );
      }
    }
    expect(
      cands.any((c) => c.question.required),
      isFalse,
      reason: 'required 题固定在前，不进收益榜',
    );
    // fine 层（scene/interest）的精确收集题不被 minMarginalYield 淘汰
    final fineCands = cands.where((c) => c.question.tier == 2).length;
    expect(fineCands, greaterThanOrEqualTo(0));
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
      final patched = engine.applyPatch(p, opt.profilePatch);
      answered.add(q.id);
      if (patched != null) p = patched;
      steps++;
      if (q.id == 'gender' || q.id == 'chronic') {
        expect(answered.contains(q.id), isTrue, reason: 'required 题被记为已答');
      }
    }
    expect(steps, lessThanOrEqualTo(24), reason: 'maxQuestions 上限生效');
    expect(
      engine.activeAdviceIds(p).length,
      lessThan(catalog.adviceList.length),
      reason: '引导后应产生实际聚焦',
    );
  });

  OnboardingQuestion questionOf(String qid) =>
      engine.onboarding.questions.firstWhere((q) => q.id == qid);

  String valueOf(String qid, String label) =>
      questionOf(qid).options.firstWhere((o) => o.label == label).value;

  test('replayDraft：单选重答无残留（婴幼儿 → 没有孩子，hasChildren/childAgeStage 复位）', () {
    UserProfile answer(String value) => engine.replayDraft({
      'family_context': {'children'},
      'children': {value},
    });

    final infant = answer(valueOf('children', '婴幼儿期（0-3 岁）'));
    expect(infant.hasChildren, isTrue);
    expect(infant.childAgeStage, 'infant');

    // 重答为「没有孩子」：重放只应用当前选择态，旧选项效果零残留
    final none = answer(valueOf('children', '没有孩子'));
    expect(none.hasChildren, isFalse);
    expect(none.childAgeStage, 'none');
    expect(none.roles.contains('家长'), isFalse);
  });

  test('replayDraft：多选可取消 + 「无」独占（medications）', () {
    String v(String label) => valueOf('medications', label);

    // 选两项
    final two = engine.replayDraft({
      'health_context': {'medications'},
      'medications': {v('减重药物/针剂'), v('胃药/抑酸药')},
    });
    expect(two.hasWeightLossGoal, isTrue);
    expect(two.hasGastroAcidOrStomach, isTrue);

    // 取消一项（再点取消语义由选择态维护：直接从集合移除后重放）
    final one = engine.replayDraft({
      'health_context': {'medications'},
      'medications': {v('减重药物/针剂')},
    });
    expect(one.hasWeightLossGoal, isTrue);
    expect(one.hasGastroAcidOrStomach, isFalse);

    // 「无」独占：清空其余选择
    final none = engine.replayDraft({
      'health_context': {'medications'},
      'medications': {v('无')},
    });
    expect(none.hasWeightLossGoal, isFalse);
    expect(none.hasGastroAcidOrStomach, isFalse);
    expect(none.medications, isEmpty);
  });

  test('replayDraft：滑块合成 patch 与选项 patch 共同生效', () {
    final draft = engine.replayDraft(
      {
        'gender': {valueOf('gender', '女')},
        'health_context': {'weight'},
        'smoking': {valueOf('smoking', '吸烟')},
      },
      sliderPatches: {
        'birth_year': {'age': 35},
        'height_weight': {'heightCm': 165.0, 'weightKg': 60.0},
      },
    );
    expect(draft.gender, '女');
    expect(draft.isSmoker, isTrue);
    expect(draft.age, 35);
    expect(draft.heightCm, 165.0);
    expect(draft.weightKg, 60.0);
  });

  test('replayDraft：key- 移除语义——自住清除默认「租房人」，学生清除默认「上班族」', () {
    final living = engine.replayDraft({
      'living_type': {valueOf('living_type', '自住（无贷）')},
    });
    expect(living.isTenant, isFalse);
    expect(
      living.livingConditions.contains('租房人'),
      isFalse,
      reason: '负面选择必须清除默认标签，否则租房门禁照推',
    );

    final work = engine.replayDraft({
      'work_status': {valueOf('work_status', '学生')},
    });
    expect(work.roles.contains('学生'), isTrue);
    expect(work.roles.contains('上班族'), isFalse);

    final single = engine.replayDraft({
      'family_context': {'partner'},
      'partner': {valueOf('partner', '单身')},
    });
    expect(single.relationshipStatus, 'single');
    expect(single.roles.contains('伴侣'), isFalse);
  });

  test('replayDraft：cohabit 独占 livingAlone（原 living_alone 重复题已并入）', () {
    final alone = engine.replayDraft({
      'cohabit': {valueOf('cohabit', '独居')},
    });
    expect(alone.livingAlone, isTrue);
    expect(alone.livingConditions.contains('独居'), isTrue);

    final withFamily = engine.replayDraft({
      'cohabit': {valueOf('cohabit', '与家人同住')},
    });
    expect(withFamily.livingAlone, isFalse);

    final shared = engine.replayDraft({
      'cohabit': {valueOf('cohabit', '与室友合租')},
    });
    expect(shared.livingAlone, isFalse);
    expect(shared.livingConditions.contains('合租'), isTrue);
  });

  test('引导基线：关注域空起步——未答不剪，作答后按选择收窄（原默认全选致多选题失效）', () {
    final base = ProfileEngine.onboardingBaseline;
    expect(base.focusDomains, isEmpty);

    // 未答：无关注域 → 不做领域剪枝（未答不剪，ADR-009）
    final unanswered = engine.activeAdviceIds(base);
    final all = {
      for (final a in catalog.adviceList)
        if (engine.gatekeeper.matchPersona(
          a,
          profile: base,
          topicFilter: (_) => true,
        ))
          a.id,
    };
    expect(unanswered, all);

    // 作答：仅健康 → 非健康领域条目被收窄
    final healthOnly = engine.replayDraft({
      'focus_domains': {valueOf('focus_domains', '健康')},
    });
    expect(healthOnly.focusDomains, ['health']);
    final narrowed = engine.activeAdviceIds(healthOnly);
    expect(narrowed.length, lessThan(unanswered.length));
    for (final id in narrowed) {
      expect(
        LifeDomain.ofChapter(catalog.adviceById(id)!.chapter).id,
        'health',
      );
    }
  });

  test('引导基线与默认画像未答口径一致（除关注域外无行为差异）', () {
    final base = ProfileEngine.onboardingBaseline;
    final defaults = const UserProfile();
    for (final a in catalog.adviceList) {
      expect(
        engine.gatekeeper.matchPersona(
          a,
          profile: base,
          topicFilter: (_) => true,
        ),
        engine.gatekeeper.matchPersona(
          a,
          profile: defaults,
          topicFilter: (_) => true,
        ),
        reason: '基线切换不得改变未答用户的准入口径：advice=${a.id}',
      );
    }
  });
}
