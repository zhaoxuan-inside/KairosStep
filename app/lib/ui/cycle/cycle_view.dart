import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import '../cards/advice_card.dart';

/// 周期页：90 天周期培养体系看板 + 每周 / 每月 / 每年 三分段。
class CycleView extends StatelessWidget {
  const CycleView({super.key});

  static const _segs = [
    (PeriodScope.weekly, '每周', '每周循环行动 · 每周节律'),
    (PeriodScope.monthly, '每月', '本月关键周期 · 月度防范'),
    (PeriodScope.yearly, '每年', '年度里程碑与持续筛查'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final plan = store.ninetyDayPlan;

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('周期', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    '90 天能力跃迁 · 每周 · 每月 · 每年循环节律',
                    style: TextStyle(fontSize: 12, color: p.inkSub),
                  ),
                  const SizedBox(height: 14),

                  // ---- 90 天能力跃迁看板 ----
                  _buildNinetyDayCard(context, p, store, plan),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                tabs: [for (final (_, name, _) in _segs) Tab(text: name)],
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                dividerColor: p.hairline,
              ),
              p.canvas,
            ),
          ),
        ],
        body: TabBarView(
          children: [
            for (final (seg, _, sub) in _segs)
              _SegPanel(scope: seg, sub: sub),
          ],
        ),
      ),
    );
  }

  Widget _buildNinetyDayCard(
    BuildContext context,
    AppPalettes p,
    AppStore store,
    NinetyDayPlan plan,
  ) {
    final day = plan.currentDay;
    final phase = plan.phase;
    final progress = (day / 90.0).clamp(0.0, 1.0);
    final catalog = catalogOf(context);

    final goalAdvices = plan.goalAdviceIds
        .map((id) => catalog.adviceById(id))
        .whereType<Advice>()
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.action.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${phase.label} · 第 $day / 90 天',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: p.action,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: p.inkSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            phase.desc,
            style: TextStyle(fontSize: 11.5, color: p.inkSub),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: p.pillBg,
              valueColor: AlwaysStoppedAnimation(p.action),
            ),
          ),
          const SizedBox(height: 14),

          // 核心 3 动作
          Text(
            '本周期聚焦 3 个核心动作',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.inkMute),
          ),
          const SizedBox(height: 8),
          for (final a in goalAdvices)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: p.surfaceGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AppHairlineIcons.shield(color: p.action, size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.title,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showSwapGoalSheet(context, store, a.id),
                    child: Text(
                      '换一个',
                      style: TextStyle(fontSize: 10.5, color: p.inkMute),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSwapGoalSheet(BuildContext context, AppStore store, int oldId) {
    final catalog = catalogOf(context);
    final p = AppPalettes.of(context);
    final candidates = catalog.adviceList.take(20).where((a) => a.id != oldId).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: candidates.length,
        itemBuilder: (c, i) {
          final cand = candidates[i];
          return ListTile(
            title: Text(cand.title, style: TextStyle(fontSize: 13, color: p.ink)),
            subtitle: Text(cand.chapter, style: TextStyle(fontSize: 11, color: p.inkMute)),
            trailing: TextButton(
              child: const Text('替换为该项'),
              onPressed: () {
                store.swapCycleGoal(oldId, cand.id);
                Navigator.of(ctx).pop();
              },
            ),
          );
        },
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar, this.bgColor);
  final TabBar tabBar;
  final Color bgColor;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: bgColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              children: [
                AppHairlineIcons.check(color: p.emerald, size: 28),
                const SizedBox(height: 8),
                Text('当前周期无特定待办', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 4),
                Text('可在生活指南中翻转卡片配置触发周期将其加入此处', style: TextStyle(fontSize: 11, color: p.inkMute)),
              ],
            ),
          )
        else
          for (final a in advices) ...[
            AdviceCard(advice: a, scope: scope),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
