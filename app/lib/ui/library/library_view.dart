import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import '../cards/advice_card.dart';
import 'guidance_sheet.dart';
import 'jump_deck.dart';
import 'topic_tree_sheet.dart';

/// 生活指南：737 条建议的可筛选列表。
///
/// - 右侧滑出式拼音索引，另可按章节和交互形态筛选。
/// - 范围三态：画像专属（默认）→ 父母适用 → 全量 737。
/// - 列表正文不显示字母分组标题。
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  String _letter = 'all';
  String _chapter = '全部';
  String _mode = 'all';
  String _topicPath = '';
  int _limit = 40;
  bool _indexVisible = false;
  Timer? _indexHide;

  @override
  void dispose() {
    _indexHide?.cancel();
    super.dispose();
  }

  void _showIndex() {
    _indexHide?.cancel();
    setState(() => _indexVisible = true);
    _indexHide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _indexVisible = false);
    });
  }

  void _selectLetter(String letter) {
    HapticFeedback.selectionClick();
    setState(() {
      _letter = letter;
      _limit = 40;
    });
    _showIndex();
  }

  bool get _hasFilter =>
      _topicPath.isNotEmpty ||
      _letter != 'all' ||
      _chapter != '全部' ||
      _mode != 'all';

  void _reset() => setState(() {
    _letter = 'all';
    _chapter = '全部';
    _mode = 'all';
    _topicPath = '';
    _limit = 40;
  });

  List<Advice> _candidates(
    BuildContext context, {
    bool applyTopicPreferences = true,
  }) {
    final catalog = catalogOf(context);
    final store = storeOf(context);
    var list = catalog.adviceList.toList();
    if (store.profile.prunedOnly) {
      list = store.profile.parentsOnly
          ? list.where((a) => parentsAdviceIds.contains(a.id)).toList()
          : list
                .where(
                  (a) => store.matchPersona(
                    a,
                    includeTopicPreferences: applyTopicPreferences,
                  ),
                )
                .toList();
      if (applyTopicPreferences) {
        list = list.where(store.matchesTopicPreferences).toList();
      }
    }
    if (_letter != 'all') {
      list = list.where((a) => catalog.letterOf(a) == _letter).toList();
    }
    if (_chapter != '全部') {
      list = list.where((a) => a.chapter == _chapter).toList();
    }
    if (_mode != 'all') list = list.where((a) => a.actType == _mode).toList();
    return list;
  }

  List<(String, List<Advice>)> _groups(BuildContext context) {
    final catalog = catalogOf(context);
    final store = storeOf(context);
    var list = _candidates(context);
    if (_topicPath.isNotEmpty) {
      final ids = catalog
          .underTopic(
            _topicPath,
            hiddenTopics: store.profile.prunedOnly
                ? store.excludedTopicPaths
                : const [],
          )
          .map((a) => a.id)
          .toSet();
      list = list.where((a) => ids.contains(a.id)).toList();
    }

    final byLetter = <String, List<Advice>>{};
    for (final a in list) {
      byLetter.putIfAbsent(catalog.letterOf(a), () => []).add(a);
    }
    final keys = byLetter.keys.toList()
      ..sort((x, y) => x == '#' ? 1 : (y == '#' ? -1 : x.compareTo(y)));
    return [for (final k in keys) (k, byLetter[k]!)];
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final groups = _groups(context);
    final total = groups.fold<int>(0, (n, g) => n + g.$2.length);
    final shown = total.clamp(0, _limit);

    return Column(
      children: [
        // 头部
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '生活指南',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.pillBg,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '$total 条 · ${store.profile.parentsOnly ? '父母适用' : (store.profile.prunedOnly ? '画像专属' : '全部建议')}',
                      style: TextStyle(fontSize: 10.5, color: p.inkSub),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 范围三态
              Wrap(
                spacing: 6,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _scopeChip(
                    context,
                    '画像专属',
                    on: store.profile.prunedOnly && !store.profile.parentsOnly,
                    onTap: () {
                      store.profile = store.profile.copyWith(
                        prunedOnly: true,
                        parentsOnly: false,
                      );
                    },
                  ),
                  _scopeChip(
                    context,
                    '父母适用',
                    on: store.profile.parentsOnly,
                    onTap: () {
                      store.profile = store.profile.copyWith(
                        prunedOnly: true,
                        parentsOnly: true,
                      );
                    },
                  ),
                  _scopeChip(
                    context,
                    '全量 737',
                    on: !store.profile.prunedOnly,
                    onTap: () {
                      store.profile = store.profile.copyWith(
                        prunedOnly: false,
                        parentsOnly: false,
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      AdviceGuidanceSheet.show(
                        context,
                        onSelectDomainChapter: (ch) {
                          setState(() {
                            _chapter = ch;
                            _limit = 40;
                          });
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.action.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: p.action.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 13,
                            color: p.action,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '737 全景引导',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.action,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.account_tree_outlined, size: 17),
                label: Text(
                  _topicPath.isEmpty
                      ? '按主题分类查找与剪枝'
                      : catalogOf(context).topics.breadcrumbOf(_topicPath),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final path = await showTopicTree(
                    context,
                    selectedPath: _topicPath,
                    personalized: store.profile.prunedOnly,
                    candidateIds: _candidates(
                      context,
                      applyTopicPreferences: false,
                    ).map((a) => a.id).toSet(),
                  );
                  if (!mounted) return;
                  setState(() {
                    if (path != null) _topicPath = path;
                    _limit = 40;
                  });
                },
              ),
              const SizedBox(height: 8),
              // 筛选条
              Row(
                children: [
                  _filterBtn(
                    context,
                    label: _chapter == '全部' ? '34 章节' : _chapter,
                    active: _chapter != '全部',
                    icon: Icons.book_outlined,
                    onTap: () async {
                      final v = await openJumpDeck(
                        context,
                        initialTab: 1,
                        letter: _letter,
                        chapter: _chapter,
                        mode: _mode,
                      );
                      if (v != null) {
                        setState(() {
                          _applyDeck(v);
                          _limit = 40;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _filterBtn(
                    context,
                    label: _mode == 'all' ? '形态' : actionTypeName(_mode),
                    active: _mode != 'all',
                    icon: Icons.category_outlined,
                    onTap: () async {
                      final v = await openJumpDeck(
                        context,
                        initialTab: 2,
                        letter: _letter,
                        chapter: _chapter,
                        mode: _mode,
                      );
                      if (v != null) {
                        setState(() {
                          _applyDeck(v);
                          _limit = 40;
                        });
                      }
                    },
                  ),
                  if (_hasFilter) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: _reset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: p.rose.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Icon(
                          Icons.filter_alt_off_outlined,
                          size: 14,
                          color: p.rose,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // 流
        Expanded(
          child: Stack(
            children: [
              total == 0
                  ? _empty(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: groups.length + 1,
                      itemBuilder: (context, i) {
                        if (i == groups.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                shown >= total
                                    ? '已平铺展开当前全部 $total 条建议交互微工具'
                                    : '已展示 $shown / $total 条',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: p.inkMute,
                                ),
                              ),
                            ),
                          );
                        }
                        final (_, items) = groups[i];
                        final preceding = groups
                            .take(i)
                            .fold<int>(0, (n, g) => n + g.$2.length);
                        if (preceding >= _limit) return const SizedBox.shrink();
                        final take = items.length.clamp(0, _limit - preceding);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            for (final a in items.take(take))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AdviceCard(
                                  advice: a,
                                  scope: PeriodScope.today,
                                  compact: true,
                                ),
                              ),
                            if (preceding + take >= _limit && shown < total)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            setState(() => _limit += 60),
                                        child: const Text(
                                          '+ 60 条',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            setState(() => _limit = total),
                                        child: Text(
                                          '全展开 ($total)',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(child: _buildIndex(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndex(BuildContext context) {
    final p = AppPalettes.of(context);
    if (!_indexVisible) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showIndex,
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx < 0) _showIndex();
        },
        child: SizedBox(
          width: 25,
          height: 82,
          child: Center(
            child: Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: p.action.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }
    const rowHeight = 14.0;
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final index = (details.localPosition.dy / rowHeight).floor().clamp(
          0,
          26,
        );
        final letter = index == 0 ? 'all' : _alphabet[index - 1];
        if (_letter != letter) _selectLetter(letter);
      },
      child: Container(
        width: 36,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
          ),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final letter in ['all', ..._alphabet.split('')])
              GestureDetector(
                onTap: () => _selectLetter(letter),
                child: SizedBox(
                  width: 36,
                  height: rowHeight,
                  child: Center(
                    child: Text(
                      letter == 'all' ? '全' : letter,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: _letter == letter
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: _letter == letter ? p.action : p.inkSub,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _applyDeck(DeckResult v) {
    _letter = v.letter;
    _chapter = v.chapter;
    _mode = v.mode;
  }

  Widget _scopeChip(
    BuildContext context,
    String label, {
    required bool on,
    required VoidCallback onTap,
  }) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () {
        setState(() {});
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? p.action.withValues(alpha: 0.14) : p.pillBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: on ? p.action.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? p.action : p.inkSub,
          ),
        ),
      ),
    );
  }

  Widget _filterBtn(
    BuildContext context, {
    required String label,
    required bool active,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final p = AppPalettes.of(context);
    return Flexible(
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? p.action.withValues(alpha: 0.12) : p.pillBg,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: active ? p.action : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: active ? p.action : p.inkMute),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? p.action : p.inkSub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final p = AppPalettes.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 30, color: p.inkMute),
          const SizedBox(height: 10),
          Text(
            '当前组合筛选下暂无匹配建议',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '可尝试清空某个维度或恢复全部全景视图',
            style: TextStyle(fontSize: 11, color: p.inkMute),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _reset, child: const Text('重置')),
        ],
      ),
    );
  }
}
