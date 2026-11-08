import '../data/advice_actions.dart';
import '../data/advice_details.dart';
import '../data/advice_entities.dart';
import '../data/advice_nodes.dart';
import '../data/advice_relations.dart';
import '../data/assets.dart' show RawAssets, decodeJson;
import '../data/detail_sources.dart';
import '../data/engine_configs.dart';
import '../data/engine_config.dart';
import '../data/style_library.dart';
import '../data/tag_library.dart';
import '../domain/profile_engine.dart' show OnboardingConfig;
import '../models/advice.dart';
import '../models/style.dart';
import '../models/topic_tree.dart';

/// 视图层 · 加工流程与关联逻辑：把数据层的拆分表 join 成建议聚合根。
/// 本文件是唯一允许跨文件关联的位置；数据层 loader 只产出拆分记录。

class AssembledCatalogData {
  const AssembledCatalogData({
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
    required this.gateTraitsManifest,
  });

  final List<Advice> adviceList;
  final Map<int, AdviceDetail> details;
  final List<NodePackage> nodePackages;
  final Map<String, String> pinyin;
  final TopicTree topics;
  final EngineConfig engines;
  final GateConfig gates;
  final ProbeContent probes;
  final ActStylesConfig actStyles;
  final DisplayBindingsConfig displayBindings;
  final Map<String, dynamic> embeddingManifest;
  final OnboardingConfig onboarding;
  final Map<int, Map<int, double>> mergeCandidateWeights;
  final Map<String, dynamic>? gateTraitsManifest;
}

AssembledCatalogData assembleCatalog(RawAssets raw) {
  // ── 数据层:各表拆分记录 ──
  final entities = loadAdviceEntities(decodeJson(raw.adviceBase, 'entity/advice'));
  final actions = loadAdviceActions(decodeJson(raw.action, 'entity/advice_action'));
  final tagLinks = loadAdviceTagLinks(decodeJson(raw.tagRows, 'facets/advice_tag'));
  final detailRows = loadAdviceDetails(decodeJson(raw.detail, 'entity/advice_detail'));
  final sourceRows = loadDetailSources(decodeJson(raw.source, 'entity/detail_source'));
  final relationRows = loadAdviceRelations(decodeJson(raw.relation, 'entity/advice_relation'));
  final nodeRows = loadAdviceNodes(decodeJson(raw.node, 'entity/advice_node'));
  final taxonomyJson = decodeJson(raw.taxonomy, 'dimensions/taxonomy', requireSchemaV1: false);
  final engines = loadEngineConfig(decodeJson(raw.engines, 'config/engines'));
  final gates = loadGateConfig(decodeJson(raw.gates, 'config/gates'));
  final probes = loadProbeContent(decodeJson(raw.probes, 'config/probes'));
  final actStyles = loadActStyles(decodeJson(raw.actStyles, 'styles/act_styles'));
  final displayBindings = loadDisplayBindings(decodeJson(raw.displayBindings, 'styles/display_bindings'));
  final embeddingManifest = loadEmbeddingManifest(decodeJson(raw.models, 'config/models', requireSchemaV1: false));
  final onboarding = OnboardingConfig.fromJson(
    decodeJson(raw.onboarding, 'config/onboarding'),
  ).withTierResolved();
  final gateTraitsManifest = loadGateTraits(raw.gateTraits);
  final nodePackages = loadNodePackages(decodeJson(raw.nodePkg, 'node_packages', requireSchemaV1: false));
  final pinyin = loadPinyin(decodeJson(raw.pinyin, 'pinyin', requireSchemaV1: false));

  // ── 关联:子表按 id 聚合(行已按 (id, ordinal) 排序,聚合即保序)──
  final partsById = <int, List<String>>{};
  final pathsById = <int, List<String>>{};
  final tagsById = <int, List<String>>{};
  final sourcesById = <int, List<List<String>>>{};
  final relById = <int, List<int>>{};
  for (final row in actions) {
    partsById.putIfAbsent(row.id, () => []).add(row.text);
  }
  for (final row in nodeRows) {
    pathsById.putIfAbsent(row.id, () => []).add(row.path);
  }
  for (final row in tagLinks) {
    tagsById.putIfAbsent(row.id, () => []).add(row.tag);
  }
  for (final row in sourceRows) {
    final url = row.url;
    sourcesById
        .putIfAbsent(row.adviceId, () => [])
        .add(url == null ? [row.name] : [row.name, url]);
  }
  // kind=related 按 ordinal 还原 detail.rel(known_gap 孤儿行原样保留,UI 空安全)
  for (final row in relationRows) {
    if (row.kind != 'related') continue;
    relById.putIfAbsent(row.fromId, () => []).add(row.toId);
  }
  // kind=merge_candidate → 触发层归并关联(weight 双向)
  final merges = <int, Map<int, double>>{};
  for (final row in relationRows) {
    if (row.kind != 'merge_candidate') continue;
    merges.putIfAbsent(row.fromId, () => {})[row.toId] =
        (row.weight ?? 0).toDouble();
    merges.putIfAbsent(row.toId, () => {})[row.fromId] =
        (row.weight ?? 0).toDouble();
  }

  // 维度树先行构建(空建议集不触发逐条校验),仅为面包屑重算;
  // 装配完成后用完整建议集重建以启用叶子/唯一性校验与倒排索引。
  final topicTreeForBreadcrumbs = TopicTree.fromJson(taxonomyJson, const []);

  final adviceList = <Advice>[];
  for (final e in entities) {
    final paths = pathsById[e.id] ?? const <String>[];
    adviceList.add(
      Advice(
        raw: RawAdvice(
          id: e.id,
          chapter: e.chapterCode,
          title: e.title,
        ),
        facets: AdviceFacets(tags: tagsById[e.id] ?? const []),
        presentation: AdvicePresentation(
          parts: partsById[e.id] ?? const [],
          timingBadge: e.badgeKey,
          actType: e.style,
        ),
        treePath: paths.isNotEmpty ? paths.first : 'daily/lifestyle/diet',
        treeDisplay: paths.isNotEmpty
            ? topicTreeForBreadcrumbs.breadcrumbOf(paths.first)
            : '日常与起居 > 衣食养生 > 饮食营养与贮存',
        treePaths: paths,
        prerequisites: e.prerequisites,
        cron: e.cron,
      ),
    );
  }

  return AssembledCatalogData(
    mergeCandidateWeights: merges,
    adviceList: adviceList,
    topics: TopicTree.fromJson(taxonomyJson, adviceList),
    engines: engines,
    gates: gates,
    probes: probes,
    actStyles: actStyles,
    displayBindings: displayBindings,
    embeddingManifest: embeddingManifest,
    onboarding: onboarding,
    gateTraitsManifest: gateTraitsManifest,
    details: {
      for (final row in detailRows)
        row.adviceId: AdviceDetail(
          humanized: row.humanized,
          cost: row.cost,
          plain: row.plain,
          benefit: row.benefit,
          grade: row.grade ?? 'C',
          sources: sourcesById[row.adviceId] ?? const [],
          notes: row.notes,
          rel: relById[row.adviceId] ?? const [],
        ),
    },
    nodePackages: nodePackages,
    pinyin: pinyin,
  );
}
