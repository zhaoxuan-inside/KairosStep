import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/topic_tree.dart';

/// Returns a selected path; '' means all topics and null means cancel.
Future<String?> showTopicTree(
  BuildContext context, {
  String selectedPath = '',
  Set<int>? candidateIds,
  bool personalized = false,
  bool manage = false,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (_) => TopicTreeSheet(
    selectedPath: selectedPath,
    candidateIds: candidateIds,
    personalized: personalized,
    manage: manage,
  ),
);

class TopicTreeSheet extends StatefulWidget {
  const TopicTreeSheet({
    super.key,
    this.selectedPath = '',
    this.candidateIds,
    this.personalized = false,
    this.manage = false,
  });

  final String selectedPath;
  final Set<int>? candidateIds;
  final bool personalized;
  final bool manage;

  @override
  State<TopicTreeSheet> createState() => _TopicTreeSheetState();
}

class _TopicTreeSheetState extends State<TopicTreeSheet> {
  late bool _manage = widget.manage;
  late final Set<String> _expanded = widget.selectedPath.isEmpty
      ? {}
      : TopicTree.ancestorsOf(widget.selectedPath).toSet();

  @override
  Widget build(BuildContext context) {
    final catalog = catalogOf(context);
    final store = storeOf(context);
    final p = AppPalettes.of(context);
    // The modal listens directly, so hiding/restoring updates counts immediately.
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final candidates = catalog.adviceList.where(
          (a) =>
              widget.candidateIds == null ||
              widget.candidateIds!.contains(a.id),
        );
        final hidden = widget.personalized
            ? store.excludedTopicPaths
            : <String>{};
        final counts = catalog.topics.countsFor(candidates, hidden: hidden);

        Widget row(TopicNode node, int depth) {
          final count = counts[node.path] ?? 0;
          if (!_manage && count == 0) return const SizedBox.shrink();
          final hiddenBy = store.hiddenAncestorOf(node.path);
          final expanded = _expanded.contains(node.path);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: depth * 14.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: node.children.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '${expanded ? '收起' : '展开'}${node.name}',
                              icon: Icon(
                                expanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                              ),
                              onPressed: () => setState(() {
                                expanded
                                    ? _expanded.remove(node.path)
                                    : _expanded.add(node.path);
                              }),
                            ),
                    ),
                    Expanded(
                      child: ListTile(
                        key: ValueKey('topic-select-${node.path}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        dense: true,
                        selected: widget.selectedPath == node.path,
                        title: Text(
                          node.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _manage && hiddenBy != null
                                ? p.inkMute
                                : p.ink,
                          ),
                        ),
                        subtitle: Text(
                          _manage && hiddenBy != null
                              ? '已隐藏 · 可恢复'
                              : '$count 条建议',
                        ),
                        onTap: () => Navigator.pop(context, node.path),
                      ),
                    ),
                    if (_manage)
                      IconButton(
                        key: ValueKey('topic-toggle-${node.path}'),
                        tooltip: hiddenBy == null
                            ? '隐藏${node.name}'
                            : '恢复${catalog.topics.labelOf(hiddenBy)}',
                        icon: Icon(
                          hiddenBy == null
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        color: hiddenBy == null ? p.inkSub : p.action,
                        onPressed: () => hiddenBy == null
                            ? store.excludeTopic(node.path)
                            : store.restoreTopic(hiddenBy),
                      ),
                  ],
                ),
              ),
              if (expanded)
                for (final child in node.children) row(child, depth + 1),
            ],
          );
        }

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '主题分类',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _manage = !_manage),
                        child: Text(_manage ? '完成管理' : '管理剪枝'),
                      ),
                      IconButton(
                        tooltip: '关闭主题分类',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    _manage
                        ? '隐藏分支会移出日常推荐；跨类建议保留在其他可见分支。全量搜索仍可查找。'
                        : '选择父级查看整个分支，展开箭头逐级查找。空分支按当前范围自动收起。',
                    style: TextStyle(
                      fontSize: 12,
                      color: p.inkSub,
                      height: 1.5,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('全部主题'),
                      ),
                      const Spacer(),
                      if (_manage && store.excludedTopicPaths.isNotEmpty)
                        TextButton(
                          onPressed: store.restoreAllTopics,
                          child: Text(
                            '恢复全部 (${store.excludedTopicPaths.length})',
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final root in catalog.topics.roots) row(root, 0),
                        if (!_manage && counts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('当前范围没有匹配主题，可切换全量范围或管理剪枝。'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
