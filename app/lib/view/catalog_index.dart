import '../models/advice.dart';
import '../models/topic_tree.dart';
import 'action_types.dart';

/// 视图层 · 索引与加工：byId/章节统计/拼音首字母/形态计数/搜索倒排。
/// 全部由建议聚合根派生,数据层不参与。

class CatalogIndex {
  CatalogIndex({
    required this.adviceList,
    required this.details,
    required this.topics,
    required this.pinyin,
  });

  final List<Advice> adviceList;
  final Map<int, AdviceDetail> details;
  final TopicTree topics;
  final Map<String, String> pinyin;

  late final Map<int, Advice> byId = {for (final a in adviceList) a.id: a};

  /// 34 章节名(按首现顺序)。
  late final List<String> chapters = [
    ...{for (final a in adviceList) a.chapter},
  ];

  /// 每章节条数。
  late final Map<String, int> chapterCounts = {
    for (final c in chapters) c: adviceList.where((a) => a.chapter == c).length,
  };

  /// 拼音首字母(与 Demo getAdviceLetter 同口径:parts[0] 首字 → PINYIN_MAP)。
  String letterOf(Advice a) {
    final s = a.parts.isNotEmpty ? a.parts.first : a.title;
    final trimmed = s.trim();
    final firstChar = trimmed.isEmpty ? '' : trimmed[0];
    return pinyin[firstChar] ?? '#';
  }

  /// 各字母的条数(A–Z 与 #)。
  late final Map<String, int> letterCounts = _countLetters();

  Map<String, int> _countLetters() {
    final counts = <String, int>{};
    for (final a in adviceList) {
      final l = letterOf(a);
      counts[l] = (counts[l] ?? 0) + 1;
    }
    // 字母按序,# 排最后
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

  late final Map<int, String> _searchIndex = {
    for (final a in adviceList)
      a.id: [
        a.title,
        a.chapter,
        ...a.parts,
        ...a.facets.effectiveTags,
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
