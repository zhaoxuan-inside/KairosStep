import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 1.2px~1.4px 极简细线矢量自绘图标库 (Bespoke Hairline Icons)
///
/// 严格遵循 DESIGN.md 温暖纸质美学：纯几何线条、端点平滑圆角、无渐变填充、杜绝一切 Emoji。
class HairlineIcon extends StatelessWidget {
  const HairlineIcon({
    super.key,
    required this.painterBuilder,
    this.size = 16,
    this.color,
    this.strokeWidth = 1.3,
  });

  final CustomPainter Function(Color color, double strokeWidth) painterBuilder;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: painterBuilder(effectiveColor, strokeWidth),
      ),
    );
  }
}

/// 集中暴露常用细线图标
abstract final class AppHairlineIcons {
  /// 配置调节滑钮 (用于 3D 翻转卡片配置触发周期)
  static Widget tune({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _TunePainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 细线叉号 (用于卡片个性化移除/关闭)
  static Widget cross({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _CrossPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 安全盾牌 (底线安全与红线)
  static Widget shield({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _ShieldPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 全局紧急警示钟/盾
  static Widget emergencyBell({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _EmergencyBellPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 卡内基周复盘四阶梯点线
  static Widget carnegie({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _CarnegiePainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 决策树分叉线
  static Widget tree({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _TreePainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 证据保险箱同心方圆
  static Widget vault({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _VaultPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 健康心率脉冲单折线
  static Widget pulse({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _PulsePainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 细线完成对勾
  static Widget check({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _CheckPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 细线撤销弧线箭头
  static Widget undo({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _UndoPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 细线信息提示 (i)
  static Widget info({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _InfoPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 细线分享 (外引箭头)
  static Widget share({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _SharePainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 精算微工具箱 (四格几何)
  static Widget calculator({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _CalcPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );

  /// 父母关爱大字模式 (双心环托)
  static Widget senior({Color? color, double size = 16, double strokeWidth = 1.3}) =>
      HairlineIcon(
        painterBuilder: (c, sw) => _SeniorPainter(c, sw),
        color: color,
        size: size,
        strokeWidth: strokeWidth,
      );
}

// ============================================================================
// 自绘画笔实现 (CustomPainters)
// ============================================================================

class _TunePainter extends CustomPainter {
  const _TunePainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 上横线与左滑块
    canvas.drawLine(Offset(w * 0.1, h * 0.32), Offset(w * 0.9, h * 0.32), p);
    canvas.drawCircle(Offset(w * 0.38, h * 0.32), w * 0.12, p..style = PaintingStyle.stroke);

    // 下横线与右滑块
    canvas.drawLine(Offset(w * 0.1, h * 0.68), Offset(w * 0.9, h * 0.68), p);
    canvas.drawCircle(Offset(w * 0.65, h * 0.68), w * 0.12, p..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _TunePainter old) => old.color != color || old.sw != sw;
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inset = size.width * 0.22;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      p,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.color != color || old.sw != sw;
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.85, h * 0.24)
      ..cubicTo(w * 0.85, h * 0.6, w * 0.65, h * 0.82, w * 0.5, h * 0.92)
      ..cubicTo(w * 0.35, h * 0.82, w * 0.15, h * 0.6, w * 0.15, h * 0.24)
      ..close();

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) => old.color != color || old.sw != sw;
}

class _EmergencyBellPainter extends CustomPainter {
  const _EmergencyBellPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 顶部小顶环
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.2), radius: w * 0.08),
      math.pi,
      math.pi,
      false,
      p,
    );

    // 钟体
    final bellPath = Path()
      ..moveTo(w * 0.25, h * 0.7)
      ..lineTo(w * 0.32, h * 0.38)
      ..cubicTo(w * 0.32, h * 0.2, w * 0.68, h * 0.2, w * 0.68, h * 0.38)
      ..lineTo(w * 0.75, h * 0.7)
      ..lineTo(w * 0.25, h * 0.7);
    canvas.drawPath(bellPath, p);

    // 底部小圆锤
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.72), radius: w * 0.1),
      0,
      math.pi,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _EmergencyBellPainter old) => old.color != color || old.sw != sw;
}

class _CarnegiePainter extends CustomPainter {
  const _CarnegiePainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 四阶梯阶跃折线
    final path = Path()
      ..moveTo(w * 0.15, h * 0.8)
      ..lineTo(w * 0.35, h * 0.8)
      ..lineTo(w * 0.35, h * 0.58)
      ..lineTo(w * 0.6, h * 0.58)
      ..lineTo(w * 0.6, h * 0.36)
      ..lineTo(w * 0.85, h * 0.36)
      ..lineTo(w * 0.85, h * 0.15);
    canvas.drawPath(path, p);

    // 右上角跃升关键点
    canvas.drawCircle(Offset(w * 0.85, h * 0.15), w * 0.07, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _CarnegiePainter old) => old.color != color || old.sw != sw;
}

class _TreePainter extends CustomPainter {
  const _TreePainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 主干向两边分叉
    canvas.drawLine(Offset(w * 0.5, h * 0.85), Offset(w * 0.5, h * 0.52), p);
    canvas.drawLine(Offset(w * 0.5, h * 0.52), Offset(w * 0.22, h * 0.26), p);
    canvas.drawLine(Offset(w * 0.5, h * 0.52), Offset(w * 0.78, h * 0.26), p);

    // 三端点小圆圈
    canvas.drawCircle(Offset(w * 0.5, h * 0.85), w * 0.08, p);
    canvas.drawCircle(Offset(w * 0.22, h * 0.26), w * 0.08, p);
    canvas.drawCircle(Offset(w * 0.78, h * 0.26), w * 0.08, p);
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) => old.color != color || old.sw != sw;
}

class _VaultPainter extends CustomPainter {
  const _VaultPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 圆角保险箱外框
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.15, w * 0.7, h * 0.7),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(rrect, p);

    // 中心旋钮圆与指针线
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.18, p);
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.62, h * 0.4), p);
  }

  @override
  bool shouldRepaint(covariant _VaultPainter old) => old.color != color || old.sw != sw;
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.1, h * 0.52)
      ..lineTo(w * 0.32, h * 0.52)
      ..lineTo(w * 0.44, h * 0.18)
      ..lineTo(w * 0.56, h * 0.82)
      ..lineTo(w * 0.68, h * 0.52)
      ..lineTo(w * 0.9, h * 0.52);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.color != color || old.sw != sw;
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.2, h * 0.52)
      ..lineTo(w * 0.44, h * 0.74)
      ..lineTo(w * 0.82, h * 0.26);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.color != color || old.sw != sw;
}

class _UndoPainter extends CustomPainter {
  const _UndoPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final arcRect = Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.6, h * 0.6);
    canvas.drawArc(arcRect, 0, -math.pi * 1.25, false, p);

    // 箭头尖端
    canvas.drawLine(Offset(w * 0.3, h * 0.2), Offset(w * 0.18, h * 0.32), p);
    canvas.drawLine(Offset(w * 0.3, h * 0.44), Offset(w * 0.18, h * 0.32), p);
  }

  @override
  bool shouldRepaint(covariant _UndoPainter old) => old.color != color || old.sw != sw;
}

class _InfoPainter extends CustomPainter {
  const _InfoPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.4, p);
    // 点与竖线
    canvas.drawCircle(Offset(w * 0.5, h * 0.32), w * 0.04, p..style = PaintingStyle.fill);
    canvas.drawLine(Offset(w * 0.5, h * 0.44), Offset(w * 0.5, h * 0.7), p..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _InfoPainter old) => old.color != color || old.sw != sw;
}

class _SharePainter extends CustomPainter {
  const _SharePainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // 底部半托盘
    final tray = Path()
      ..moveTo(w * 0.2, h * 0.45)
      ..lineTo(w * 0.2, h * 0.82)
      ..lineTo(w * 0.8, h * 0.82)
      ..lineTo(w * 0.8, h * 0.45);
    canvas.drawPath(tray, p);

    // 向上箭头
    canvas.drawLine(Offset(w * 0.5, h * 0.65), Offset(w * 0.5, h * 0.18), p);
    canvas.drawLine(Offset(w * 0.34, h * 0.34), Offset(w * 0.5, h * 0.18), p);
    canvas.drawLine(Offset(w * 0.66, h * 0.34), Offset(w * 0.5, h * 0.18), p);
  }

  @override
  bool shouldRepaint(covariant _SharePainter old) => old.color != color || old.sw != sw;
}

class _CalcPainter extends CustomPainter {
  const _CalcPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 外框
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.12, w * 0.7, h * 0.76),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(rrect, p);

    // 屏幕横线
    canvas.drawLine(Offset(w * 0.26, h * 0.32), Offset(w * 0.74, h * 0.32), p);

    // 四个微点按键
    final dots = [
      Offset(w * 0.35, h * 0.52),
      Offset(w * 0.65, h * 0.52),
      Offset(w * 0.35, h * 0.72),
      Offset(w * 0.65, h * 0.72),
    ];
    for (final d in dots) {
      canvas.drawCircle(d, w * 0.04, p..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _CalcPainter old) => old.color != color || old.sw != sw;
}

class _SeniorPainter extends CustomPainter {
  const _SeniorPainter(this.color, this.sw);
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 两个爱心圆弧守护
    canvas.drawCircle(Offset(w * 0.38, h * 0.38), w * 0.14, p);
    canvas.drawCircle(Offset(w * 0.62, h * 0.38), w * 0.14, p);

    // 托手弧线
    final tray = Path()
      ..moveTo(w * 0.18, h * 0.68)
      ..cubicTo(w * 0.35, h * 0.86, w * 0.65, h * 0.86, w * 0.82, h * 0.68);
    canvas.drawPath(tray, p);
  }

  @override
  bool shouldRepaint(covariant _SeniorPainter old) => old.color != color || old.sw != sw;
}
