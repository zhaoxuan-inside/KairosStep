// 门禁编译路径等价性验证：matchPersonaByTraits（编译判定）≡ matchPersonaReference（原实现）。
// 三路覆盖：
//   1. 随包 asset 生效（usesCompiledAsset）——资产-数据指纹一致；
//   2. asset 编译路径 == 参考实现，画像矩阵 × 全部 737 条逐一比对；
//   3. 运行时兜底编译（GateTraits.fromAdvice 直算）== 参考实现（同矩阵）。
// 画像矩阵：空/默认画像 + 引导全部选项 patch（真实作答空间）+ 边界画像 + 确定性伪随机组合。
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/gate_traits.dart';
import 'package:kairo_step/domain/gatekeeper_engine.dart';
import 'package:kairo_step/domain/profile_engine.dart';
import 'package:kairo_step/models/advice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  late GatekeeperEngine gatekeeper;
  late ProfileEngine profileEngine;

  setUpAll(() async {
    catalog = await Catalog.load();
    gatekeeper = GatekeeperEngine(catalog);
    profileEngine = ProfileEngine(
      catalog: catalog,
      gatekeeper: gatekeeper,
      onboarding: catalog.onboarding,
    );
  });

  bool compiled(Advice a, UserProfile p) =>
      gatekeeper.matchPersona(a, profile: p, topicFilter: (_) => true);
  bool reference(Advice a, UserProfile p) =>
      gatekeeper.matchPersonaReference(a, profile: p, topicFilter: (_) => true);

  /// 确定性伪随机（LCG，固定种子——可复现，不依赖 test 随机源）。
  int seed = 20260101;
  int rnd() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed;
  }

  T pick<T>(List<T> xs) => xs[rnd() % xs.length];

  UserProfile randomProfile() {
    final domains = ['health', 'career', 'family', 'finance', 'emergency', 'cadence'];
    return UserProfile(
      gender: pick(['男', '女']),
      age: pick([16, 22, 28, 35, 47, 61, 74, 88]),
      roles: [
        '全民',
        for (final r in [
          '上班族', '程序员', '创业者', '学生', '求职者', '家长', '准父母', '孕产',
          '照护者', '司机', '出境者', '留学生', '灵活就业者', '雇主', '合伙人', '平台运营',
          '残障人士',
        ])
          if (rnd().isOdd) r,
      ],
      livingConditions: [
        for (final c in ['租房人', '购房人', '家有老人', '养犬人', '负债人群'])
          if (rnd().isOdd) c,
      ],
      healthConcerns: [
        for (final h in [
          '久坐伏案', '血压关注', '血糖关注', '肾结石', '痛风', '确诊慢病',
          '心理减压', '反酸胃炎', '止痛用药', '减重管理', '吸烟者', '残疾照护',
        ])
          if (rnd().isOdd) h,
      ],
      focusDomains: [
        for (final d in domains)
          if (rnd().isOdd) d,
      ],
      hasCar: rnd().isOdd,
      hasTwowheeler: rnd().isOdd,
      hasChildren: rnd().isOdd,
      hasAgingParents: rnd().isOdd,
      isSmoker: rnd().isOdd,
      hasPets: rnd().isOdd,
      hasPipedGas: rnd().isOdd,
      hasMortgage: rnd().isOdd,
      isTenant: rnd().isOdd,
      isEntrepreneur: rnd().isOdd,
      hasHypertension: rnd().isOdd,
      hasDiabetes: rnd().isOdd,
      hasKidneyStones: rnd().isOdd,
      hasGout: rnd().isOdd,
      isProgrammer: rnd().isOdd,
      isPregnantOrPlanning: rnd().isOdd,
      hasAbroadTravelOrStudy: rnd().isOdd,
      hasDebtPressure: rnd().isOdd,
      hasDigitalAssetsConcern: rnd().isOdd,
      hasDisabilityCare: rnd().isOdd,
      hasCrisisOrMentalStress: rnd().isOdd,
      heightCm: 140 + rnd() % 71,
      weightKg: 35 + rnd() % 116,
      hasWeightLossGoal: rnd().isOdd,
      hasGastroAcidOrStomach: rnd().isOdd,
      hasFrequentPainOrAnalgesic: rnd().isOdd,
      childAgeStage: pick(['none', 'infant', 'school']),
      relationshipStatus: pick(['single', 'in_love', 'married']),
      livingAlone: rnd().isOdd,
    );
  }

  /// 全部引导选项 patch（真实作答空间）+ 边界画像 + 默认画像。
  List<(String, UserProfile)> buildProfiles() {
    final base = const UserProfile();
    final out = <(String, UserProfile)>[
      ('empty', const UserProfile()),
      ('default', base),
      ('default-normalized', base.normalized()),
      ('female-young', base.copyWith(gender: '女', age: 21)),
      ('female-pregnant', base.copyWith(gender: '女', isPregnantOrPlanning: true, roles: ['全民', '准父母', '孕产'])),
      ('male-elderly', base.copyWith(gender: '男', age: 72, hasAgingParents: true)),
      ('all-flags', base.copyWith(
        hasCar: true, hasTwowheeler: true, hasChildren: true, hasAgingParents: true,
        isSmoker: true, hasPets: true, hasPipedGas: true, hasMortgage: true,
        isTenant: true, isEntrepreneur: true, hasHypertension: true, hasDiabetes: true,
        hasKidneyStones: true, hasGout: true, isProgrammer: true,
        hasAbroadTravelOrStudy: true, hasDebtPressure: true,
        hasDigitalAssetsConcern: true, hasDisabilityCare: true,
        hasCrisisOrMentalStress: true, hasWeightLossGoal: true,
        hasGastroAcidOrStomach: true, hasFrequentPainOrAnalgesic: true,
      )),
      ('no-domain', base.copyWith(focusDomains: <String>[])),
      ('health-only', base.copyWith(focusDomains: ['health'])),
    ];
    // 引导全部选项 patch（含单选互斥与多选追加的真实作答效果）
    for (final q in profileEngine.onboarding.questions) {
      for (final o in q.options) {
        final patched = profileEngine.applyPatch(base, o.profilePatch);
        if (patched != null) out.add(('onboard-${q.id}-${o.value}', patched));
      }
    }
    // 确定性伪随机 40 组
    for (var k = 0; k < 40; k++) {
      out.add(('random-$k', randomProfile()));
    }
    return out;
  }

  test('随包 asset 生效（编译路径启用，非兜底）', () {
    // 惰性解析（late final）：先触发一次判定再断言
    gatekeeper.matchPersona(
      catalog.adviceList.first,
      profile: const UserProfile(),
      topicFilter: (_) => true,
    );
    expect(
      gatekeeper.usesCompiledAsset,
      isTrue,
      reason: 'gate_traits.json 缺失或与随包数据指纹错位——'
          '运行 GATE_TRAITS_UPDATE=1 flutter test test/build_gate_traits_test.dart 重建',
    );
  });

  test('asset 编译路径 == 参考实现（画像矩阵 × 737 条逐一比对）', () {
    final profiles = buildProfiles();
    expect(profiles.length, greaterThan(50));
    for (final (name, p) in profiles) {
      for (final a in catalog.adviceList) {
        expect(
          compiled(a, p),
          reference(a, p),
          reason: '编译/参考实现分歧：profile=$name advice=${a.id}「${a.title}」',
        );
      }
      // 引导视图口径：活跃集一致
      expect(
        {
          for (final a in catalog.adviceList)
            if (compiled(a, p)) a.id,
        },
        {
          for (final a in catalog.adviceList)
            if (reference(a, p)) a.id,
        },
        reason: '活跃集分歧：profile=$name',
      );
    }
  });

  test('运行时兜底编译（fromAdvice 直算）== 参考实现（同矩阵）', () {
    final traitsById = {
      for (final a in catalog.adviceList)
        a.id: GateTraits.fromAdvice(a, ruleSets: catalog.gates.ruleIdSets),
    };
    expect(traitsById.length, catalog.adviceList.length);
    for (final (name, p) in buildProfiles()) {
      for (final a in catalog.adviceList) {
        expect(
          matchPersonaByTraits(traitsById[a.id]!, p),
          reference(a, p),
          reason: '兜底编译/参考实现分歧：profile=$name advice=${a.id}',
        );
      }
    }
  });
}
