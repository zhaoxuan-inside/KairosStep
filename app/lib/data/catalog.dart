import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine_config.dart';
import '../models/style.dart';
import '../models/advice.dart';
import '../models/topic_tree.dart';

// 时机模型自 presentation.dart 再导出（Phase 2 分域重组，存量引用路径兼容）
export '../models/presentation.dart' show TimingModel;

/// 交互形态中枢：与 Demo ACTION_TYPE_DEFS 同构，图标用 Material 线性图标近似。
const List<ActionTypeDef> actionTypes = [
  ActionTypeDef('all', '全部形态', Icons.apps),
  ActionTypeDef('daily-streak', '每日连击', Icons.local_fire_department_outlined),
  ActionTypeDef('windowed-cadence', '持续窗口期', Icons.date_range_outlined),
  ActionTypeDef('quick-checkin', '行动打卡', Icons.check_circle_outline),
  ActionTypeDef('slider-calc', '测算滑块', Icons.tune),
  ActionTypeDef('haptic-toggle', '触感卡扣', Icons.toggle_on_outlined),
  ActionTypeDef('emergency-action', '紧急直达', Icons.emergency_outlined),
  ActionTypeDef('zen-timer', '计时屏息', Icons.timer_outlined),
  ActionTypeDef('evidence-checklist', '证据清单', Icons.inventory_2_outlined),
  ActionTypeDef('wage-calc', '时薪决策', Icons.calculate_outlined),
  ActionTypeDef('redline-stamp', '红线铭记', Icons.gpp_maybe_outlined),
  ActionTypeDef('context-guard', '情境拦截', Icons.fact_check_outlined),
  ActionTypeDef('decision-check', '决策核对', Icons.rule_outlined),
  ActionTypeDef('process-steps', '办事分步', Icons.format_list_numbered),
];

String actionTypeName(String id) {
  for (final d in actionTypes) {
    if (d.id == id) return d.name;
  }
  return id;
}

IconData actionTypeIcon(String id) {
  for (final d in actionTypes) {
    if (d.id == id) return d.icon;
  }
  return Icons.category_outlined;
}

/// 建议目录：加载资产、建立索引、计算字母、画像匹配。
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
  });

  final List<Advice> adviceList;
  final Map<int, AdviceDetail> details;
  final List<NodePackage> nodePackages;
  final PinyinMap pinyin;
  final TopicTree topics;

  /// L7 引擎配置（engines.json / gates.json，Phase 2 外置）
  final EngineConfig engines;
  final GateConfig gates;

  /// L7 探查内容（probes.json，Phase 4 外置）
  final ProbeContent probes;

  /// L2 交互样式（styles/act_styles.json，Phase 4 外置）
  final ActStylesConfig actStyles;

  /// L5 展示↔样式绑定（styles/display_bindings.json，Phase 4 外置）
  final DisplayBindingsConfig displayBindings;

  /// 语义模型清单（config/models.json，Phase 5；sha256 为 modelVersion 源）
  final Map<String, dynamic> embeddingManifest;

  late final Map<int, Advice> byId = {for (final a in adviceList) a.id: a};

  Advice? adviceById(int id) => byId[id];

  /// 34 章节名（按首现顺序）。
  late final List<String> chapters = [
    ...{for (final a in adviceList) a.chapter},
  ];

  /// 每章节条数。
  late final Map<String, int> chapterCounts = {
    for (final c in chapters) c: adviceList.where((a) => a.chapter == c).length,
  };

  /// 拼音首字母（与 Demo getAdviceLetter 同口径：parts[0] 首字 → PINYIN_MAP）。
  String letterOf(Advice a) {
    final s = a.parts.isNotEmpty ? a.parts.first : a.title;
    final trimmed = s.trim();
    final firstChar = trimmed.isEmpty ? '' : trimmed[0];
    return pinyin[firstChar] ?? '#';
  }

  /// 各字母的条数（A–Z 与 #）。
  late final Map<String, int> letterCounts = _countLetters();

  Map<String, int> _countLetters() {
    final counts = <String, int>{};
    for (final a in adviceList) {
      final l = letterOf(a);
      counts[l] = (counts[l] ?? 0) + 1;
    }
    // 字母按序，# 排最后
    final sorted = <String, int>{};
    for (final key
        in counts.keys.toList()
          ..sort((x, y) => x == '#' ? 1 : (y == '#' ? -1 : x.compareTo(y)))) {
      sorted[key] = counts[key]!;
    }
    return sorted;
  }

  /// 每种交互形态的条数。
  late final Map<String, int> modeCounts = {
    for (final d in actionTypes.skip(1))
      d.id: adviceList.where((a) => a.actType == d.id).length,
  };

  static Future<Catalog> load() async {
    Future<Map<String, dynamic>> loadJson(String name) async {
      final raw = await rootBundle.loadString('assets/data/$name.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    void requireSchema(Map<String, dynamic> json, String name) {
      if (json['schemaVersion'] != 1) {
        throw FormatException('$name schemaVersion 异常：${json['schemaVersion']}');
      }
    }

    // ── 分层加载（L0 实体层 + L1 维度树；关系化 Schema 见 docs/refactor §4.9） ──
    final adviceBaseJson = await loadJson('entity/advice');
    requireSchema(adviceBaseJson, 'entity/advice');
    final actionJson = await loadJson('entity/advice_action');
    requireSchema(actionJson, 'entity/advice_action');
    final tagRowsJson = await loadJson('facets/advice_tag');
    requireSchema(tagRowsJson, 'facets/advice_tag');
    final detailJson = await loadJson('entity/advice_detail');
    requireSchema(detailJson, 'entity/advice_detail');
    final sourceJson = await loadJson('entity/detail_source');
    requireSchema(sourceJson, 'entity/detail_source');
    final relationJson = await loadJson('entity/advice_relation');
    requireSchema(relationJson, 'entity/advice_relation');
    final nodeJson = await loadJson('entity/advice_node');
    requireSchema(nodeJson, 'entity/advice_node');
    final taxonomyJson = await loadJson('dimensions/taxonomy');
    final enginesJson = await loadJson('config/engines');
    requireSchema(enginesJson, 'config/engines');
    final gatesJson = await loadJson('config/gates');
    requireSchema(gatesJson, 'config/gates');
    final probesJson = await loadJson('config/probes');
    requireSchema(probesJson, 'config/probes');
    final actStylesJson = await loadJson('styles/act_styles');
    requireSchema(actStylesJson, 'styles/act_styles');
    final displayBindingsJson = await loadJson('styles/display_bindings');
    requireSchema(displayBindingsJson, 'styles/display_bindings');
    final modelsManifest = await loadJson('config/models');
    final nodePkgJson = await loadJson('node_packages');
    final pinyinJson = await loadJson('pinyin');

    // 子表按 id 聚合（行已按 (id, ordinal) 排序，聚合即保序）：
    // 原子动作 → parts、维度挂载 → treePaths、标签 → tags、来源 → sources、关联 → rel
    final partsById = <int, List<String>>{};
    final pathsById = <int, List<String>>{};
    final tagsById = <int, List<String>>{};
    final sourcesById = <int, List<List<String>>>{};
    final relById = <int, List<int>>{};
    for (final row
        in (actionJson['list'] as List).cast<Map<String, dynamic>>()) {
      partsById.putIfAbsent(row['id'] as int, () => []).add(row['text'] as String);
    }
    for (final row in (nodeJson['list'] as List).cast<Map<String, dynamic>>()) {
      pathsById.putIfAbsent(row['id'] as int, () => []).add(row['path'] as String);
    }
    for (final row in (tagRowsJson['list'] as List).cast<Map<String, dynamic>>()) {
      tagsById.putIfAbsent(row['id'] as int, () => []).add(row['tag'] as String);
    }
    for (final row
        in (sourceJson['list'] as List).cast<Map<String, dynamic>>()) {
      final name = row['name'] as String;
      final url = row['url'] as String?;
      sourcesById
          .putIfAbsent(row['adviceId'] as int, () => [])
          .add(url == null ? [name] : [name, url]);
    }
    // kind=related 按 ordinal 还原 detail.rel（known_gap 孤儿行原样保留，UI 空安全）
    for (final row
        in (relationJson['list'] as List).cast<Map<String, dynamic>>()) {
      if (row['kind'] != 'related') continue;
      relById.putIfAbsent(row['fromId'] as int, () => []).add(row['toId'] as int);
    }

    // 维度树先行构建（空建议集不触发逐条校验），仅为面包屑重算；
    // 装配完成后用完整建议集重建以启用叶子/唯一性校验与倒排索引。
    final topicTreeForBreadcrumbs = TopicTree.fromJson(taxonomyJson, const []);

    final adviceList = <Advice>[];
    for (final row
        in (adviceBaseJson['list'] as List).cast<Map<String, dynamic>>()) {
      final id = row['id'] as int;
      final paths = pathsById[id] ?? const <String>[];
      adviceList.add(
        Advice(
          raw: RawAdvice(
            id: id,
            chapter: row['chapterCode'] as String,
            title: row['title'] as String,
          ),
          facets: AdviceFacets(tags: tagsById[id] ?? const []),
          presentation: AdvicePresentation(
            parts: partsById[id] ?? const [],
            timingBadge: row['badgeKey'] as String,
            actType: row['style'] as String,
          ),
          treePath: paths.isNotEmpty ? paths.first : 'daily/lifestyle/diet',
          treeDisplay: paths.isNotEmpty
              ? topicTreeForBreadcrumbs.breadcrumbOf(paths.first)
              : '日常与起居 > 衣食养生 > 饮食营养与贮存',
          treePaths: paths,
          prerequisites:
              (row['prerequisites'] as Map<String, dynamic>?) ?? const {},
          cron: row['cron'] as String,
        ),
      );
    }

    return Catalog._(
      adviceList: adviceList,
      topics: TopicTree.fromJson(taxonomyJson, adviceList),
      engines: EngineConfig.fromJson(enginesJson),
      gates: GateConfig.fromJson(gatesJson),
      probes: ProbeContent.fromJson(probesJson),
      actStyles: ActStylesConfig.fromJson(actStylesJson),
      displayBindings: DisplayBindingsConfig.fromJson(displayBindingsJson),
      embeddingManifest: (modelsManifest['providers'] as Map<String, dynamic>)['embedding']
          as Map<String, dynamic>,
      details: {
        for (final row
            in (detailJson['list'] as List).cast<Map<String, dynamic>>())
          row['adviceId'] as int: AdviceDetail(
            humanized: row['humanized'] as String,
            cost: row['cost'] as String?,
            plain: row['plain'] as String?,
            benefit: row['benefit'] as String?,
            grade: row['grade'] as String? ?? 'C',
            sources: sourcesById[row['adviceId'] as int] ?? const [],
            notes: row['notes'] as String?,
            rel: relById[row['adviceId'] as int] ?? const [],
          ),
      },
      nodePackages: (nodePkgJson['list'] as List)
          .map((e) => NodePackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      pinyin: {for (final e in pinyinJson.entries) e.key: e.value as String},
    );
  }

  AdviceDetail? detailOf(int id) => details[id];

  List<Advice> byChapter(String chapter) =>
      adviceList.where((a) => a.chapter == chapter).toList();

  late final Map<int, String> _searchIndex = {
    for (final a in adviceList)
      a.id: [
        a.title,
        a.chapter,
        ...a.parts,
        ...a.tags,
        a.timingBadge,
        ...topics.termsOf(a),
        if (details[a.id] case final detail?) ...[
          detail.humanized,
          detail.plain ?? '',
          detail.notes ?? '',
        ],
      ].join('\n').toLowerCase(),
  };

  List<Advice> underTopic(
    String path, {
    Iterable<String> hiddenTopics = const [],
  }) {
    final ids = topics.adviceIdsUnder(path);
    return adviceList
        .where(
          (a) =>
              ids.contains(a.id) &&
              a.topicPaths.any(
                (leaf) =>
                    TopicNode.containsPath(path, leaf) &&
                    !hiddenTopics.any(
                      (hidden) => TopicNode.containsPath(hidden, leaf),
                    ),
              ),
        )
        .toList();
  }

  /// Parent topics include descendants. Search can be combined with a subtree and
  /// an explicit persona filter; global lookup remains available for helping others.
  List<Advice> search(
    String query, {
    String? topicPath,
    bool Function(Advice)? include,
    Iterable<String> hiddenTopics = const [],
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty && topicPath == null) return const [];
    final terms = q
        .split(RegExp(r'[\s，,、]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final candidates = topicPath == null
        ? adviceList.where((a) => topics.isVisible(a, hiddenTopics))
        : underTopic(topicPath, hiddenTopics: hiddenTopics);
    final results = candidates
        .where(
          (a) =>
              (include == null || include(a)) &&
              terms.every((term) => _searchIndex[a.id]!.contains(term)),
        )
        .toList();
    // Exact title hits lead; stable ID breaks ties, never relying on sort stability.
    results.sort((a, b) {
      final aTitle = q.isNotEmpty && a.title.toLowerCase().contains(q);
      final bTitle = q.isNotEmpty && b.title.toLowerCase().contains(q);
      if (aTitle != bTitle) return aTitle ? -1 : 1;
      return a.id.compareTo(b.id);
    });
    return results;
  }
}
