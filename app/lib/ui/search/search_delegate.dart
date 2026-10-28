import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../cards/advice_card.dart';
import '../../state/app_store.dart';
import '../library/topic_tree_sheet.dart';

/// 全局搜索：搜索秒开通道 —— 标题 / 章节 / 标签 / 时机徽章全文匹配。
Future<void> showGlobalSearch(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => const GlobalSearchPage(),
  );
}

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  String _q = '';
  String _topicPath = '';
  bool _personalized = false;
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final catalog = catalogOf(context);
    final store = storeOf(context);
    final results = catalog.search(
      _q,
      topicPath: _topicPath.isEmpty ? null : _topicPath,
      include: _personalized ? (a) => store.matchPersona(a) : null,
      hiddenTopics: _personalized ? store.excludedTopicPaths : const [],
    );

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      autofocus: true,
                      onChanged: (v) => setState(() => _q = v),
                      decoration: InputDecoration(
                        hintText: '搜索 767 条建议 · 场景 / 红线 / 办事…',
                        hintStyle: TextStyle(fontSize: 12.5, color: p.inkMute),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: p.inkMute,
                        ),
                        filled: true,
                        fillColor: p.searchBg,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9999),
                          borderSide: BorderSide(color: p.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9999),
                          borderSide: BorderSide(color: p.hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9999),
                          borderSide: BorderSide(color: p.action),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '取消',
                      style: TextStyle(fontSize: 13, color: p.inkSub),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.account_tree_outlined, size: 16),
                      label: Text(
                        _topicPath.isEmpty
                            ? '全部主题'
                            : catalog.topics.breadcrumbOf(_topicPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final path = await showTopicTree(
                          context,
                          selectedPath: _topicPath,
                          personalized: _personalized,
                          candidateIds: _personalized
                              ? catalog.adviceList
                                    .where(
                                      (a) => store.matchPersona(
                                        a,
                                        includeTopicPreferences: false,
                                      ),
                                    )
                                    .map((a) => a.id)
                                    .toSet()
                              : null,
                        );
                        if (!mounted) return;
                        setState(() {
                          if (path != null) _topicPath = path;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('按画像筛选'),
                    selected: _personalized,
                    onSelected: (v) => setState(() => _personalized = v),
                  ),
                ],
              ),
            ),
            // 结果
            Expanded(
              child: _q.trim().isEmpty && _topicPath.isEmpty
                  ? _suggestions(context)
                  : _results(context, results),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestions(BuildContext context) {
    final p = AppPalettes.of(context);
    const hints = [
      '燃气',
      '安全带',
      '血压',
      '欠薪',
      '防骗',
      '发热',
      '房租',
      '头盔',
      '断舍离',
      '止付',
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(
          '试试搜索',
          style: TextStyle(fontSize: 10.5, color: p.inkMute, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in hints)
              ActionChipLike(
                label: h,
                onTap: () => setState(() {
                  _q = h;
                  _queryController.text = h;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _results(BuildContext context, List<Advice> results) {
    final p = AppPalettes.of(context);
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 28, color: p.inkMute),
            const SizedBox(height: 8),
            Text('无匹配建议', style: TextStyle(fontSize: 12.5, color: p.inkSub)),
            const SizedBox(height: 4),
            Text(
              '换个关键词，或到「生活指南」里按章节浏览',
              style: TextStyle(fontSize: 11, color: p.inkMute),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: results.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '命中 ${results.length} 条',
              style: TextStyle(fontSize: 10.5, color: p.inkMute),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AdviceCard(
            advice: results[i - 1],
            scope: PeriodScope.today,
            compact: true,
          ),
        );
      },
    );
  }
}

class ActionChipLike extends StatelessWidget {
  const ActionChipLike({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: p.pillBg,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: p.inkSub,
          ),
        ),
      ),
    );
  }
}
