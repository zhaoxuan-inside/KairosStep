import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 全屏礼花动效：自屏幕中上方迸发一簇调色板彩纸，重力坠落、旋转飘散，
/// 1.4 秒自然消散；纯 CustomPaint 实现，不引入第三方依赖。
///
/// 触点：完成建议打卡、卡内基落印完成。
class ConfettiBurst {
  ConfettiBurst._();

  /// 计算某组件中心点的全局坐标（用作礼花迸发原点）；不可用时返回 null。
  static Offset? originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    return null;
  }

  /// [origin] 为迸发原点（全局坐标）；null 时默认自屏幕中上方迸发。
  static void show(BuildContext context, {AppPalettes? palette, Offset? origin}) {
    final p = palette ?? AppPalettes.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _ConfettiPaint(
          palette: p,
          origin: origin,
          onComplete: () => entry.remove(),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

class _ConfettiPaint extends StatefulWidget {
  const _ConfettiPaint({
    required this.palette,
    required this.onComplete,
    this.origin,
  });

  final AppPalettes palette;
  final VoidCallback onComplete;
  final Offset? origin;

  @override
  State<_ConfettiPaint> createState() => _ConfettiPaintState();
}

class _ConfettiPaintState extends State<_ConfettiPaint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  List<_Particle> _particles = const [];
  late Size _screen;

  static const _totalSeconds = 1.4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // View.of 依赖 InheritedWidget，只能在 didChangeDependencies 中读取
    final view = View.of(context);
    _screen = Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );
    final rng = math.Random();
    final colors = [
      widget.palette.action,
      widget.palette.emerald,
      widget.palette.amber,
      widget.palette.rose,
      widget.palette.indigo,
    ];
    final origin =
        widget.origin ?? Offset(_screen.width * 0.5, _screen.height * 0.26);
    _particles = [
      for (var i = 0; i < 64; i++)
        _Particle(
          origin: origin,
          // 上抛扇形：竖直向上 ±55°，速度离散形成错落的抛物线
          velocity: Offset(
            math.sin((-math.pi / 2 + (rng.nextDouble() - 0.5) * 1.9)) *
                (320 + rng.nextDouble() * 400),
            math.cos((-math.pi / 2 + (rng.nextDouble() - 0.5) * 1.1)) *
                (420 + rng.nextDouble() * 420),
          ),
          color: colors[rng.nextInt(colors.length)],
          size: 4.5 + rng.nextDouble() * 4.5,
          rot0: rng.nextDouble() * math.pi * 2,
          spin: (rng.nextDouble() - 0.5) * 12,
          drag: 0.55 + rng.nextDouble() * 0.5,
        ),
    ];
    _ctl
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => CustomPaint(
        size: MediaQuery.sizeOf(context),
        painter: _ConfettiPainter(
          particles: _particles,
          t: _ctl.value * _totalSeconds,
          screen: _screen,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.origin,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rot0,
    required this.spin,
    required this.drag,
  });

  final Offset origin;
  final Offset velocity;
  final Color color;
  final double size;
  final double rot0;
  final double spin;
  final double drag;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.screen,
  });

  final List<_Particle> particles;
  final double t;
  final Size screen;

  @override
  void paint(Canvas canvas, Size size) {
    // 尾段整体淡出，避免彩纸悬空消失的突兀感
    final fade = t < _ConfettiPaintFade.start
        ? 1.0
        : 1.0 -
            (t - _ConfettiPaintFade.start) /
                (_ConfettiPaintFade.total - _ConfettiPaintFade.start);
    final paint = Paint()..color = Colors.white;
    for (final p in particles) {
      final dt = t;
      // 阻尼上抛 + 重力坠落：x 受空气阻力衰减，y 遵循抛物线
      final vx = p.velocity.dx * math.exp(-p.drag * dt);
      final x = p.origin.dx + vx * dt;
      final y = p.origin.dy +
          (p.velocity.dy * dt + 0.5 * 1250 * dt * dt) -
          p.drag * p.velocity.dy * 0.35 * dt;
      final rot = p.rot0 + p.spin * dt;

      paint.color = p.color.withValues(
        alpha: (fade.clamp(0.0, 1.0) * 0.95),
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      // 矩形纸片随旋转呈现宽窄变化，近似 3D 翻转
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * (0.35 + 0.65 * math.cos(rot * 1.7).abs()),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _ConfettiPaintFade {
  static const start = 1.0;
  static const total = 1.4;
}
