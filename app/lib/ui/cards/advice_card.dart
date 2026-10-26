import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import '../detail/advice_detail_sheet.dart';
import '../share/share_sheet.dart';
import 'interactors.dart';

/// 建议交互卡：卡片主体 = 章节眉标 + 标题 + 时机徽章 + 专属微交互器。
///
/// 卡片聚焦原则（DESIGN.md）：主体严格聚焦「原子行动 + 专属微交互器」，
/// 不呈现分组类型名；状态由完成色直接表达，不用文字描述。
class AdviceCard extends StatelessWidget {
  const AdviceCard({
    super.key,
    required this.advice,
    required this.scope,
    this.compact = false,
    this.showDoneBar = true,
  });

  final Advice advice;
  final PeriodScope scope;

  /// 紧凑模式：库流中减少留白，保留全部交互。
  final bool compact;

  /// 显示完成度进度条（列表卡）。
  final bool showDoneBar;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final st = store.cardState(scope, advice.id);
    final done = st.isDone;
    final timing = TimingModel.of(advice.timingBadge);
    final detail = catalogOf(context).detailOf(advice.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: done ? p.emerald.withValues(alpha: 0.55) : p.hairline,
          width: done ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: () => HapticFeedback.selectionClick(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, compact ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, p, timing, detail != null),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  advice.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (advice.caveats.isNotEmpty && !compact) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in advice.caveats)
                        Text(
                          '· $c',
                          style: TextStyle(
                            fontSize: 11,
                            color: p.inkSub,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: compact ? 8 : 12),
                AdviceInteractor(advice: advice, scope: scope),
                if (showDoneBar) ...[
                  SizedBox(height: compact ? 8 : 10),
                  _doneBar(context, p, st),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppPalettes p, TimingModel timing, bool hasDetail) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: timing.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            advice.timingBadge,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: timing.color,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const Spacer(),
        if (hasDetail)
          _iconBtn(
            context,
            icon: Icons.info_outline,
            tip: '证据与详情',
            onTap: () => showAdviceDetail(context, advice.id),
          ),
        _iconBtn(
          context,
          icon: Icons.ios_share_outlined,
          tip: '分享此条',
          onTap: () => ShareSheet.open(context, advice),
        ),
      ],
    );
  }

  Widget _iconBtn(
    BuildContext context, {
    required IconData icon,
    required String tip,
    required VoidCallback onTap,
  }) {
    final p = AppPalettes.of(context);
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: p.inkMute),
        ),
      ),
    );
  }

  Widget _doneBar(BuildContext context, AppPalettes p, CardState st) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: st.completionRatio),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: p.pillBg,
                valueColor: AlwaysStoppedAnimation(
                  st.completionRatio >= 1 ? p.emerald : p.action,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: st.completionRatio >= 1
              ? Row(
                  key: const ValueKey('ok'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 13, color: p.emerald),
                    const SizedBox(width: 3),
                    Text(
                      '已闭环',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.emerald,
                      ),
                    ),
                  ],
                )
              : Text(
                  '${(st.completionRatio * 100).round()}%',
                  key: ValueKey(st.completionRatio),
                  style: TextStyle(fontSize: 10.5, color: p.inkMute),
                ),
        ),
      ],
    );
  }
}
