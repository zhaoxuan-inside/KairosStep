import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// 齿轮时间尺：1.5 小时聚焦视窗刻度尺。
///
/// - 时间范围：1.5 小时（90 分钟），中心对齐当前锚点，视野覆盖前 45 分钟至后 45 分钟。
/// - 无外层背景框，两端高斯模糊与渐变虚化自然过渡。
/// - 刻度层级：整点显示完整时间（如 23:00），15/30/45 分刻度显示纯数字（如 15），5 分钟中刻度，1 分钟机械齿微刻度。
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 1.5 小时 = 90 分钟，定义每分钟像素跨度
        final pixelsPerMinute = width / 90.0;
        final edgeWidth = math.min(64.0, width * 0.16);
        final blurRatio = width > 0 ? (edgeWidth / width) : 0.15;

        return SizedBox(
          height: 54,
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
                // 1. 整体标尺两端渐隐全局遮罩 (与 Demo -webkit-mask-image 同构)
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: const [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        blurRatio * 0.7,
                        1.0 - blurRatio * 0.7,
                        1.0,
                      ],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Stack(
                      children: [
                        // 1.1 虚化渐变层 (Defocus Layer)：两端保持完全虚化并向中心平滑衰减，绝不回弹为清晰
                        Positioned.fill(
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black,
                                Colors.black,
                              ],
                              stops: [
                                0.0,
                                blurRatio * 0.5,
                                blurRatio * 1.3,
                                1.0 - blurRatio * 1.3,
                                1.0 - blurRatio * 0.5,
                                1.0,
                              ],
                            ).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 0),
                              child: CustomPaint(
                                painter: _RulerPainter(
                                  now: now,
                                  palettes: p,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 1.2 清晰标尺层 (Sharp Layer)：中心完全清晰，向两端单调衰减交接给虚化层，外侧彻底为零
                        Positioned.fill(
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                                Colors.transparent,
                              ],
                              stops: [
                                0.0,
                                blurRatio * 0.5,
                                blurRatio * 1.3,
                                1.0 - blurRatio * 1.3,
                                1.0 - blurRatio * 0.5,
                                1.0,
                              ],
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
                      ],
                    ),
                  ),
                ),

                // 2. 左侧边缘柔和色彩溶入遮罩 (与 Demo .ruler-edge-blur-left 渐变背景同构)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: edgeWidth,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            p.canvas,
                            p.canvas.withValues(alpha: 0.85),
                            p.canvas.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.25, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. 右侧边缘柔和色彩溶入遮罩 (与 Demo .ruler-edge-blur-right 渐变背景同构)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: edgeWidth,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            p.canvas,
                            p.canvas.withValues(alpha: 0.85),
                            p.canvas.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.25, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. 居中机械准心指示器
                Center(
                  child: CustomPaint(
                    size: const Size(12, 54),
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
    );
  }
}

/// 标尺绘制：在 1.5 小时（90 分钟）内绘制整点、15分钟、5分钟与1分钟齿轮刻度
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
      if (x < -20 || x > width + 20) continue;

      final isHour = t.minute == 0;
      final is15Min = t.minute % 15 == 0;
      final is5Min = t.minute % 5 == 0;

      if (isHour) {
        // 整点刻度：带有完整时间（如 23:00）并着色
        final c = _GearRulerState.hourColor(palettes, t.hour);
        canvas.drawLine(
          Offset(x, height - 18),
          Offset(x, height - 2),
          Paint()
            ..color = c
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );

        // 正点时间标签：例如 23:00
        final timeStr =
            '${t.hour.toString().padLeft(2, '0')}:00';
        final tp = TextPainter(
          text: TextSpan(
            text: timeStr,
            style: TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2.0, height - 34));
      } else if (is15Min) {
        // 15/30/45 分刻度：仅显示纯数字（如 15、30、45），无重复小时前缀
        canvas.drawLine(
          Offset(x, height - 13),
          Offset(x, height - 2),
          Paint()
            ..color = palettes.inkSub.withValues(alpha: 0.75)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );

        final minStr = '${t.minute}';
        final tp = TextPainter(
          text: TextSpan(
            text: minStr,
            style: TextStyle(
              color: palettes.inkSub,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2.0, height - 29));
      } else if (is5Min) {
        // 5 分钟中刻度
        canvas.drawLine(
          Offset(x, height - 9),
          Offset(x, height - 2),
          Paint()
            ..color = palettes.inkSub.withValues(alpha: 0.4)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // 1 分钟微齿轮刻度
        canvas.drawLine(
          Offset(x, height - 5),
          Offset(x, height - 2),
          Paint()
            ..color = palettes.hairline.withValues(alpha: 0.7)
            ..strokeWidth = 0.8,
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
      ..moveTo(x - 3.5, 3)
      ..lineTo(x + 3.5, 3)
      ..lineTo(x, 8)
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
      Offset(x, 8),
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
