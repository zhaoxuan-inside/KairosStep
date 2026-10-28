import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../detail/advice_detail_sheet.dart';

/// 767 条建议全景引导罗盘与领域漫游底板。
///
/// 覆盖 6 大人生支柱（180健康、128职场、113家庭、202财产、99应急、45节律），
/// 确保建议的引导能够 100% 覆盖到全库 767 条建议。
class AdviceGuidanceSheet extends StatefulWidget {
  const AdviceGuidanceSheet({
    super.key,
    this.initialDomain,
    this.onSelectDomainChapter,
  });

  final LifeDomain? initialDomain;
  final void Function(String chapter)? onSelectDomainChapter;

  static Future<void> show(
    BuildContext context, {
    LifeDomain? initialDomain,
    void Function(String chapter)? onSelectDomainChapter,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdviceGuidanceSheet(
        initialDomain: initialDomain,
        onSelectDomainChapter: onSelectDomainChapter,
      ),
    );
  }

  @override
  State<AdviceGuidanceSheet> createState() => _AdviceGuidanceSheetState();
}

class _AdviceGuidanceSheetState extends State<AdviceGuidanceSheet>
    with SingleTickerProviderStateMixin {
  late LifeDomain _selectedDomain;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _selectedDomain = widget.initialDomain ?? LifeDomain.health;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _switchDomain(LifeDomain d) {
    if (_selectedDomain == d) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedDomain = d);
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final catalog = catalogOf(context);
    final isDark = p.brightness == Brightness.dark;

    final domainAdvices = catalog.adviceList
        .where((a) => _selectedDomain.chapters.contains(a.chapter))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: p.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // 顶端拖拽手柄
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.hairline,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            // 顶栏说明
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.action.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.explore_outlined, size: 20, color: p.action),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '767 条建议全景引导罗盘',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '六大支柱完整覆盖 · 100% 消除信息死角',
                          style: TextStyle(fontSize: 11, color: p.inkSub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: p.inkMute),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 六大领域水平选择 Tab 栏
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: LifeDomain.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final domain = LifeDomain.values[i];
                  final isSelected = domain == _selectedDomain;
                  return GestureDetector(
                    onTap: () => _switchDomain(domain),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? domain.accentColor.withValues(alpha: 0.15)
                            : p.surface,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isSelected ? domain.accentColor : p.hairline,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            domain.icon,
                            size: 15,
                            color: isSelected ? domain.accentColor : p.inkSub,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            domain.shortTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? domain.accentColor : p.ink,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? domain.accentColor.withValues(alpha: 0.2)
                                  : p.hairline,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              '${domain.totalCount}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? domain.accentColor : p.inkMute,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // 内容滚动区
            Expanded(
              child: FadeTransition(
                opacity: _animController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // 领域综述横幅
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedDomain.accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedDomain.accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _selectedDomain.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _selectedDomain.accentColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '共 ${_selectedDomain.totalCount} 条实证建议',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedDomain.accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDomain.description,
                              style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 涵盖章节胶囊群
                      Text(
                        '包含章节 (${_selectedDomain.chapters.length} 章)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.inkSub),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedDomain.chapters.map((ch) {
                          final count = catalog.chapterCounts[ch] ?? 0;
                          return ActionChip(
                            avatar: CircleAvatar(
                              radius: 8,
                              backgroundColor: _selectedDomain.accentColor.withValues(alpha: 0.2),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedDomain.accentColor,
                                ),
                              ),
                            ),
                            label: Text(
                              ch,
                              style: TextStyle(fontSize: 11, color: p.ink),
                            ),
                            backgroundColor: p.surface,
                            side: BorderSide(color: p.hairline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                              widget.onSelectDomainChapter?.call(ch);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      // 该领域建议精选预览
                      Row(
                        children: [
                          Text(
                            '精选实证建议与黄金行动',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink),
                          ),
                          const Spacer(),
                          Text(
                            '点击查看实证详情与科学出处',
                            style: TextStyle(fontSize: 10.5, color: p.inkMute),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...domainAdvices.take(15).map((a) => _adviceSampleTile(p, a)),
                      if (domainAdvices.length > 15) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            '已展示前 15 条 · 领域内其余 ${domainAdvices.length - 15} 条可直接在库中按章节检索',
                            style: TextStyle(fontSize: 11, color: p.inkMute),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adviceSampleTile(AppPalettes p, Advice a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Text(
            a.title,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink, height: 1.35),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _selectedDomain.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    a.chapter,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: _selectedDomain.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '编号 #${a.id}',
                  style: TextStyle(fontSize: 10, color: p.inkMute),
                ),
              ],
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 12, color: p.inkMute),
          onTap: () {
            HapticFeedback.lightImpact();
            showAdviceDetail(context, a.id);
          },
        ),
      ),
    );
  }
}
