import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';
import '../cards/advice_card.dart';
import 'gear_ruler.dart';

/// 当下页：1.5小时齿轮时间尺（置顶） + 时段问候 + 当下 Hero 卡。
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
      return const NowPeriod('morning', '早晨 · 晨光正好，从容出发',
          '早晨好，我已为你备好今日出发动作', '正在为你守护晨间出行安全与身体唤醒');
    }
    if (m >= 570 && m < 720) {
      return const NowPeriod('focus', '上午 · 专注当下，保持节奏',
          '上午好，专注当下，保持高效节奏', '工位健康自检与深度工作守护中');
    }
    if (m >= 720 && m < 1080) {
      return const NowPeriod('afternoon', '午后 · 久坐远眺，舒展身心',
          '午后好，久坐别忘舒展身心与远眺', '午后健康微防线持续守护中');
    }
    if (m >= 1080 && m < 1320) {
      return const NowPeriod('evening', '傍晚 · 归途与晚间',
          '傍晚好，卸下疲惫，留存一日平和生活', '晚间归途与家庭安全守护中');
    }
    return const NowPeriod('night', '夜深了 · 放下屏幕，安稳入眠',
        '夜深了，放下发光屏幕，让身心安稳入眠', '褪黑素节律守护中 · 远离发光屏幕');
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
    final periodAdvices = store.periodAdvicesOf(period.key);

    final hero = periodAdvices.isNotEmpty
        ? periodAdvices[_heroOffset % periodAdvices.length]
        : (store.todayAdvices.isNotEmpty ? store.todayAdvices.first : null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
      children: [
        // 1. 齿轮时间尺（放在最上面，时间范围 1.5 小时聚焦视窗）
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
        const SizedBox(height: 16),

        // 2. 时段徽标
        Row(
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
          ],
        ),
        const SizedBox(height: 12),

        // 3. 拟人化时段问候与守护提示
        Text(
          period.greeting,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(period.sub, style: TextStyle(fontSize: 12, color: p.inkSub)),
        const SizedBox(height: 18),

        // 4. 当下 Hero 卡标题与换一换切换
        if (periodAdvices.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '时段核心行动 · 第 ${(_heroOffset % periodAdvices.length) + 1} / ${periodAdvices.length} 项',
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
        if (hero != null)
          AdviceCard(advice: hero, scope: PeriodScope.today),

        // 6. 当前时段其他待命建议
        if (periodAdvices.length > 1) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.checklist_rtl_outlined, size: 14, color: p.action),
              const SizedBox(width: 6),
              Text(
                '此刻待命其他实证行动（${periodAdvices.length - 1}）',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < periodAdvices.length; i++)
            if (i != (_heroOffset % periodAdvices.length))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
