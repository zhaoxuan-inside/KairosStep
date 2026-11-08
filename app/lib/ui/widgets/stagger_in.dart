import 'package:flutter/material.dart';

/// 入场动效：淡入 + 自下 12px 滑入，让内容「浮现」而非瞬间铺开。
///
/// 用于页卡、弹层分节的首次出现；[delay] 与同类元素配合可做轻微级联
/// （建议步长 40~60ms，总长不超过 300ms，避免拖沓）。
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    const base = Duration(milliseconds: 320);
    final total = base + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      // 用区间曲线实现延迟启动：前 delay 段保持不可见，之后 easeOutCubic 浮现
      curve: Interval(
        total.inMilliseconds > 0 ? delay.inMilliseconds / total.inMilliseconds : 0,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, offset * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
