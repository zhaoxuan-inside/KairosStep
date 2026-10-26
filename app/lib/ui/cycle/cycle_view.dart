import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';
import '../cards/advice_card.dart';

/// 周期页：每周 / 每月 / 每年 三分段，各带聚光流与完成量胶囊。
class CycleView extends StatelessWidget {
  const CycleView({super.key});

  static const _segs = [
    (PeriodScope.weekly, '每周', '每周循环行动 · 每周节律 · 循环打卡'),
    (PeriodScope.monthly, '每月', '本月关键周期 · 月度长效防范'),
    (PeriodScope.yearly, '每年', '年度里程碑与持续事件 · 含日期范围窗口期'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('周期', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(
                  '每周 · 每月 · 每年循环节律已备好',
                  style: TextStyle(fontSize: 12, color: p.inkSub),
                ),
              ],
            ),
          ),
          TabBar(
            tabs: [for (final (_, name, _) in _segs) Tab(text: name)],
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            dividerColor: p.hairline,
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final (seg, _, sub) in _segs)
                  _SegPanel(scope: seg, sub: sub),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegPanel extends StatelessWidget {
  const _SegPanel({required this.scope, required this.sub});

  final PeriodScope scope;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final (done, total) = store.countersOf(scope);
    final advices = store.cycleAdvicesOf(scope);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(sub, style: TextStyle(fontSize: 11, color: p.inkMute))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: done >= total && total > 0
                    ? p.emerald.withValues(alpha: 0.14)
                    : p.pillBg,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '$done / $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: done >= total && total > 0 ? p.emerald : p.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (advices.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.hairline),
            ),
            child: Center(
              child: Text(
                '暂无当前周期的专属行动建议',
                style: TextStyle(fontSize: 12, color: p.inkSub),
              ),
            ),
          )
        else
          for (final advice in advices)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AdviceCard(advice: advice, scope: scope),
            ),
        Text(
          '周期完成量计入本分段胶囊 · 跨周期自然滚动',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: p.inkMute),
        ),
      ],
    );
  }
}
