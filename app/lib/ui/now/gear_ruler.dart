import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 齿轮时间尺：24 小时横向刻度尺。
///
/// - 每格一小时，按小时与当下时段着色（晨/午/暮/夜）。
/// - 事件圆点 = 各时段 Hero 目标（安全带 / 血压 / 睡前离屏）。
/// - 拖动刻度 → 回调改写「当下」锚点；实时模式有呼吸指示灯。
class GearRuler extends StatelessWidget {
  const GearRuler({
    super.key,
    required this.now,
    required this.live,
    required this.onChanged,
  });

  final DateTime now;
  final bool live;
  final ValueChanged<DateTime> onChanged;

  static const _heroHours = {1: 1, 7: 7, 103: 23}; // heroId → 小时
  static const double cellWidth = 92;

  Color _hourColor(AppPalettes p, int hour) {
    if (hour >= 5 && hour < 9) return p.action;
    if (hour >= 9 && hour < 12) return p.indigo;
    if (hour >= 12 && hour < 18) return p.emerald;
    if (hour >= 18 && hour < 22) return p.amber;
    return p.rose;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final controller = ScrollController(
      initialScrollOffset: (now.hour + now.minute / 60) * cellWidth - 140,
    );

    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        children: [
          // 顶部状态条：时钟 + 实时呼吸灯
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Text(
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                if (live)
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
                  )
                else
                  Icon(Icons.touch_app_outlined, size: 13, color: p.amber),
                const Spacer(),
                Text(
                  live ? '实时同步中' : '预演模式',
                  style: TextStyle(fontSize: 10.5, color: live ? p.emerald : p.amber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 刻度尺主体
          Expanded(
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 48, // 两天，允许跨夜拖动
              itemExtent: cellWidth,
              itemBuilder: (context, i) {
                final hour = i % 24;
                final isNow = live && hour == now.hour;
                final c = _hourColor(p, hour);
                final hero = _heroHours.entries.where((e) => e.value == hour).toList();
                return GestureDetector(
                  onTap: () => onChanged(DateTime(now.year, now.month, now.day, hour)),
                  child: Container(
                    width: cellWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: p.hairline, width: 0.5),
                      ),
                      color: isNow ? c.withValues(alpha: 0.1) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isNow ? c : p.inkSub,
                              ),
                            ),
                            if (isNow) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.circle, size: 5, color: c),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 事件点：该小时的 Hero 行动
                        for (final h in hero)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration:
                                      BoxDecoration(shape: BoxShape.circle, color: c),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    switch (h.key) {
                                      1 => '出行 · 系安全带',
                                      7 => '血压 · 晨起监测',
                                      _ => '睡前 · 离屏静心',
                                    },
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 9.5, color: p.inkMute),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        // 小时刻度齿
                        Row(
                          children: [
                            for (var t = 0; t < 4; t++)
                              Expanded(
                                child: Container(
                                  height: t == 0 ? 8 : 4,
                                  margin: const EdgeInsets.only(right: 4),
                                  color: p.hairline,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
