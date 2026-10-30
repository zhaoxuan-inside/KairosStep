import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';
import '../cards/advice_card.dart';
import 'breathing_practice.dart';
import 'gear_ruler.dart';

/// 当下页：前后 45 分钟时间尺（置顶） + 时段问候 + 当下焦点卡。
///
/// 时段划分与 Demo getPeriodInfo 一致：晨 05:00-09:30 / 上午 09:30-12:00 /
/// 午后 12:00-18:00 / 傍晚 18:00-22:00 / 夜间 22:00-05:00。
class NowPeriod {
  const NowPeriod(this.key, this.tag, this.greeting, this.sub);

  final String key;
  final String tag;
  final String greeting;
  final String sub;

  static NowPeriod of(DateTime now) {
    final m = now.hour * 60 + now.minute;
    if (m >= 300 && m < 570) {
      return const NowPeriod(
        'morning',
        '早晨 · 05:00-09:30',
        '早晨好，我已为你备好今日出发动作',
        '正在为你守护晨间出行安全与身体唤醒',
      );
    }
    if (m >= 570 && m < 720) {
      return const NowPeriod(
        'focus',
        '上午 · 09:30-12:00',
        '上午好，专注当下，保持高效节奏',
        '工位健康自检与深度工作守护中',
      );
    }
    if (m >= 720 && m < 1080) {
      return const NowPeriod(
        'afternoon',
        '午后 · 12:00-18:00',
        '午后好，久坐别忘舒展身心与远眺',
        '午后健康微防线持续守护中',
      );
    }
    if (m >= 1080 && m < 1320) {
      return const NowPeriod(
        'evening',
        '傍晚 · 18:00-22:00',
        '傍晚好，卸下疲惫，留存一日平和生活',
        '晚间归途与家庭安全守护中',
      );
    }
    return const NowPeriod(
      'night',
      '夜深 · 22:00-05:00',
      '夜深了，放下发光屏幕，让身心安稳入眠',
      '褪黑素节律守护中 · 远离发光屏幕',
    );
  }
}

class NowView extends StatefulWidget {
  const NowView({super.key});

  @override
  State<NowView> createState() => _NowViewState();
}

class _NowViewState extends State<NowView> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  /// 时间尺可拖动改写「当下」锚点；null = 跟随真实时钟。
  DateTime? _scrub;
  int _heroOffset = 0;

  DateTime get effectiveNow => _scrub ?? _now;

  @override
  void initState() {
    super.initState();
    // 每秒驱动实时呼吸与时钟更新
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _scrub != null) return;
      final now = DateTime.now();
      final periodChanged = NowPeriod.of(now).key != NowPeriod.of(_now).key;
      setState(() {
        _now = now;
        if (periodChanged) _heroOffset = 0;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final period = NowPeriod.of(effectiveNow);
    final periodAdvices = store.advicesForWindow(effectiveNow);

    final hero = periodAdvices.isNotEmpty
        ? periodAdvices[_heroOffset % periodAdvices.length]
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        // 1. 时段徽标 + 预演模式快速回到此刻
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: p.action.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  period.tag,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: p.action,
                  ),
                ),
              ),
              const Spacer(),
              if (_scrub != null)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _scrub = null;
                      _heroOffset = 0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: p.emerald.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: p.emerald.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location, size: 11, color: p.emerald),
                        const SizedBox(width: 4),
                        Text(
                          '回到此刻',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. 拟人化时段问候与守护提示语（如 "夜深了，放下发光屏幕..."）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.greeting,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      period.sub,
                      style: TextStyle(fontSize: 12, color: p.inkSub),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      store.probeScheduler.triggerManualOnDemandProbe(
                        effectiveNow,
                      );
                    },
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: p.action.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: p.action.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 11, color: p.action),
                          const SizedBox(width: 4),
                          Text(
                            '探查校准',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.action,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: BreathingPractice(),
        ),
        const SizedBox(height: 16),

        // 3. 齿轮时间尺（全宽贯通屏幕视口，两端高斯模糊与渐隐平滑溶入屏幕边缘）
        GearRuler(
          now: effectiveNow,
          live: _scrub == null,
          onChanged: (dt) => setState(() {
            _scrub = dt;
            _heroOffset = 0;
          }),
          onReset: _scrub == null
              ? null
              : () => setState(() {
                  _scrub = null;
                  _heroOffset = 0;
                }),
        ),
        const SizedBox(height: 20),

        // 4. 当下 Hero 卡标题与换一换切换
        if (periodAdvices.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '前后 45 分钟 · 第 ${(_heroOffset % periodAdvices.length) + 1} / ${periodAdvices.length} 项',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.inkMute,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _heroOffset++);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 12, color: p.action),
                      const SizedBox(width: 3),
                      Text(
                        '换一换',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.action,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 5. 当下 Hero 核心行动卡
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: hero != null
              ? AdviceCard(advice: hero, scope: PeriodScope.today)
              : Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.schedule_outlined, size: 28, color: p.inkMute),
                      const SizedBox(height: 10),
                      Text(
                        '前后 45 分钟暂无定时行动',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: p.inkSub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '可滑动时间尺查看其他时刻；未定时的建议仍可在「今天」查看',
                        style: TextStyle(fontSize: 11.5, color: p.inkMute),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        ),

        // 同一视窗内的候选仍可切换查看。候选已经由精确触发时刻筛选，
        // 不再由“早上/午后”等宽泛分组直接推入。
        if (periodAdvices.length > 1) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.checklist_rtl_outlined, size: 14, color: p.action),
                const SizedBox(width: 6),
                Text(
                  '前后 45 分钟内的其他行动（${periodAdvices.length - 1}）',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < periodAdvices.length; i++)
            if (i != (_heroOffset % periodAdvices.length))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: AdviceCard(
                  advice: periodAdvices[i],
                  scope: PeriodScope.today,
                  compact: true,
                ),
              ),
        ],
      ],
    );
  }
}
