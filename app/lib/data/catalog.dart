import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine_config.dart';
import '../models/style.dart';
import '../domain/profile_engine.dart';
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

/// Catalog.load 的原始资产字符串包（主 isolate 读取 → 后台 isolate 解码装配）。
class _RawAssets {
  const _RawAssets({
    required this.adviceBase,
    required this.action,
    required this.tagRows,
    required this.detail,
    required this.source,
    required this.relation,
    required this.node,
    required this.taxonomy,
    required this.engines,
    required this.gates,
    required this.probes,
    required this.actStyles,
    required this.displayBindings,
    required this.models,
    required this.onboarding,
    required this.gateTraits,
    required this.nodePkg,
    required this.pinyin,
  });

  final String adviceBase;
  final String action;
  final String tagRows;
  final String detail;
  final String source;
  final String relation;
  final String node;
  final String taxonomy;
  final String engines;
  final String gates;
  final String probes;
  final String actStyles;
  final String displayBindings;
  final String models;
  final String onboarding;

  /// gate_traits 缺失时为空串（装配端转 null 走运行时兜底编译）。
  final String gateTraits;
  final String nodePkg;
  final String pinyin;
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
    required this.onboarding,
    required this.mergeCandidateWeights,
    this.gateTraitsManifest,
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

  /// L7 画像引导配置（onboarding.json，Phase 6）
  final OnboardingConfig onboarding;

  /// 触发层归并关联（adviceId → {otherId: weight}，双向；Phase 7）
  final Map<int, Map<int, double>> mergeCandidateWeights;

  /// L8 门禁谓词预编译资产（config/gate_traits.json 原文；null = 缺失走兜底编译）。
  /// 指纹校验在 GatekeeperEngine._resolveTraits：与随包数据错位即弃用。
  final Map<String, dynamic>? gateTraitsManifest;

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
    Future<String> raw(String name) =>
        rootBundle.loadString('assets/data/$name.json');

    // 资产字符串主 isolate 异步读取（平台通道），JSON 解码与模型装配移入
    // 后台 isolate（Isolate.run）——消除启动首帧前 ~4.5MB 主线程解码白屏。
    // Web 端 dart:isolate 受限，保持主线程装配。
    final r = _RawAssets(
      adviceBase: await raw('entity/advice'),
      action: await raw('entity/advice_action'),
      tagRows: await raw('facets/advice_tag'),
      detail: await raw('entity/advice_detail'),
      source: await raw('entity/detail_source'),
      relation: await raw('entity/advice_relation'),
      node: await raw('entity/advice_node'),
      taxonomy: await raw('dimensions/taxonomy'),
      engines: await raw('config/engines'),
      gates: await raw('config/gates'),
      probes: await raw('config/probes'),
      actStyles: await raw('styles/act_styles'),
      displayBindings: await raw('styles/display_bindings'),
      models: await raw('config/models'),
      onboarding: await raw('config/onboarding'),
      // L8 门禁谓词预编译资产（离线生成，见 test/build_gate_traits_test.dart）：
      // 缺失/损坏不阻断启动——GatekeeperEngine 按指纹校验失败自动兜底编译。
      gateTraits: await raw('config/gate_traits').catchError((_) => ''),
      nodePkg: await raw('node_packages'),
      pinyin: await raw('pinyin'),
    );
    if (kIsWeb) return _assemble(r);
    // flutter test 的 testWidgets 在 FakeAsync 区运行，Isolate.run 的结果端口
    // 永不投递（实测死锁）——测试环境退回主线程同步装配；设备/桌面走后台 isolate。
    if (_isFlutterTest) return _assemble(r);
    return Isolate.run(() => _assemble(r));
  }

  /// FLUTTER_TEST 由 flutter test 注入（dart:io 仅限非 Web 路径可达）。
  static bool get _isFlutterTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static Catalog _assemble(_RawAssets r) {
    Map<String, dynamic> decode(
      String raw,
      String name, {
      bool requireSchemaV1 = true,
    }) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (requireSchemaV1 && json['schemaVersion'] != 1) {
        throw FormatException(
          '$name schemaVersion 异常：${json['schemaVersion']}',
        );
      }
      return json;
    }

    // ── 分层加载（L0 实体层 + L1 维度树；关系化 Schema 见 docs/refactor §4.9） ──
    final adviceBaseJson = decode(r.adviceBase, 'entity/advice');
    final actionJson = decode(r.action, 'entity/advice_action');
    final tagRowsJson = decode(r.tagRows, 'facets/advice_tag');
    final detailJson = decode(r.detail, 'entity/advice_detail');
    final sourceJson = decode(r.source, 'entity/detail_source');
    final relationJson = decode(r.relation, 'entity/advice_relation');
    final nodeJson = decode(r.node, 'entity/advice_node');
    final taxonomyJson = decode(r.taxonomy, 'dimensions/taxonomy', requireSchemaV1: false);
    final enginesJson = decode(r.engines, 'config/engines');
    final gatesJson = decode(r.gates, 'config/gates');
    final probesJson = decode(r.probes, 'config/probes');
    final actStylesJson = decode(r.actStyles, 'styles/act_styles');
    final displayBindingsJson = decode(r.displayBindings, 'styles/display_bindings');
    final modelsManifest = decode(r.models, 'config/models', requireSchemaV1: false);
    final onboardingJson = decode(r.onboarding, 'config/onboarding');
    final gateTraitsJson = r.gateTraits.isEmpty
        ? null
        : decode(r.gateTraits, 'config/gate_traits', requireSchemaV1: false);
    final nodePkgJson = decode(r.nodePkg, 'node_packages', requireSchemaV1: false);
    final pinyinJson = decode(r.pinyin, 'pinyin', requireSchemaV1: false);

    // 子表按 id 聚合（行已按 (id, ordinal) 排序，聚合即保序）：
    // 原子动作 → parts、维度挂载 → treePaths、标签 → tags、来源 → sources、关联 → rel
    final partsById = <int, List<String>>{};
    final pathsById = <int, List<String>>{};
    final tagsById = <int, List<String>>{};
    final sourcesById = <int, List<List<String>>>{};
    final relById = <int, List<int>>{};
    for (final row
        in (actionJson['list'] as List).cast<Map<String, dynamic>>()) {
      partsById
          .putIfAbsent(row['id'] as int, () => [])
          .add(row['text'] as String);
    }
    for (final row in (nodeJson['list'] as List).cast<Map<String, dynamic>>()) {
      pathsById
          .putIfAbsent(row['id'] as int, () => [])
          .add(row['path'] as String);
    }
    for (final row
        in (tagRowsJson['list'] as List).cast<Map<String, dynamic>>()) {
      tagsById
          .putIfAbsent(row['id'] as int, () => [])
          .add(row['tag'] as String);
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
      relById
          .putIfAbsent(row['fromId'] as int, () => [])
          .add(row['toId'] as int);
    }
    // kind=merge_candidate → 触发层归并关联（Phase 7；weight 双向）
    final merges = <int, Map<int, double>>{};
    for (final row
        in (relationJson['list'] as List).cast<Map<String, dynamic>>()) {
      if (row['kind'] != 'merge_candidate') continue;
      merges.putIfAbsent(row['fromId'] as int, () => {})[(row['toId'] as int)] =
          (row['weight'] as num).toDouble();
      merges.putIfAbsent(row['toId'] as int, () => {})[(row['fromId'] as int)] =
          (row['weight'] as num).toDouble();
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
      mergeCandidateWeights: merges,
      adviceList: adviceList,
      topics: TopicTree.fromJson(taxonomyJson, adviceList),
      engines: EngineConfig.fromJson(enginesJson),
      gates: GateConfig.fromJson(gatesJson),
      probes: ProbeContent.fromJson(probesJson),
      actStyles: ActStylesConfig.fromJson(actStylesJson),
      displayBindings: DisplayBindingsConfig.fromJson(displayBindingsJson),
      embeddingManifest:
          (modelsManifest['providers'] as Map<String, dynamic>)['embedding']
              as Map<String, dynamic>,
      onboarding: OnboardingConfig.fromJson(onboardingJson).withTierResolved(),
      gateTraitsManifest: gateTraitsJson,
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
