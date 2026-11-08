import 'package:flutter/material.dart';

import '../../models/advice.dart';
import '../../models/advice_classification.dart';
import '../../models/topic_tree.dart';
import '../cards/advice_card.dart';

class ClassifiedAdviceGroup {
  ClassifiedAdviceGroup(this.path, this.lane, this.items);
  final String path;
  final String lane;
  final List<Advice> items;
  String get key => '$path|$lane';
}

List<ClassifiedAdviceGroup> classifyAdvice(
  Iterable<Advice> advice, {
  String selectedTopic = '',
  Iterable<String> hiddenTopics = const [],
  List<String> focusTopics = const [],
}) {
  final groups = <String, ClassifiedAdviceGroup>{};
  final seen = <int>{};
  for (final a in advice) {
    if (!seen.add(a.id)) continue;
    final routes = a.topicPaths.where(
      (path) =>
          (selectedTopic.isEmpty ||
              TopicNode.containsPath(selectedTopic, path)) &&
          !hiddenTopics.any((hidden) => TopicNode.containsPath(hidden, path)) &&
          (focusTopics.isEmpty ||
              focusTopics.any((focus) => TopicNode.containsPath(focus, path))),
    );
    if (routes.isEmpty) continue;
    final path = routes.first;
    final lane = a.classification?.lane ?? 'dormant';
    final group = groups.putIfAbsent(
      '$path|$lane',
      () => ClassifiedAdviceGroup(path, lane, []),
    );
    group.items.add(a);
  }
  return groups.values.toList()..sort((a, b) => a.key.compareTo(b.key));
}

/// Every topic/trigger group starts collapsed and opens a bounded 20-item page.
class ClassifiedAdviceList extends StatefulWidget {
  const ClassifiedAdviceList({
    super.key,
    required this.groups,
    required this.topics,
  });
  final List<ClassifiedAdviceGroup> groups;
  final TopicTree topics;

  @override
  State<ClassifiedAdviceList> createState() => _ClassifiedAdviceListState();
}

class _ClassifiedAdviceListState extends State<ClassifiedAdviceList> {
  final Map<String, int> _pages = {};

  @override
  Widget build(BuildContext context) {
    final domains = <String, List<ClassifiedAdviceGroup>>{};
    for (final group in widget.groups) {
      (domains[group.path.split('/').first] ??= []).add(group);
    }
    final keys = domains.keys.toList();
    return Material(
      type: MaterialType.transparency,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 30, 24),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final domain = keys[index];
          final groups = domains[domain]!;
          final count = groups.fold<int>(0, (n, g) => n + g.items.length);
          return ExpansionTile(
            key: ValueKey('advice-domain-$domain'),
            title: Text(widget.topics.labelOf(domain)),
            subtitle: Text('$count 条建议 · ${groups.length} 个专题分组'),
            children: [for (final group in groups) _groupTile(group)],
          );
        },
      ),
    );
  }

  Widget _groupTile(ClassifiedAdviceGroup group) {
    final pages = (group.items.length / 20).ceil();
    final page = (_pages[group.key] ?? 0).clamp(0, pages - 1);
    return ExpansionTile(
      key: ValueKey('advice-group-${group.key}'),
      title: Text(widget.topics.labelOf(group.path)),
      subtitle: Text(
        '${AdviceClassification.laneLabels[group.lane]} · ${group.items.length} 条 · 展开查看',
      ),
      children: [
        for (final a in group.items.skip(page * 20).take(20))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AdviceCard(
              advice: a,
              scope: PeriodScope.today,
              compact: true,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: page > 0
                    ? () => setState(() => _pages[group.key] = page - 1)
                    : null,
                child: const Text('上一页'),
              ),
              Text('第 ${page + 1}/$pages 页'),
              TextButton(
                onPressed: page + 1 < pages
                    ? () => setState(() => _pages[group.key] = page + 1)
                    : null,
                child: const Text('下一页'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
