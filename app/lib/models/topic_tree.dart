import 'advice.dart';

/// A path identifies a topic; labels and aliases may change without changing it.
class TopicNode {
  const TopicNode({
    required this.path,
    required this.name,
    required this.children,
    this.aliases = const [],
  });

  final String path;
  final String name;
  final List<String> aliases;
  final List<TopicNode> children;

  static bool containsPath(String parent, String path) =>
      path == parent || path.startsWith('$parent/');
}

/// Topic ancestry is indexed once. Counts use sets so cross-listed advice counts once.
class TopicTree {
  TopicTree._(this.roots, this.byPath, this._adviceIds);

  final List<TopicNode> roots;
  final Map<String, TopicNode> byPath;
  final Map<String, Set<int>> _adviceIds;

  factory TopicTree.fromJson(
    Map<String, dynamic> json,
    Iterable<Advice> advice,
  ) {
    final nodes = <String, TopicNode>{};
    List<TopicNode> parse(Map<String, dynamic> entries, String parent) {
      return entries.entries.map((entry) {
        if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(entry.key)) {
          throw FormatException('Invalid topic key: ${entry.key}');
        }
        final path = parent.isEmpty ? entry.key : '$parent/${entry.key}';
        final data = entry.value as Map<String, dynamic>;
        final name = data['name'] as String;
        if (name.trim().isEmpty) throw FormatException('Empty topic: $path');
        final node = TopicNode(
          path: path,
          name: name,
          aliases: List.unmodifiable(
            (data['aliases'] as List? ?? []).cast<String>(),
          ),
          children: List.unmodifiable(
            parse((data['sub'] as Map<String, dynamic>?) ?? {}, path),
          ),
        );
        nodes[path] = node;
        return node;
      }).toList();
    }

    final roots = parse(json, '');
    final index = <String, Set<int>>{for (final path in nodes.keys) path: {}};
    final seen = <int>{};
    for (final item in advice) {
      if (!seen.add(item.id)) {
        throw FormatException('Duplicate advice: ${item.id}');
      }
      if (item.topicPaths.isEmpty) {
        throw FormatException('Missing topic: ${item.id}');
      }
      for (final path in item.topicPaths) {
        final node = nodes[path];
        if (node == null || node.children.isNotEmpty) {
          throw FormatException('Advice ${item.id} needs a valid leaf: $path');
        }
        for (final ancestor in ancestorsOf(path)) {
          index[ancestor]!.add(item.id);
        }
      }
    }
    return TopicTree._(
      List.unmodifiable(roots),
      Map.unmodifiable(nodes),
      Map.unmodifiable(
        index.map((path, ids) => MapEntry(path, Set<int>.unmodifiable(ids))),
      ),
    );
  }

  static Iterable<String> ancestorsOf(String path) sync* {
    final parts = path.split('/');
    for (var i = 1; i <= parts.length; i++) {
      yield parts.take(i).join('/');
    }
  }

  Set<int> adviceIdsUnder(String path) => _adviceIds[path] ?? const <int>{};

  String labelOf(String path) => byPath[path]?.name ?? path;

  String breadcrumbOf(String path) =>
      ancestorsOf(path).map(labelOf).join(' > ');

  Iterable<String> termsOf(Advice advice) sync* {
    final paths = {for (final path in advice.topicPaths) ...ancestorsOf(path)};
    for (final path in paths) {
      final node = byPath[path]!;
      yield node.name;
      yield* node.aliases;
      yield path;
    }
  }

  /// Recalculate counts after persona/search filters, preserving only nonempty branches.
  Map<String, int> countsFor(
    Iterable<Advice> advice, {
    Iterable<String> hidden = const [],
  }) {
    final ids = <String, Set<int>>{};
    for (final item in advice) {
      for (final leaf in item.topicPaths) {
        if (hidden.any((parent) => TopicNode.containsPath(parent, leaf))) {
          continue;
        }
        for (final path in ancestorsOf(leaf)) {
          (ids[path] ??= {}).add(item.id);
        }
      }
    }
    return {for (final entry in ids.entries) entry.key: entry.value.length};
  }

  /// A hidden topic removes that route. Other unhidden memberships remain usable.
  bool isVisible(Advice item, Iterable<String> hidden) => item.topicPaths.any(
    (path) => !hidden.any((parent) => TopicNode.containsPath(parent, path)),
  );
}
