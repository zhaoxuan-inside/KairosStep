import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/time_quotes.dart';
import '../../state/app_store.dart';

/// 顶部搜索栏左侧的同心四层圆环进度框
///
/// 从里到外依次代表：
/// - Ring 1 (最内层): 当下 (前后 45 分钟窗口)
/// - Ring 2 (次内层): 今天 / 每天
/// - Ring 3 (次外层): 本周
/// - Ring 4 (最外层): 本月
///
/// 每层专属独立颜色；已完成高亮饱满，未完成暗色底轨。
/// 点击弹出四层粒度详细进度弹窗卡。
class ConcentricProgressRingWidget extends StatelessWidget {
  const ConcentricProgressRingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);

    // 计算各层级的统计数据
    final (nowDone, nowTotal) = _getNowCounters(store);
    final (todayDone, todayTotal) = store.countersOf(PeriodScope.today);
    final (weekDone, weekTotal) = store.countersOf(PeriodScope.weekly);
    final (monthDone, monthTotal) = store.countersOf(PeriodScope.monthly);

    // 专属颜色
    final colorNow = p.amber; // 最内层：当下 (琥珀黄)
    final colorToday = p.action; // 次内层：今天 (行动蓝)
    final colorWeek = p.emerald; // 次外层：本周 (护盾绿)
    final colorMonth = p.indigo; // 最外层：本月 (决策靛紫)

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDetailsDialog(
          context,
          p,
          now: (done: nowDone, total: nowTotal, color: colorNow),
          today: (done: todayDone, total: todayTotal, color: colorToday),
          week: (done: weekDone, total: weekTotal, color: colorWeek),
          month: (done: monthDone, total: monthTotal, color: colorMonth),
        );
      },
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
        ),
        padding: const EdgeInsets.all(3),
        child: CustomPaint(
          size: const Size(32, 32),
          painter: _ConcentricRingsPainter(
            rings: [
              // 从外到里绘制：先外环，最后内环
              _RingData(
                radius: 14.2,
                strokeWidth: 1.8,
                color: colorMonth,
                progress: monthTotal > 0 ? (monthDone / monthTotal) : 0.0,
              ),
              _RingData(
                radius: 10.8,
                strokeWidth: 1.8,
                color: colorWeek,
                progress: weekTotal > 0 ? (weekDone / weekTotal) : 0.0,
              ),
              _RingData(
                radius: 7.4,
                strokeWidth: 1.8,
                color: colorToday,
                progress: todayTotal > 0 ? (todayDone / todayTotal) : 0.0,
              ),
              _RingData(
                radius: 4.0,
                strokeWidth: 1.8,
                color: colorNow,
                progress: nowTotal > 0 ? (nowDone / nowTotal) : 0.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (int, int) _getNowCounters(AppStore store) {
    final nowList = store.advicesForWindow(DateTime.now());
    if (nowList.isEmpty) return (0, 0);
    int done = 0;
    for (final a in nowList) {
      if (store.cardState(PeriodScope.today, a.id).isDone) {
        done++;
      }
    }
    return (done, nowList.length);
  }

  void _showDetailsDialog(
    BuildContext context,
    AppPalettes p, {
    required ({int done, int total, Color color}) now,
    required ({int done, int total, Color color}) today,
    required ({int done, int total, Color color}) week,
    required ({int done, int total, Color color}) month,
  }) {
    // 每次打开弹窗随机抽一句时间名言,弹窗存续期间保持不变。
    final quote = pickTimeQuote();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.donut_large_rounded, color: p.action, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '防线行动进度四环仪',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.inkMute),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '四层同心圆环反映您在不同生命时间跨度的执行守卫',
                style: TextStyle(fontSize: 11.5, color: p.inkSub),
              ),
              const SizedBox(height: 16),
              _buildProgressRow(
                p,
                ringLabel: '当下',
                done: now.done,
                total: now.total,
                color: now.color,
              ),
              const SizedBox(height: 12),
              _buildProgressRow(
                p,
                ringLabel: '今天',
                done: today.done,
                total: today.total,
                color: today.color,
              ),
              const SizedBox(height: 12),
              _buildProgressRow(
                p,
                ringLabel: '本周',
                done: week.done,
                total: week.total,
                color: week.color,
              ),
              const SizedBox(height: 12),
              _buildProgressRow(
                p,
                ringLabel: '本月',
                done: month.done,
                total: month.total,
                color: month.color,
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: p.hairline),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.pillBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                        Icon(Icons.format_quote_rounded, size: 14, color: p.emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quote,
                            style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.4),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRow(
    AppPalettes p, {
    required String ringLabel,
    required int done,
    required int total,
    required Color color,
  }) {
    final unDone = math.max(0, total - done);
    final ratio = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 最左:彩色圆点 + 层级标签
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(ringLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink)),
          ],
        ),
        const SizedBox(width: 12),
        // 右侧:进度数据在上,进度条在下
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已完成 $done · 未完成 $unDone · 总数 $total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: color.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingData {
  const _RingData({
    required this.radius,
    required this.strokeWidth,
    required this.color,
    required this.progress,
  });

  final double radius;
  final double strokeWidth;
  final Color color;
  final double progress; // 0.0 ~ 1.0
}

class _ConcentricRingsPainter extends CustomPainter {
  const _ConcentricRingsPainter({required this.rings});

  final List<_RingData> rings;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final ring in rings) {
      // 1. 绘制暗色背景圆环（代表未完成轨道）
      final bgPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.strokeWidth;

      canvas.drawCircle(center, ring.radius, bgPaint);

      // 2. 绘制高亮已完成进度弧线
      if (ring.progress > 0) {
        final activePaint = Paint()
          ..color = ring.color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ring.strokeWidth;

        // 从顶部正上方 (-90度) 顺时针旋转
        const startAngle = -math.pi / 2;
        final sweepAngle = 2 * math.pi * ring.progress.clamp(0.0, 1.0);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: ring.radius),
          startAngle,
          sweepAngle,
          false,
          activePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) {
    if (oldDelegate.rings.length != rings.length) return true;
    for (int i = 0; i < rings.length; i++) {
      if (oldDelegate.rings[i].progress != rings[i].progress ||
          oldDelegate.rings[i].color != rings[i].color) {
        return true;
      }
    }
    return false;
  }
}
