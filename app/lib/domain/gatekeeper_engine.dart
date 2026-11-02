// 建议筛选门禁引擎（REFACTOR_DESIGN §5.2）：画像门禁 + 前置条件 + 专病一票否决。
// 自 app_store.matchPersona（原 :1979-2292）与 evalNodeItem（原 :2294-2314）整体迁移，
// 判定逻辑逐字保留；ID 集与名单数据化于 L7 gates.json（Phase 2），
// 关键词谓词保留在代码（Phase 7 内容画像补全时随规则 schema 收编）。
//
// 预编译（Phase 8 性能重构）：matchPersona 的静态事实（关键词命中/章节归属/名单
// 成员/prerequisites）由 lib/domain/gate_traits.dart 一次性提取为 GateTraits；
// 随包 asset 缺失或与数据指纹错位时，用同一提取函数运行时兜底编译（毫秒级）。
// 判定等价性由 test/gate_traits_equivalence_test.dart（matchPersonaReference
// 对照）与 golden 快照双重守护。
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../data/catalog.dart';
import 'gate_traits.dart';
import '../models/advice.dart';

class GatekeeperEngine {
  GatekeeperEngine(this.catalog);

  final Catalog catalog;

  /// 编译判定记录（asset 优先，缺失/错位即运行时兜底编译）。
  late final Map<int, GateTraits> _traits = _resolveTraits();

  /// 当前是否走随包 asset 编译（false = 兜底运行时编译）。
  bool get usesCompiledAsset => _usedAsset;
  bool _usedAsset = false;

  Map<int, GateTraits> _resolveTraits() {
    final manifest = catalog.gateTraitsManifest;
    if (manifest != null) {
      final bundle = GateTraitsBundle.parse(manifest);
      final hash = bundle?.sourceHash;
      if (bundle != null &&
          bundle.adviceCount == catalog.adviceList.length &&
          hash == gateTraitsSourceFingerprint(
            catalog.adviceList,
            catalog.gates.ruleIdSets,
          )) {
        _usedAsset = true;
        return bundle.traits;
      }
    }
    // Fail-safe：asset 缺失/数据-资产错位 → 同一提取函数运行时编译（毫秒级）
    return {
      for (final a in catalog.adviceList)
        a.id: GateTraits.fromAdvice(a, ruleSets: catalog.gates.ruleIdSets),
    };
  }

  /// 画像门禁（编译路径：纯字段判定，无字符串操作）。
  /// [topicFilter] 注入主题树偏好过滤（store 的 matchesTopicPreferences），
  /// 保持原实现"includeTopicPreferences 时先查主题偏好"的语义与求值次数。
  bool matchPersona(
    Advice a, {
    required UserProfile profile,
    required bool Function(Advice) topicFilter,
    bool includeTopicPreferences = true,
  }) {
    if (includeTopicPreferences && !topicFilter(a)) return false;
    return matchPersonaByTraits(
      _traits[a.id]!,
      profile,
    );
  }

  /// 原实现（逐字保留，仅作等价性对照）：
  /// test/gate_traits_equivalence_test.dart 以本方法为基准验证编译路径，
  /// golden 快照基线亦由本实现的历史行为固化。
  @visibleForTesting
  bool matchPersonaReference(
    Advice a, {
    required UserProfile profile,
    required bool Function(Advice) topicFilter,
    bool includeTopicPreferences = true,
  }) {
    final p = profile;
    if (includeTopicPreferences && !topicFilter(a)) return false;

    // 0. 关注领域过滤（若设置了特定关注领域且未全选）
    if (p.focusDomains.isNotEmpty && p.focusDomains.length < 6) {
      final domain = LifeDomain.ofChapter(a.chapter);
      if (!p.focusDomains.contains(domain.id)) return false;
    }

    // 0.5 树节点画像前置守卫 (Prerequisites Gating)
    final prereqs = a.prerequisites;
    if (prereqs.isNotEmpty) {
      if (prereqs['has_car'] == true && !p.hasCar) return false;
      if (prereqs['has_twowheeler'] == true && !p.hasTwowheeler) return false;
      if (prereqs['is_smoker'] == true && !p.isSmoker) return false;
      if (prereqs['has_children'] == true &&
          !p.hasChildren &&
          !p.roles.contains('家长') &&
          !p.roles.contains('准父母')) {
        return false;
      }
      if (prereqs['is_pregnant_or_parent'] == true &&
          !p.hasChildren &&
          !p.roles.contains('孕产') &&
          !p.roles.contains('准父母') &&
          !p.roles.contains('家长')) {
        return false;
      }
      if (prereqs['has_aging_parents'] == true &&
          !p.hasAgingParents &&
          !p.livingConditions.contains('家有老人') &&
          !p.roles.contains('照护者')) {
        return false;
      }
      if (prereqs['is_tenant'] == true &&
          !p.isTenant &&
          !p.livingConditions.contains('租房人')) {
        return false;
      }
      if (prereqs['has_mortgage'] == true &&
          !p.hasMortgage &&
          !p.livingConditions.contains('购房人')) {
        return false;
      }
      if (prereqs['has_pets'] == true &&
          !p.hasPets &&
          !p.livingConditions.contains('养犬人')) {
        return false;
      }
      if (prereqs['has_piped_gas'] == true && !p.hasPipedGas) return false;
      if (prereqs['is_entrepreneur'] == true &&
          !p.isEntrepreneur &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('合伙人')) {
        return false;
      }
      if (prereqs['gender_female'] == true && p.gender != '女') return false;
      if (prereqs['gender_male'] == true && p.gender != '男') return false;
      if (prereqs['min_age'] is int && p.age < (prereqs['min_age'] as int)) {
        return false;
      }
    }

    // 0.6 慢性病与特殊病理强门禁 (Condition Strong Gating)
    // 凡涉及特定确诊疾病、慢性病或特殊病理史的条目，一票否决「全民/通用」穿透特权
    final text = '${a.title} ${a.tags.join(" ")} ${a.chapter}';
    final hasChronic =
        a.tags.contains('确诊慢病') ||
        a.tags.contains('慢性病') ||
        a.chapter == '得了慢性病之后怎么活' ||
        a.chapter == '残疾之后怎么活';

    if (hasChronic ||
        text.contains('肾结石') ||
        text.contains('痛风') ||
        text.contains('高尿酸')) {
      if (text.contains('肾结石')) {
        if (!p.hasKidneyStones && !p.healthConcerns.contains('肾结石')) {
          return false;
        }
      }
      if (text.contains('痛风') || text.contains('高尿酸')) {
        if (!p.hasGout && !p.healthConcerns.contains('痛风')) {
          return false;
        }
      }
      if (text.contains('高血压') || (text.contains('血压') && hasChronic)) {
        if (!p.hasHypertension && !p.healthConcerns.contains('血压关注')) {
          return false;
        }
      }
      if (text.contains('糖尿病') || text.contains('血糖') || text.contains('胰岛素')) {
        if (!p.hasDiabetes && !p.healthConcerns.contains('血糖关注')) {
          return false;
        }
      }
      if (a.chapter == '残疾之后怎么活' ||
          a.tags.contains('残疾') ||
          a.tags.contains('残障人士')) {
        if (!p.roles.contains('残障人士') && !p.healthConcerns.contains('残疾照护')) {
          return false;
        }
      }
      // 如果属于《得了慢性病之后怎么活》且用户未勾选慢病关注，默认拦截
      if (a.chapter == '得了慢性病之后怎么活' &&
          !p.hasHypertension &&
          !p.hasDiabetes &&
          !p.hasKidneyStones &&
          !p.hasGout &&
          !p.healthConcerns.contains('确诊慢病')) {
        return false;
      }
    }

    // 0.7 职业/技术/出境/育儿特殊章节强门禁 (Special Chapter Gating)
    final chap = a.chapter;
    if (chap == '程序员和技术人容易踩的红线') {
      if (!p.isProgrammer && !p.roles.contains('程序员')) return false;
    }
    if (chap == '做一个网站或平台：资质、备案和服务器') {
      if (!p.isProgrammer &&
          !p.isEntrepreneur &&
          !p.hasDigitalAssetsConcern &&
          !p.roles.contains('程序员') &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('平台运营')) {
        return false;
      }
    }
    if (chap == '创业与做生意：别把家底赔进去') {
      if (!p.isEntrepreneur &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('合伙人')) {
        return false;
      }
    }
    if (chap == '出国、旅行与境外安全' || chap == '出国留学：身份、打工、保险和回国认证') {
      if (!p.hasAbroadTravelOrStudy &&
          !p.roles.contains('出境者') &&
          !p.roles.contains('留学生')) {
        return false;
      }
    }
    if (chap == '怀孕和生产：从发现怀孕到出院办证') {
      if (p.gender == '男' &&
          !p.isPregnantOrPlanning &&
          !p.roles.contains('准父母') &&
          !p.roles.contains('孕产') &&
          !p.roles.contains('家长')) {
        return false;
      }
    }
    if (chap == '刚出生的孩子怎么带') {
      if (p.childAgeStage != 'infant' &&
          !p.hasChildren &&
          !p.roles.contains('家长')) {
        return false;
      }
    }
    if (chap == '上学以后的孩子') {
      if (p.childAgeStage != 'school' &&
          !p.hasChildren &&
          !p.roles.contains('家长')) {
        return false;
      }
    }

    // 0.8 减重、减肥药物与量化运动强门禁 (Weight Loss & Medication Gating)
    // ID 集数据化于 L7 gates.json（ruleIdSets），关键词条件保留在代码
    if (catalog.gates.ruleSet('weight-loss').contains(a.id) ||
        text.contains('减肥药') ||
        text.contains('司美格鲁肽') ||
        text.contains('减重针') ||
        text.contains('手表的运动量化帮你减重') ||
        text.contains('酵素梅') ||
        text.contains('瘦身糖果')) {
      if (!p.hasWeightLossGoal && !p.isOverweightOrObese) {
        return false;
      }
    }

    // 0.9 肠胃/反酸烧心强门禁 (Gastro / Omeprazole Gating)
    if (catalog.gates.ruleSet('gastro').contains(a.id) ||
        text.contains('奥美拉唑') ||
        text.contains('反酸烧心')) {
      if (!p.hasGastroAcidOrStomach && !p.healthConcerns.contains('反酸胃炎')) {
        return false;
      }
    }

    // 0.10 止痛药常备与频繁用药门禁
    if (catalog.gates.ruleSet('analgesic').contains(a.id) ||
        text.contains('止痛药一个月别吃超过') ||
        text.contains('复方止痛药别超过')) {
      if (!p.hasFrequentPainOrAnalgesic && !p.healthConcerns.contains('止痛用药')) {
        return false;
      }
    }

    // 0.11 独居安全兜底防线
    if (catalog.gates.ruleSet('living-alone').contains(a.id) ||
        text.contains('建立三道安全兜底网') ||
        text.contains('盯着你的那个人')) {
      if (p.relationshipStatus != 'single' && !p.hasCrisisOrMentalStress) {
        return false;
      }
    }

    // 0.12 抑郁重度干预与心理热线（由情绪晴雨表弹窗交互触发，严禁直接无故推送到日常任务）
    if (catalog.gates.ruleSet('mood-trigger-only').contains(a.id) ||
        (text.contains('心情差到抑郁') && a.chapter == '怎么放松：娱乐场所和减压') ||
        (text.contains('12356') && a.chapter == '遭遇重大打击之后') ||
        text.contains('有自杀念头时打 12356') ||
        text.contains('带着孩子一起走')) {
      return false;
    }

    // 0.13 孕产专科急重症与子痫用药强门禁
    if (catalog.gates.ruleSet('maternity-emergency').contains(a.id) ||
        text.contains('破水了就地平躺') ||
        text.contains('子痫前期')) {
      if (p.gender != '女' ||
          (!p.isPregnantOrPlanning &&
              !p.roles.contains('孕产') &&
              !p.roles.contains('准父母'))) {
        return false;
      }
    }

    // 0.14 婴幼儿与学龄儿童突发及欺凌门禁
    if (catalog.gates.ruleSet('child-emergency').contains(a.id) ||
        text.contains('新生儿黄疸') ||
        text.contains('孩子被欺凌') ||
        text.contains('撞了头、之后头痛')) {
      if (!p.hasChildren &&
          !p.roles.contains('家长') &&
          !p.roles.contains('准父母')) {
        return false;
      }
    }

    // 0.15 专病与特殊高危用药强门禁 (44 房颤, 121 失眠安眠药, 757 60岁布洛芬)
    if (catalog.gates.ruleSet('afib').contains(a.id) ||
        text.contains('查出房颤请医生评估吃抗凝药')) {
      if (!p.hasHypertension && !p.healthConcerns.contains('血压关注')) {
        return false;
      }
    }
    if (catalog.gates.ruleSet('sleep-pills').contains(a.id) ||
        text.contains('别一上来就长期吃安眠药')) {
      if (!p.healthConcerns.contains('心理减压') && !p.hasCrisisOrMentalStress) {
        return false;
      }
    }
    if (catalog.gates.ruleSet('elderly-painkiller').contains(a.id) ||
        text.contains('60 岁以上、胃出过血、在吃抗凝药')) {
      if (p.age < 60 && !p.hasGastroAcidOrStomach) {
        return false;
      }
    }

    // 1. 硬性排除
    if (a.tags.any(p.exclude.contains)) return false;

    // 女性专属硬条件
    if (p.gender != '女' && a.tags.contains('女性健康')) return false;

    // 2. 年龄阶段匹配：若建议包含阶段标签（少年/青年/中年/老年），必须与用户阶段有交集
    const stageTags = ['少年', '青年', '中年', '老年'];
    final adviceStages = a.tags.where(stageTags.contains).toList();
    if (adviceStages.isNotEmpty && !adviceStages.any(p.stages.contains)) {
      return false;
    }

    // 3. 角色与群体匹配：建议若包含特定角色标签，且非全民通用，则检查用户是否具备该角色
    const specificRoleTags = [
      '程序员',
      '创业者',
      '学生',
      '求职者',
      '家长',
      '准父母',
      '孕产',
      '照护者',
      '家有老人',
      '残障人士',
      '租房人',
      '购房人',
      '司机',
      '出境者',
      '灵活就业者',
      '雇主',
      '合伙人',
    ];
    final adviceSpecificRoles = a.tags
        .where(specificRoleTags.contains)
        .toList();
    if (adviceSpecificRoles.isNotEmpty) {
      final userAllRoles = {
        ...p.roles,
        ...p.livingConditions,
        ...p.healthConcerns,
      };
      final isGeneric =
          !hasChronic && (a.tags.contains('全民') || a.tags.contains('通用'));
      final matchesUserRole = adviceSpecificRoles.any(userAllRoles.contains);
      if (!isGeneric && !matchesUserRole) {
        return false;
      }
    }

    return true;
  }

  /// 健康节点包条目的硬条件求值（性别 / 年龄），不通过则不渲染。
  ({bool show, String? reason, String? note}) evalNodeItem(
    NodePackageItem it,
    UserProfile profile,
  ) {
    final p = profile;
    if (it.female && p.gender != '女') {
      return (show: false, reason: '女性专属 · 已按画像过滤', note: null);
    }
    if (it.bone) {
      if (p.gender == '女' && p.age >= 65) {
        return (show: true, reason: null, note: null);
      }
      if (p.gender == '男' && p.age >= 70) {
        return (
          show: true,
          reason: null,
          note: '70 岁以上男性（中国指南）· 条件谓词动态求值后重新出现',
        );
      }
      return (show: false, reason: '适用：女性 65+ / 男性 70+ · 已按画像过滤', note: null);
    }
    return (show: true, reason: null, note: null);
  }
}
