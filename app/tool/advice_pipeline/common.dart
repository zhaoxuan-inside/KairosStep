// 建议数据流水线：公共工具与受控常量。
// 只依赖 dart:io / dart:convert，禁止 import Flutter / lib/（构建期与运行时严格隔离）。
import 'dart:convert';
import 'dart:io';

const srcDir = 'data-src';
const outDir = 'assets/data';

/// 读取源归档（data-src/，只增不改）。
Map<String, dynamic> loadSource(String name) {
  final raw = File('$srcDir/$name.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// 原样拷贝（字节级）。
void copyFile(String from, String to) {
  File(to).parent.createSync(recursive: true);
  File(from).copySync(to);
}

/// 写紧凑 JSON（确定键序：由构造顺序保证；调用方负责列表排序）。
void writeJson(String relPath, Object data) {
  final file = File('$outDir/$relPath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(data));
}

String encodeStable(Object data) => jsonEncode(data);

/// schemaVersion 统一从 1 起。
const schemaVersion = 1;

// ── 受控词表（与 lib/data/catalog.dart 的 TimingModel、models/advice.dart 的
//    AdviceFacets 常量同源；修改必须同步并在 validate 中互检） ──

/// TimingModel 枚举的 (key, label)，顺序即 Dart 枚举声明顺序（contains 匹配依赖此序）。
const timingModelDefs = <(String, String)>[
  ('situational', '情境感知'),
  ('continuous', '持续事件'),
  ('redline', '红线知识'),
  ('daily', '每日节律'),
  ('process', '办事流程'),
  ('decision', '决策规则'),
  ('contextGuard', '情境拦截'),
  ('emergency', 'P0 紧急'),
  ('search', '搜索秒开'),
  ('periodic', '周期节律'),
  ('slider', '时长感知'),
  ('finance', '理财决策'),
];

/// 复刻 catalog.dart `TimingModel.of`：前缀 contains 匹配 + 兜底规则，逐字对齐。
String timingModelKeyOf(String badge) {
  final prefix = badge.split(' · ').first.trim();
  for (final (key, label) in timingModelDefs) {
    if (prefix.contains(label) || label.contains(prefix)) return key;
  }
  if (prefix.startsWith('每日') || prefix.contains('周期')) return 'periodic';
  return 'search';
}

/// 标签受控维度（词表）。open 维度（theme）不列明细，凡未命中受控清单的标签归入 theme。
const tagDimensionDefs = <(String, String, bool)>[
  // key, name, multi
  ('stage', '人生阶段', true),
  ('frequency', '频率', true),
  ('timing', '时机', true),
  ('scene', '场景', true),
  ('audience', '对象', true),
  ('money', '金钱', false),
  ('function', '功能', true),
  ('reliance', '依赖', false),
  ('validity', '时效', false),
  ('role', '角色群体', true),
  ('gender', '性别', false),
  ('theme', '主题', true),
];

const controlledVocabulary = <String, List<String>>{
  'stage': ['少年', '青年', '中年', '老年', '全民'],
  'frequency': ['每天', '每周', '每月', '每年', '单次', '偶发', '每次', '每日多次'],
  'timing': ['事前', '事中', '事后'],
  'scene': ['在家', '在路上', '在线上', '在医院', '在职场', '不限场景'],
  'audience': ['自身', '家人', '子女', '伴侣', '陌生人', '雇主', '医生'],
  'money': ['不涉及钱', '要花钱', '能拿钱', '高风险钱'],
  'function': [
    '打卡',
    '提醒',
    '速查',
    '收藏',
    '决策点',
    '日历时点',
    '情境触发',
    '突发事件',
    '需机构窗口',
    '需医生介入',
  ],
  'reliance': ['可独立完成', '需他人协助'],
  'validity': ['长期有效', '限时有效'],
  // 角色群体：与 app_store.matchPersona 的 17 个 specificRoleTags 同源，
  // 另含被 probe_scheduler/normalized() 消费的上班族、养犬人、父母、老人
  'role': [
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
    '上班族',
    '养犬人',
    '父母',
    '老人',
    '军人',
    '教师',
    '体力劳动者',
    '留学生',
    '房东',
    '患者',
  ],
  'gender': ['女性', '男性'],
};

/// 已登记的关联缺口（源归档中的 rel 指向库内缺失 id；登记后跳过生成并在报告留痕）。
/// 来源：detail.json["103"].rel=[104]，而 104 在 737 条库中不存在（id 区间缺口）。
const knownRelationOrphans = <int, List<int>>{
  103: [104],
};

/// prerequisites 合法画像键（与 app_store.matchPersona 的消费一致）。
const prerequisiteKeys = {
  'has_children',
  'is_entrepreneur',
  'is_pregnant_or_parent',
  'gender_female',
  'gender_male',
  'has_aging_parents',
  'has_mortgage',
  'has_pets',
  'has_piped_gas',
  'has_twowheeler',
  'has_car',
  'is_smoker',
  'is_tenant',
  'min_age',
};
