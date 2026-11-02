// 门禁谓词预编译层（Gate Traits）：matchPersona 的静态事实一次提取、运行时纯字段判定。
//
// 为什么存在：原 matchPersona 每次判定都做字符串拼接（title+tags+chapter）与
// 30+ 次 text.contains 全文扫描，而其中绝大多数事实（关键词命中、章节归属、
// 门禁名单成员、prerequisites 取值）与用户画像无关——是每条建议的静态属性。
// 本层把这些静态事实一次性提取为 GateTraits 记录（"规则树"节点），运行时
// matchPersonaByTraits 只做纯字段读取与分支，零字符串操作、零集合分配。
//
// 单一事实源约定：
//   - GateTraits.fromAdvice 同时供离线生成（test/build_gate_traits_test.dart，
//     GATE_TRAITS_UPDATE=1 重建 assets/data/config/gate_traits.json）与运行时
//     兜底编译（asset 缺失/校验失败时）使用——判定逻辑只此一份，不写第二套。
//   - matchPersonaByTraits 与 GatekeeperEngine.matchPersonaReference（原实现
//     逐字保留）分支、顺序、返回语义等价；等价性由 test/gate_traits_equivalence_test.dart
//     （全建议 × 画像矩阵比对）与 golden 快照（737 × 种子画像零漂移）双重守护。
import 'dart:convert';

import '../models/advice.dart';

/// 一条建议的全部静态门禁事实（规则树节点）。
class GateTraits {
  const GateTraits({
    required this.id,
    required this.domainId,
    required this.reqCar,
    required this.reqTwowheeler,
    required this.reqSmoker,
    required this.reqChildren,
    required this.reqPregnantOrParent,
    required this.reqAgingParents,
    required this.reqTenant,
    required this.reqMortgage,
    required this.reqPets,
    required this.reqPipedGas,
    required this.reqEntrepreneur,
    required this.reqGenderFemale,
    required this.reqGenderMale,
    required this.minAge,
    required this.hasChronic,
    required this.kwKidneyStone,
    required this.kwGout,
    required this.kwHyper,
    required this.kwBloodPressure,
    required this.kwDiabetes,
    required this.disabilityChapter,
    required this.disabilityTag,
    required this.chronicChapter,
    required this.chapProgrammer,
    required this.chapDigitalPlatform,
    required this.chapEntrepreneurship,
    required this.chapAbroad,
    required this.chapPregnancy,
    required this.chapInfant,
    required this.chapSchoolAge,
    required this.gateWeightLoss,
    required this.gateGastro,
    required this.gateAnalgesic,
    required this.gateLivingAlone,
    required this.gateMoodOnly,
    required this.gateMaternityEmergency,
    required this.gateChildEmergency,
    required this.gateAfib,
    required this.gateSleepPills,
    required this.gateElderlyPainkiller,
    required this.tags,
    required this.stageTags,
    required this.roleTags,
    required this.femaleOnly,
    required this.isGeneric,
  });

  final int id;
  final String domainId; // LifeDomain.ofChapter(chapter).id（0 关注领域过滤）

  // ── 0.5 prerequisites（类型化展开；'== true' 语义与原实现一致）──
  final bool reqCar;
  final bool reqTwowheeler;
  final bool reqSmoker;
  final bool reqChildren;
  final bool reqPregnantOrParent;
  final bool reqAgingParents;
  final bool reqTenant;
  final bool reqMortgage;
  final bool reqPets;
  final bool reqPipedGas;
  final bool reqEntrepreneur;
  final bool reqGenderFemale;
  final bool reqGenderMale;
  final int? minAge; // prerequisites['min_age'] is int

  // ── 0.6 慢性病与特殊病理（hasChronic ∨ kwKidney ∨ kwGout 进入该组）──
  final bool hasChronic;
  final bool kwKidneyStone; // text ⊇ '肾结石'
  final bool kwGout; // text ⊇ '痛风' ∨ '高尿酸'
  final bool kwHyper; // text ⊇ '高血压'
  final bool kwBloodPressure; // text ⊇ '血压'
  final bool kwDiabetes; // text ⊇ '糖尿病' ∨ '血糖' ∨ '胰岛素'
  final bool disabilityChapter; // chapter == '残疾之后怎么活'
  final bool disabilityTag; // tags ∋ '残疾' ∨ '残障人士'
  final bool chronicChapter; // chapter == '得了慢性病之后怎么活'

  // ── 0.7 职业/技术/出境/育儿章节强门禁 ──
  final bool chapProgrammer;
  final bool chapDigitalPlatform;
  final bool chapEntrepreneurship;
  final bool chapAbroad; // '出国、旅行与境外安全' ∨ '出国留学：…'（原实现同支）
  final bool chapPregnancy;
  final bool chapInfant;
  final bool chapSchoolAge;

  // ── 0.8–0.15 名单 ∨ 关键词 合并门禁旗标（进组即按原实现体判定）──
  final bool gateWeightLoss;
  final bool gateGastro;
  final bool gateAnalgesic;
  final bool gateLivingAlone;
  final bool gateMoodOnly; // 含章节限定关键词的静态折叠
  final bool gateMaternityEmergency;
  final bool gateChildEmergency;
  final bool gateAfib;
  final bool gateSleepPills;
  final bool gateElderlyPainkiller;

  // ── 1/2/3 标签面 ──
  final List<String> tags; // 1. 硬性排除：tags.any(exclude.contains)
  final List<String> stageTags; // ⊆ ['少年','青年','中年','老年']
  final List<String> roleTags; // ⊆ specificRoleTags（17 项）
  final bool femaleOnly; // tags ∋ '女性健康'
  final bool isGeneric; // !hasChronic ∧ (tags ∋ '全民' ∨ '通用')

  // ── 序列化（紧凑：false/null/空列表省略）──

  Map<String, dynamic> toJson() => {
    'id': id,
    'domain': domainId,
    if (reqCar) 'reqCar': true,
    if (reqTwowheeler) 'reqTwo': true,
    if (reqSmoker) 'reqSmoke': true,
    if (reqChildren) 'reqChild': true,
    if (reqPregnantOrParent) 'reqPreg': true,
    if (reqAgingParents) 'reqElder': true,
    if (reqTenant) 'reqTenant': true,
    if (reqMortgage) 'reqMort': true,
    if (reqPets) 'reqPet': true,
    if (reqPipedGas) 'reqGas': true,
    if (reqEntrepreneur) 'reqEnt': true,
    if (reqGenderFemale) 'reqFemale': true,
    if (reqGenderMale) 'reqMale': true,
    if (minAge != null) 'minAge': minAge,
    if (hasChronic) 'chronic': true,
    if (kwKidneyStone) 'kwKidney': true,
    if (kwGout) 'kwGout': true,
    if (kwHyper) 'kwHyper': true,
    if (kwBloodPressure) 'kwBP': true,
    if (kwDiabetes) 'kwSugar': true,
    if (disabilityChapter) 'disChap': true,
    if (disabilityTag) 'disTag': true,
    if (chronicChapter) 'chronicChap': true,
    if (chapProgrammer) 'chProg': true,
    if (chapDigitalPlatform) 'chPlat': true,
    if (chapEntrepreneurship) 'chEnt': true,
    if (chapAbroad) 'chAbroad': true,
    if (chapPregnancy) 'chPreg': true,
    if (chapInfant) 'chInfant': true,
    if (chapSchoolAge) 'chSchool': true,
    if (gateWeightLoss) 'gWL': true,
    if (gateGastro) 'gGastro': true,
    if (gateAnalgesic) 'gAnalg': true,
    if (gateLivingAlone) 'gAlone': true,
    if (gateMoodOnly) 'gMood': true,
    if (gateMaternityEmergency) 'gMatEr': true,
    if (gateChildEmergency) 'gChildEr': true,
    if (gateAfib) 'gAfib': true,
    if (gateSleepPills) 'gSleep': true,
    if (gateElderlyPainkiller) 'gElderPain': true,
    if (tags.isNotEmpty) 'tags': tags,
    if (stageTags.isNotEmpty) 'stages': stageTags,
    if (roleTags.isNotEmpty) 'roles': roleTags,
    if (femaleOnly) 'female': true,
    if (isGeneric) 'generic': true,
  };

  factory GateTraits.fromJson(Map<String, dynamic> j) => GateTraits(
    id: j['id'] as int,
    domainId: j['domain'] as String,
    reqCar: j['reqCar'] as bool? ?? false,
    reqTwowheeler: j['reqTwo'] as bool? ?? false,
    reqSmoker: j['reqSmoke'] as bool? ?? false,
    reqChildren: j['reqChild'] as bool? ?? false,
    reqPregnantOrParent: j['reqPreg'] as bool? ?? false,
    reqAgingParents: j['reqElder'] as bool? ?? false,
    reqTenant: j['reqTenant'] as bool? ?? false,
    reqMortgage: j['reqMort'] as bool? ?? false,
    reqPets: j['reqPet'] as bool? ?? false,
    reqPipedGas: j['reqGas'] as bool? ?? false,
    reqEntrepreneur: j['reqEnt'] as bool? ?? false,
    reqGenderFemale: j['reqFemale'] as bool? ?? false,
    reqGenderMale: j['reqMale'] as bool? ?? false,
    minAge: j['minAge'] as int?,
    hasChronic: j['chronic'] as bool? ?? false,
    kwKidneyStone: j['kwKidney'] as bool? ?? false,
    kwGout: j['kwGout'] as bool? ?? false,
    kwHyper: j['kwHyper'] as bool? ?? false,
    kwBloodPressure: j['kwBP'] as bool? ?? false,
    kwDiabetes: j['kwSugar'] as bool? ?? false,
    disabilityChapter: j['disChap'] as bool? ?? false,
    disabilityTag: j['disTag'] as bool? ?? false,
    chronicChapter: j['chronicChap'] as bool? ?? false,
    chapProgrammer: j['chProg'] as bool? ?? false,
    chapDigitalPlatform: j['chPlat'] as bool? ?? false,
    chapEntrepreneurship: j['chEnt'] as bool? ?? false,
    chapAbroad: j['chAbroad'] as bool? ?? false,
    chapPregnancy: j['chPreg'] as bool? ?? false,
    chapInfant: j['chInfant'] as bool? ?? false,
    chapSchoolAge: j['chSchool'] as bool? ?? false,
    gateWeightLoss: j['gWL'] as bool? ?? false,
    gateGastro: j['gGastro'] as bool? ?? false,
    gateAnalgesic: j['gAnalg'] as bool? ?? false,
    gateLivingAlone: j['gAlone'] as bool? ?? false,
    gateMoodOnly: j['gMood'] as bool? ?? false,
    gateMaternityEmergency: j['gMatEr'] as bool? ?? false,
    gateChildEmergency: j['gChildEr'] as bool? ?? false,
    gateAfib: j['gAfib'] as bool? ?? false,
    gateSleepPills: j['gSleep'] as bool? ?? false,
    gateElderlyPainkiller: j['gElderPain'] as bool? ?? false,
    tags: (j['tags'] as List?)?.cast<String>() ?? const [],
    stageTags: (j['stages'] as List?)?.cast<String>() ?? const [],
    roleTags: (j['roles'] as List?)?.cast<String>() ?? const [],
    femaleOnly: j['female'] as bool? ?? false,
    isGeneric: j['generic'] as bool? ?? false,
  );

  // ── 提取（离线生成与运行时兜底共用的唯一实现）──

  static const _stageTagSet = ['少年', '青年', '中年', '老年'];
  static const _specificRoleTagSet = [
    '程序员', '创业者', '学生', '求职者', '家长', '准父母', '孕产', '照护者',
    '家有老人', '残障人士', '租房人', '购房人', '司机', '出境者', '灵活就业者',
    '雇主', '合伙人',
  ];

  /// 从建议实体提取静态门禁事实。[ruleSets] 即 gates.json 的 ruleIdSets。
  factory GateTraits.fromAdvice(
    Advice a, {
    required Map<String, List<int>> ruleSets,
  }) {
    final chapter = a.chapter;
    final tags = a.tags;
    final text = '${a.title} ${tags.join(" ")} $chapter';
    final prereqs = a.prerequisites;
    bool rs(String id) => ruleSets[id]?.contains(a.id) ?? false;
    bool kw(String s) => text.contains(s);

    return GateTraits(
      id: a.id,
      domainId: LifeDomain.ofChapter(chapter).id,
      reqCar: prereqs['has_car'] == true,
      reqTwowheeler: prereqs['has_twowheeler'] == true,
      reqSmoker: prereqs['is_smoker'] == true,
      reqChildren: prereqs['has_children'] == true,
      reqPregnantOrParent: prereqs['is_pregnant_or_parent'] == true,
      reqAgingParents: prereqs['has_aging_parents'] == true,
      reqTenant: prereqs['is_tenant'] == true,
      reqMortgage: prereqs['has_mortgage'] == true,
      reqPets: prereqs['has_pets'] == true,
      reqPipedGas: prereqs['has_piped_gas'] == true,
      reqEntrepreneur: prereqs['is_entrepreneur'] == true,
      reqGenderFemale: prereqs['gender_female'] == true,
      reqGenderMale: prereqs['gender_male'] == true,
      minAge: prereqs['min_age'] is int ? prereqs['min_age'] as int : null,
      hasChronic: tags.contains('确诊慢病') ||
          tags.contains('慢性病') ||
          chapter == '得了慢性病之后怎么活' ||
          chapter == '残疾之后怎么活',
      kwKidneyStone: kw('肾结石'),
      kwGout: kw('痛风') || kw('高尿酸'),
      kwHyper: kw('高血压'),
      kwBloodPressure: kw('血压'),
      kwDiabetes: kw('糖尿病') || kw('血糖') || kw('胰岛素'),
      disabilityChapter: chapter == '残疾之后怎么活',
      disabilityTag: tags.contains('残疾') || tags.contains('残障人士'),
      chronicChapter: chapter == '得了慢性病之后怎么活',
      chapProgrammer: chapter == '程序员和技术人容易踩的红线',
      chapDigitalPlatform: chapter == '做一个网站或平台：资质、备案和服务器',
      chapEntrepreneurship: chapter == '创业与做生意：别把家底赔进去',
      chapAbroad: chapter == '出国、旅行与境外安全' ||
          chapter == '出国留学：身份、打工、保险和回国认证',
      chapPregnancy: chapter == '怀孕和生产：从发现怀孕到出院办证',
      chapInfant: chapter == '刚出生的孩子怎么带',
      chapSchoolAge: chapter == '上学以后的孩子',
      gateWeightLoss: rs('weight-loss') ||
          kw('减肥药') ||
          kw('司美格鲁肽') ||
          kw('减重针') ||
          kw('手表的运动量化帮你减重') ||
          kw('酵素梅') ||
          kw('瘦身糖果'),
      gateGastro: rs('gastro') || kw('奥美拉唑') || kw('反酸烧心'),
      gateAnalgesic: rs('analgesic') ||
          kw('止痛药一个月别吃超过') ||
          kw('复方止痛药别超过'),
      gateLivingAlone: rs('living-alone') ||
          kw('建立三道安全兜底网') ||
          kw('盯着你的那个人'),
      gateMoodOnly: rs('mood-trigger-only') ||
          (kw('心情差到抑郁') && chapter == '怎么放松：娱乐场所和减压') ||
          (kw('12356') && chapter == '遭遇重大打击之后') ||
          kw('有自杀念头时打 12356') ||
          kw('带着孩子一起走'),
      gateMaternityEmergency:
          rs('maternity-emergency') || kw('破水了就地平躺') || kw('子痫前期'),
      gateChildEmergency: rs('child-emergency') ||
          kw('新生儿黄疸') ||
          kw('孩子被欺凌') ||
          kw('撞了头、之后头痛'),
      gateAfib: rs('afib') || kw('查出房颤请医生评估吃抗凝药'),
      gateSleepPills: rs('sleep-pills') || kw('别一上来就长期吃安眠药'),
      gateElderlyPainkiller: rs('elderly-painkiller') ||
          kw('60 岁以上、胃出过血、在吃抗凝药'),
      tags: List.unmodifiable(tags),
      stageTags: [
        for (final t in tags)
          if (_stageTagSet.contains(t)) t,
      ],
      roleTags: [
        for (final t in _specificRoleTagSet)
          if (tags.contains(t)) t,
      ],
      femaleOnly: tags.contains('女性健康'),
      isGeneric: !(tags.contains('确诊慢病') ||
              tags.contains('慢性病') ||
              chapter == '得了慢性病之后怎么活' ||
              chapter == '残疾之后怎么活') &&
          (tags.contains('全民') || tags.contains('通用')),
    );
  }
}

// ── asset 包络 ──

/// gate_traits.json 包络：schemaVersion + 源数据指纹 + 逐条 traits。
class GateTraitsBundle {
  GateTraitsBundle._(this.sourceHash, this.adviceCount, this.traits);

  final String sourceHash;
  final int adviceCount;
  final Map<int, GateTraits> traits;

  static const schemaVersion = 1;
  static const assetPath = 'assets/data/config/gate_traits.json';

  /// 解析；任何结构异常返回 null（调用方走运行时兜底编译）。
  static GateTraitsBundle? parse(Map<String, dynamic> json) {
    try {
      if (json['schemaVersion'] != schemaVersion) return null;
      final list = json['traits'] as List;
      return GateTraitsBundle._(
        json['sourceHash'] as String,
        (json['adviceCount'] as num).toInt(),
        {
          for (final e in list)
            (e['id'] as int): GateTraits.fromJson(e as Map<String, dynamic>),
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// 构建包络（离线生成端入口：test/build_gate_traits_test.dart 使用）。
  static Map<String, dynamic> buildManifest(
    Iterable<Advice> advices,
    Map<String, List<int>> ruleSets,
  ) {
    final list = [...advices];
    return GateTraitsBundle._(
      gateTraitsSourceFingerprint(list, ruleSets),
      list.length,
      {
        for (final a in list) a.id: GateTraits.fromAdvice(a, ruleSets: ruleSets),
      },
    ).toJson();
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': GateTraitsBundle.schemaVersion,
    'sourceHash': sourceHash,
    'adviceCount': adviceCount,
    'traits': [for (final t in traits.values) t.toJson()],
  };
}

/// 源数据指纹（FNV-1a 64）：advice 实体静态字段 + gates 名单的规范化折叠。
/// 生成端与运行端对同一份随包数据必然同值；不一致即资产-数据错位 → 兜底编译。
/// 注：依赖 Dart VM 64 位整型环绕语义（Web 端不参与资产生成/校验）。
String gateTraitsSourceFingerprint(
  Iterable<Advice> advices,
  Map<String, List<int>> ruleIdSets,
) {
  var h = 0xcbf29ce484222325;
  void feed(String s) {
    for (final cu in s.codeUnits) {
      h = (h ^ cu) * 0x100000001b3;
    }
  }

  final sorted = [...advices]..sort((a, b) => a.id.compareTo(b.id));
  for (final a in sorted) {
    feed('${a.id}\u0000${a.chapter}\u0000${a.title}\u0000'
        '${a.tags.join('\u0001')}\u0000${jsonEncode(a.prerequisites)}\u0001');
  }
  final keys = ruleIdSets.keys.toList()..sort();
  for (final k in keys) {
    feed('$k\u0000${ruleIdSets[k]!.join(',')}\u0001');
  }
  return h.toRadixString(16);
}

// ── 编译判定（与 GatekeeperEngine.matchPersonaReference 逐字等价）──

/// 纯字段判定：分支与顺序同原 matchPersona（0 → 0.5 → 0.6 → 0.7 → 0.8–0.15
/// → 1 → 女性专属 → 2 阶段 → 3 角色），静态量已折叠为 traits 字段。
/// topicFilter 由调用方（GatekeeperEngine.matchPersona）先行处理。
bool matchPersonaByTraits(GateTraits t, UserProfile p) {
  // 0. 关注领域过滤（若设置了特定关注领域且未全选）
  if (p.focusDomains.isNotEmpty &&
      p.focusDomains.length < 6 &&
      !p.focusDomains.contains(t.domainId)) {
    return false;
  }

  // 0.5 树节点画像前置守卫（原顺序逐条保留；'∨角色串' 判定体不变）
  if (t.reqCar && !p.hasCar) return false;
  if (t.reqTwowheeler && !p.hasTwowheeler) return false;
  if (t.reqSmoker && !p.isSmoker) return false;
  if (t.reqChildren &&
      !p.hasChildren &&
      !p.roles.contains('家长') &&
      !p.roles.contains('准父母')) {
    return false;
  }
  if (t.reqPregnantOrParent &&
      !p.hasChildren &&
      !p.roles.contains('孕产') &&
      !p.roles.contains('准父母') &&
      !p.roles.contains('家长')) {
    return false;
  }
  if (t.reqAgingParents &&
      !p.hasAgingParents &&
      !p.livingConditions.contains('家有老人') &&
      !p.roles.contains('照护者')) {
    return false;
  }
  if (t.reqTenant && !p.isTenant && !p.livingConditions.contains('租房人')) {
    return false;
  }
  if (t.reqMortgage && !p.hasMortgage && !p.livingConditions.contains('购房人')) {
    return false;
  }
  if (t.reqPets && !p.hasPets && !p.livingConditions.contains('养犬人')) {
    return false;
  }
  if (t.reqPipedGas && !p.hasPipedGas) return false;
  if (t.reqEntrepreneur &&
      !p.isEntrepreneur &&
      !p.roles.contains('创业者') &&
      !p.roles.contains('合伙人')) {
    return false;
  }
  if (t.reqGenderFemale && p.gender != '女') return false;
  if (t.reqGenderMale && p.gender != '男') return false;
  if (t.minAge != null && p.age < t.minAge!) return false;

  // 0.6 慢性病与特殊病理强门禁（进组条件与原实现一致：hasChronic ∨ 肾结石 ∨ 痛风）
  if (t.hasChronic || t.kwKidneyStone || t.kwGout) {
    if (t.kwKidneyStone &&
        !p.hasKidneyStones &&
        !p.healthConcerns.contains('肾结石')) {
      return false;
    }
    if (t.kwGout && !p.hasGout && !p.healthConcerns.contains('痛风')) {
      return false;
    }
    // 原式：text.contains('高血压') || (text.contains('血压') && hasChronic)
    // （hasChronic 在原实现作用域内）——编译展开后同构。
    if (t.kwHyper || (t.kwBloodPressure && t.hasChronic)) {
      if (!p.hasHypertension && !p.healthConcerns.contains('血压关注')) {
        return false;
      }
    }
    if (t.kwDiabetes) {
      if (!p.hasDiabetes && !p.healthConcerns.contains('血糖关注')) {
        return false;
      }
    }
    if (t.disabilityChapter || t.disabilityTag) {
      if (!p.roles.contains('残障人士') && !p.healthConcerns.contains('残疾照护')) {
        return false;
      }
    }
    // 慢病章兜底：未勾选任何慢病/慢病关注则默认拦截
    if (t.chronicChapter &&
        !p.hasHypertension &&
        !p.hasDiabetes &&
        !p.hasKidneyStones &&
        !p.hasGout &&
        !p.healthConcerns.contains('确诊慢病')) {
      return false;
    }
  }

  // 0.7 职业/技术/出境/育儿特殊章节强门禁
  if (t.chapProgrammer && !p.isProgrammer && !p.roles.contains('程序员')) {
    return false;
  }
  if (t.chapDigitalPlatform &&
      !p.isProgrammer &&
      !p.isEntrepreneur &&
      !p.hasDigitalAssetsConcern &&
      !p.roles.contains('程序员') &&
      !p.roles.contains('创业者') &&
      !p.roles.contains('平台运营')) {
    return false;
  }
  if (t.chapEntrepreneurship &&
      !p.isEntrepreneur &&
      !p.roles.contains('创业者') &&
      !p.roles.contains('合伙人')) {
    return false;
  }
  if (t.chapAbroad &&
      !p.hasAbroadTravelOrStudy &&
      !p.roles.contains('出境者') &&
      !p.roles.contains('留学生')) {
    return false;
  }
  if (t.chapPregnancy &&
      p.gender == '男' &&
      !p.isPregnantOrPlanning &&
      !p.roles.contains('准父母') &&
      !p.roles.contains('孕产') &&
      !p.roles.contains('家长')) {
    return false;
  }
  if (t.chapInfant &&
      p.childAgeStage != 'infant' &&
      !p.hasChildren &&
      !p.roles.contains('家长')) {
    return false;
  }
  if (t.chapSchoolAge &&
      p.childAgeStage != 'school' &&
      !p.hasChildren &&
      !p.roles.contains('家长')) {
    return false;
  }

  // 0.8 减重、减肥药物与量化运动强门禁
  if (t.gateWeightLoss && !p.hasWeightLossGoal && !p.isOverweightOrObese) {
    return false;
  }
  // 0.9 肠胃/反酸烧心强门禁
  if (t.gateGastro &&
      !p.hasGastroAcidOrStomach &&
      !p.healthConcerns.contains('反酸胃炎')) {
    return false;
  }
  // 0.10 止痛药常备与频繁用药门禁
  if (t.gateAnalgesic &&
      !p.hasFrequentPainOrAnalgesic &&
      !p.healthConcerns.contains('止痛用药')) {
    return false;
  }
  // 0.11 独居安全兜底防线
  if (t.gateLivingAlone &&
      p.relationshipStatus != 'single' &&
      !p.hasCrisisOrMentalStress) {
    return false;
  }
  // 0.12 抑郁重度干预与心理热线（情绪晴雨表专属，日常流一律拦截）
  if (t.gateMoodOnly) {
    return false;
  }
  // 0.13 孕产专科急重症与子痫用药强门禁
  if (t.gateMaternityEmergency &&
      (p.gender != '女' ||
          (!p.isPregnantOrPlanning &&
              !p.roles.contains('孕产') &&
              !p.roles.contains('准父母')))) {
    return false;
  }
  // 0.14 婴幼儿与学龄儿童突发及欺凌门禁
  if (t.gateChildEmergency &&
      !p.hasChildren &&
      !p.roles.contains('家长') &&
      !p.roles.contains('准父母')) {
    return false;
  }
  // 0.15 专病与特殊高危用药强门禁
  if (t.gateAfib &&
      !p.hasHypertension &&
      !p.healthConcerns.contains('血压关注')) {
    return false;
  }
  if (t.gateSleepPills &&
      !p.healthConcerns.contains('心理减压') &&
      !p.hasCrisisOrMentalStress) {
    return false;
  }
  if (t.gateElderlyPainkiller && p.age < 60 && !p.hasGastroAcidOrStomach) {
    return false;
  }

  // 1. 硬性排除
  if (t.tags.any(p.exclude.contains)) return false;

  // 女性专属硬条件
  if (p.gender != '女' && t.femaleOnly) return false;

  // 2. 年龄阶段匹配
  if (t.stageTags.isNotEmpty && !t.stageTags.any(p.stages.contains)) {
    return false;
  }

  // 3. 角色与群体匹配（原实现的 userAllRoles 并集命中 ≡ 三表任一命中）
  if (t.roleTags.isNotEmpty) {
    final matchesUserRole = t.roleTags.any(
      (r) =>
          p.roles.contains(r) ||
          p.livingConditions.contains(r) ||
          p.healthConcerns.contains(r),
    );
    if (!t.isGeneric && !matchesUserRole) {
      return false;
    }
  }

  return true;
}
