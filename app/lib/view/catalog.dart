import 'dart:isolate';

import '../data/assets.dart' show RawAssets, readRawAssets, isFlutterTest;
import '../models/advice.dart';
import '../models/topic_tree.dart';
import 'advice_assembler.dart';
import 'catalog_index.dart';
import '../data/engine_config.dart';
import '../domain/profile_engine.dart' show OnboardingConfig;
import '../models/style.dart';

export '../models/presentation.dart' show TimingModel;
export 'action_types.dart' show actionTypes, actionTypeName, actionTypeIcon;

/// 视图层 · 建议目录门面：数据层加载拆分纯数据 → 视图层装配与索引。
/// 对外 API 与重构前逐字段一致,消费方零改动;加工与关联逻辑见
/// advice_assembler.dart / catalog_index.dart。
class Catalog {
  Catalog._({
    required this.adviceList,
    required this.details,
    required this.nodePackages,
    required this.pinyin,
    required this.topics,
    required this.engines,
    required this.gates,
    required this.probes,
    required this.actStyles,
    required this.displayBindings,
    required this.embeddingManifest,
    required this.onboarding,
    required this.mergeCandidateWeights,
    this.gateTraitsManifest,
  });

  final List<Advice> adviceList;
  final Map<int, AdviceDetail> details;
  final List<NodePackage> nodePackages;
  final Map<String, String> pinyin;
  final TopicTree topics;

  /// L7 引擎配置(engines.json / gates.json,Phase 2 外置)
  final EngineConfig engines;
  final GateConfig gates;

  /// L7 探查内容(probes.json,Phase 4 外置)
  final ProbeContent probes;

  /// L2 交互样式(styles/act_styles.json,Phase 4 外置)
  final ActStylesConfig actStyles;

  /// L5 展示↔样式绑定(styles/display_bindings.json,Phase 4 外置)
  final DisplayBindingsConfig displayBindings;

  /// 语义模型清单(config/models.json,Phase 5;sha256 为 modelVersion 源)
  final Map<String, dynamic> embeddingManifest;

  /// L7 画像引导配置(onboarding.json,Phase 6)
  final OnboardingConfig onboarding;

  /// 触发层归并关联(adviceId → {otherId: weight},双向;Phase 7)
  final Map<int, Map<int, double>> mergeCandidateWeights;

  /// L8 门禁谓词预编译资产(config/gate_traits.json 原文;null = 缺失走兜底编译)。
  /// 指纹校验在 GatekeeperEngine._resolveTraits:与随包数据错位即弃用。
  final Map<String, dynamic>? gateTraitsManifest;

  late final CatalogIndex _index = CatalogIndex(
    adviceList: adviceList,
    details: details,
    topics: topics,
    pinyin: pinyin,
  );

  Map<int, Advice> get byId => _index.byId;

  Advice? adviceById(int id) => _index.byId[id];

  /// 34 章节名(按首现顺序)。
  List<String> get chapters => _index.chapters;

  /// 每章节条数。
  Map<String, int> get chapterCounts => _index.chapterCounts;

  /// 拼音首字母(与 Demo getAdviceLetter 同口径:parts[0] 首字 → PINYIN_MAP)。
  String letterOf(Advice a) => _index.letterOf(a);

  /// 各字母的条数(A–Z 与 #)。
  Map<String, int> get letterCounts => _index.letterCounts;

  /// 每种交互形态的条数。
  Map<String, int> get modeCounts => _index.modeCounts;

  static Future<Catalog> load() async {
    // 资产字符串主 isolate 异步读取(平台通道),JSON 解码与模型装配移入
    // 后台 isolate(Isolate.run)——消除启动首帧前 ~4.5MB 主线程解码白屏。
    // Web 端 dart:isolate 受限,保持主线程装配。
    final raw = await readRawAssets();
    if (isFlutterTest) return _build(raw);
    return Isolate.run(() => _build(raw));
  }

  static Catalog _build(RawAssets raw) => Catalog._from(assembleCatalog(raw));

  static Catalog _from(AssembledCatalogData d) => Catalog._(
    adviceList: d.adviceList,
    details: d.details,
    nodePackages: d.nodePackages,
    pinyin: d.pinyin,
    topics: d.topics,
    engines: d.engines,
    gates: d.gates,
    probes: d.probes,
    actStyles: d.actStyles,
    displayBindings: d.displayBindings,
    embeddingManifest: d.embeddingManifest,
    onboarding: d.onboarding,
    mergeCandidateWeights: d.mergeCandidateWeights,
    gateTraitsManifest: d.gateTraitsManifest,
  );

  AdviceDetail? detailOf(int id) => details[id];

  List<Advice> byChapter(String chapter) =>
      adviceList.where((a) => a.chapter == chapter).toList();

  List<Advice> underTopic(
    String path, {
    Iterable<String> hiddenTopics = const [],
  }) =>
      _index.underTopic(path, hiddenTopics: hiddenTopics);

  /// Parent topics include descendants. Search can be combined with a subtree and
  /// an explicit persona filter; global lookup remains available for helping others.
  List<Advice> search(
    String query, {
    String? topicPath,
    bool Function(Advice)? include,
    Iterable<String> hiddenTopics = const [],
  }) =>
      _index.search(query, topicPath: topicPath, include: include, hiddenTopics: hiddenTopics);
}
