// 语义混合检索引擎（REFACTOR_DESIGN §11.6）：词法（catalog.search）⊕ 向量（BGE+L8）RRF 融合。
// Fail-safe：模型/向量层任一不可用即单通道；两者皆不可用 → 词法必达。
// feature flag：engines.json semantic.enabled（Phase 5 独立验收）。
import '../data/catalog.dart';
import '../models/advice.dart';
import '../semantic/providers/bge_provider.dart';
import '../semantic/vector_store.dart';

class SemanticSearchEngine {
  SemanticSearchEngine(this._catalog, this._manifest);

  final Catalog _catalog;
  final Map<String, dynamic> _manifest;

  BgeProvider? _provider;
  VectorStore? _store;
  bool _tried = false;
  final _cache = <String, List<Advice>>{}; // 查询缓存（键入每次重建不重复推理）

  bool get enabled => _catalog.engines.semantic.enabled;

  Future<void> _ensureReady() async {
    if (_tried || !enabled) return;
    _tried = true;
    try {
      final provider = BgeProvider(_manifest);
      await provider.ensureLoaded();
      if (!provider.isAvailable) return;
      _store = await VectorStore.load(provider.modelVersion);
      if (_store == null || _store!.isEmpty) return;
      _provider = provider;
    } catch (_) {
      _provider = null; // Fail-safe：词法兜底
    }
  }

  /// 混合检索：词法通道（标题命中置顶语义保留）⊕ 向量通道 RRF 融合。
  /// [topicPath]/[include]/[hiddenTopics] 与 catalog.search 同义：词法直达，
  /// 向量命中同样过滤（个性化/主题范围对两通道一致）。
  Future<List<Advice>> search(
    String query, {
    String? topicPath,
    bool Function(Advice)? include,
    Iterable<String> hiddenTopics = const [],
  }) async {
    final cacheKey = '$query|$topicPath|${include != null}|${hiddenTopics.join(',')}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    bool passScope(Advice a) =>
        (include == null || include(a)) &&
        (topicPath == null || _catalog
                .underTopic(topicPath, hiddenTopics: hiddenTopics)
                .any((x) => x.id == a.id)) &&
        _catalog.topics.isVisible(a, hiddenTopics);
    final lexical = _catalog.search(
      query,
      topicPath: topicPath,
      include: include,
      hiddenTopics: hiddenTopics,
    );
    if (!enabled) return lexical;
    await _ensureReady();
    final provider = _provider;
    final store = _store;
    if (provider == null || store == null || store.isEmpty) return lexical;

    final qVec = await provider.embed(query);
    if (qVec == null) return lexical;

    final vectorHits = store
        .search(
          qVec,
          topK: 20,
          floor: (_manifest['similarityFloor'] as num?)?.toDouble() ?? 0.35,
        )
        .where(
          (h) => switch (_catalog.adviceById(h.$1)) {
            final a? when passScope(a) => true,
            _ => false,
          },
        )
        .toList();
    if (vectorHits.isEmpty) return lexical;

    // RRF：score = 1/(60+rank_lex) + 1/(60+rank_vec)；词法命中置顶规则经 rank_lex 保留
    const k = 60;
    final scores = <int, double>{};
    var rank = 0;
    for (final a in lexical) {
      rank++;
      scores[a.id] = (scores[a.id] ?? 0) + 1 / (k + rank);
    }
    rank = 0;
    for (final (id, _) in vectorHits) {
      rank++;
      scores[id] = (scores[id] ?? 0) + 1 / (k + rank);
    }
    final ids = scores.keys.toList()
      ..sort((a, b) => (scores[b]!.compareTo(scores[a]!)) != 0
          ? scores[b]!.compareTo(scores[a]!)
          : a.compareTo(b));
    final merged = [for (final id in ids) ?_catalog.adviceById(id)];
    if (_cache.length > 32) _cache.clear();
    _cache[cacheKey] = merged;
    return merged;
  }
}
