import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// 齿轮时间尺：1.5 小时聚焦视窗刻度尺。
///
/// - 时间范围：1.5 小时（90 分钟），中心对齐当前锚点，视野覆盖前 45 分钟至后 45 分钟。
/// - 刻度层级：15 分钟主刻度（附带数字时间）、5 分钟中刻度、1 分钟机械齿微刻度。
/// - 交互特性：支持横向滑动手感推演与点按定位；实时模式带呼吸灯，推演模式支持一键回到此刻。
class GearRuler extends StatefulWidget {
  const GearRuler({
    super.key,
    required this.now,
    required this.live,
    required this.onChanged,
    this.onReset,
  });

  final DateTime now;
  final bool live;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onReset;

  @override
  State<GearRuler> createState() => _GearRulerState();
}

class _GearRulerState extends State<GearRuler> {
  double _dragAccumulator = 0.0;

  static Color hourColor(AppPalettes p, int hour) {
    final h = (hour % 24 + 24) % 24;
    if (h >= 5 && h < 9) return p.action;
    if (h >= 9 && h < 12) return p.indigo;
    if (h >= 12 && h < 18) return p.emerald;
    if (h >= 18 && h < 22) return p.amber;
    return p.rose;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final now = widget.now;
    final live = widget.live;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 顶部状态栏：实时时钟 + 状态指示 + 1.5h视窗标签 + 回到此刻
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Text(
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                    letterSpacing: -0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                if (live)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.emerald,
                          boxShadow: [
                            BoxShadow(
                              color: p.emerald.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '实时同步中',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.emerald,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_outlined, size: 13, color: p.amber),
                      const SizedBox(width: 4),
                      Text(
                        '预演模式',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.amber,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                // 1.5 小时视窗范围徽标
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.hairline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timelapse_outlined, size: 11, color: p.inkSub),
                      const SizedBox(width: 3),
                      Text(
                        '1.5h 视窗',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: p.inkSub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!live && widget.onReset != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onReset!();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.emerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: p.emerald.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location, size: 11, color: p.emerald),
                          const SizedBox(width: 3),
                          Text(
                            '回到此刻',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: p.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. 1.5 小时机械齿轮标尺视口
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // 1.5 小时 = 90 分钟，定义每分钟像素跨度
              final pixelsPerMinute = width / 90.0;

              return SizedBox(
                height: 56,
                width: width,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _dragAccumulator = 0.0,
                  onHorizontalDragUpdate: (details) {
                    _dragAccumulator += details.primaryDelta ?? 0.0;
                    final deltaMinutes = -(_dragAccumulator / pixelsPerMinute);
                    if (deltaMinutes.abs() >= 1.0) {
                      final mins = deltaMinutes.truncate();
                      _dragAccumulator -= -mins * pixelsPerMinute;
                      final target = now.add(Duration(minutes: mins));
                      if (mins.abs() >= 5 || target.minute % 5 == 0) {
                        HapticFeedback.selectionClick();
                      }
                      widget.onChanged(target);
                    }
                  },
                  onTapDown: (details) {
                    final dx = details.localPosition.dx - (width / 2.0);
                    final deltaMinutes = (dx / pixelsPerMinute).round();
                    if (deltaMinutes != 0) {
                      HapticFeedback.selectionClick();
                      widget.onChanged(now.add(Duration(minutes: deltaMinutes)));
                    }
                  },
                  child: Stack(
                    children: [
                      // 标尺带：带边缘虚化渐隐遮罩
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.08, 0.92, 1.0],
                          ).createShader(bounds),
                          blendMode: BlendMode.dstIn,
                          child: CustomPaint(
                            painter: _RulerPainter(
                              now: now,
                              palettes: p,
                            ),
                          ),
                        ),
                      ),
                      // 居中机械准心指示器
                      Center(
                        child: CustomPaint(
                          size: const Size(12, 56),
                          painter: _CenterIndicatorPainter(
                            color: live ? p.emerald : p.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 3. 底部视窗标注：前45分 ‹ 此刻 › 后45分
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Row(
              children: [
                Text(
                  live
                      ? '1.5小时聚焦视窗 · 左右滑动可顺滑推演'
                      : '已推演至 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 9.5, color: p.inkMute),
                ),
                const Spacer(),
                Text(
                  '-45分 ‹ 此刻 › +45分',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: live ? p.emerald.withValues(alpha: 0.85) : p.amber,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 标尺绘制：在 1.5 小时（90 分钟）内绘制 15 分钟、5 分钟与 1 分钟齿轮刻度
class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.now,
    required this.palettes,
  });

  final DateTime now;
  final AppPalettes palettes;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final pixelsPerMinute = width / 90.0;
    final centerX = width / 2.0;

    // 锚定中心：精确到秒
    final secondOffset = now.second / 60.0;

    // 绘制覆盖 -48 分钟 到 +48 分钟
    for (int delta = -48; delta <= 48; delta++) {
      final t = now.add(Duration(minutes: delta));
      final exactDelta = delta - secondOffset;
      final x = centerX + exactDelta * pixelsPerMinute;
      if (x < -10 || x > width + 10) continue;

      final is15Min = t.minute % 15 == 0;
      final is5Min = t.minute % 5 == 0;

      if (is15Min) {
        // 15 分钟主刻度：带有时间文字与时段着色
        final c = _GearRulerState.hourColor(palettes, t.hour);
        canvas.drawLine(
          Offset(x, height - 16),
          Offset(x, height - 2),
          Paint()
            ..color = c
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );

        // 时间标签，如 18:45
        final timeStr =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        final tp = TextPainter(
          text: TextSpan(
            text: timeStr,
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2.0, height - 32));
      } else if (is5Min) {
        // 5 分钟中刻度
        canvas.drawLine(
          Offset(x, height - 11),
          Offset(x, height - 2),
          Paint()
            ..color = palettes.inkSub.withValues(alpha: 0.55)
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // 1 分钟微齿轮刻度
        canvas.drawLine(
          Offset(x, height - 6),
          Offset(x, height - 2),
          Paint()
            ..color = palettes.hairline
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.now != now || old.palettes != palettes;
}

/// 居中机械准心指示器（顶部三角 + 竖直准线 + 底部三角）
class _CenterIndicatorPainter extends CustomPainter {
  const _CenterIndicatorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2.0;
    final h = size.height;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 顶部倒三角指示器
    final topTriangle = Path()
      ..moveTo(x - 3.5, 6)
      ..lineTo(x + 3.5, 6)
      ..lineTo(x, 11)
      ..close();
    canvas.drawPath(topTriangle, paint);

    // 底部正三角指示器
    final bottomTriangle = Path()
      ..moveTo(x - 3.5, h - 2)
      ..lineTo(x + 3.5, h - 2)
      ..lineTo(x, h - 7)
      ..close();
    canvas.drawPath(bottomTriangle, paint);

    // 中间准心刻线
    canvas.drawLine(
      Offset(x, 11),
      Offset(x, h - 7),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CenterIndicatorPainter old) => old.color != color;
}

/// 时段弧环（保留备用：当下页顶部装饰性时段环）。
class PeriodArc extends CustomPainter {
  PeriodArc({required this.progress, required this.color});

  final double progress; // 0~1 当前时段进度
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(PeriodArc old) =>
      old.progress != progress || old.color != color;
}
