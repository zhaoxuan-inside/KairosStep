import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';

/// 跳转矩阵筛选结果。
class DeckResult {
  const DeckResult(this.letter, this.chapter, this.mode);
  final String letter;
  final String chapter;
  final String mode;
}



/// 跳转矩阵：拼音字母 / 34 章节 / 交互形态，点击方块即时聚焦。
Future<DeckResult?> openJumpDeck(
  BuildContext context, {
  int initialTab = 0,
  required String letter,
  required String chapter,
  required String mode,
}) {
  return showModalBottomSheet<DeckResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _JumpDeck(
      initialTab: initialTab,
      letter: letter,
      chapter: chapter,
      mode: mode,
    ),
  );
}

class _JumpDeck extends StatefulWidget {
  const _JumpDeck({
    required this.initialTab,
    required this.letter,
    required this.chapter,
    required this.mode,
  });

  final int initialTab;
  final String letter;
  final String chapter;
  final String mode;

  @override
  State<_JumpDeck> createState() => _JumpDeckState();
}

class _JumpDeckState extends State<_JumpDeck> {
  late int _tab = widget.initialTab;
  late String _letter = widget.letter;
  late String _chapter = widget.chapter;
  late String _mode = widget.mode;

  void _pop() => Navigator.pop(
      context, DeckResult(_letter, _chapter, _mode));

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final catalog = catalogOf(context);
    final height = MediaQuery.of(context).size.height * 0.82;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            // 头
            Row(
              children: [
                Icon(Icons.grid_view_outlined, size: 15, color: p.action),
                const SizedBox(width: 6),
                Text('快速聚焦筛选中枢',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(9999),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 三维 Tab
            Row(
              children: [
                _deckTab('拼音', _tab == 0, () => setState(() => _tab = 0)),
                const SizedBox(width: 6),
                _deckTab('34 大分类', _tab == 1, () => setState(() => _tab = 1)),
                const SizedBox(width: 6),
                _deckTab('形态', _tab == 2, () => setState(() => _tab = 2)),
              ],
            ),
            const SizedBox(height: 12),
            // 「全部」重置行
            Row(
              children: [
                _resetPill(context, '全部', sub: switch (_tab) {
                  0 => '${catalog.adviceList.length}条',
                  1 => '全域',
                  _ => '全量',
                }, onTap: () {
                  setState(() {
                    switch (_tab) {
                      case 0:
                        _letter = 'all';
                      case 1:
                        _chapter = '全部';
                      default:
                        _mode = 'all';
                    }
                  });
                  _pop();
                }),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: switch (_tab) {
                0 => _letterGrid(context, catalog),
                1 => _chapterGrid(context, catalog),
                _ => _modeGrid(context),
              },
            ),
            const SizedBox(height: 10),
            Text('点击方块即可即时聚焦', style: TextStyle(fontSize: 10.5, color: p.inkMute)),
          ],
        ),
      ),
    );
  }

  Widget _deckTab(String label, bool on, VoidCallback onTap) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: on ? p.action.withValues(alpha: 0.14) : p.pillBg,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: on ? p.action : p.inkSub,
          ),
        ),
      ),
    );
  }

  Widget _resetPill(BuildContext context, String label,
      {String? sub, required VoidCallback onTap}) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.pillBg,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.ink)),
            if (sub != null) ...[
              const SizedBox(width: 5),
              Text(sub, style: TextStyle(fontSize: 10, color: p.inkMute)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _letterGrid(BuildContext context, Catalog catalog) {
    final p = AppPalettes.of(context);
    final letters = catalog.letterCounts.keys.toList();
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: letters.length,
      itemBuilder: (context, i) {
        final l = letters[i];
        final on = _letter == l;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _letter = l);
            _pop();
          },
          child: Container(
            decoration: BoxDecoration(
              color: on ? p.action : p.pillBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : p.ink,
                  ),
                ),
                Text(
                  '${catalog.letterCounts[l]}',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: on ? Colors.white70 : p.inkMute,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chapterGrid(BuildContext context, Catalog catalog) {
    final p = AppPalettes.of(context);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: catalog.chapters.length,
      itemBuilder: (context, i) {
        final c = catalog.chapters[i];
        final on = _chapter == c;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _chapter = c);
            _pop();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: on ? p.action.withValues(alpha: 0.14) : p.pillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: on ? p.action : Colors.transparent, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? p.action : p.ink,
                    ),
                    overflow: TextOverflow.fade,
                  ),
                ),
                Text(
                  '${catalog.chapterCounts[c]} 条',
                  style: TextStyle(fontSize: 9.5, color: p.inkMute),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modeGrid(BuildContext context) {
    final p = AppPalettes.of(context);
    final catalog = catalogOf(context);
    final modes = actionTypes.skip(1).toList();
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: modes.length,
      itemBuilder: (context, i) {
        final m = modes[i];
        final on = _mode == m.id;
        final count = catalog.modeCounts[m.id] ?? 0;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _mode = m.id);
            _pop();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: on ? p.action.withValues(alpha: 0.14) : p.pillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: on ? p.action : Colors.transparent, width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(m.icon, size: 18, color: on ? p.action : p.inkSub),
                const SizedBox(height: 6),
                Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    color: on ? p.action : p.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('$count 条', style: TextStyle(fontSize: 9, color: p.inkMute)),
              ],
            ),
          ),
        );
      },
    );
  }
}
