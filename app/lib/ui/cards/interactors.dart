import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import 'spotlight_interactors.dart';
import '../now/breathing_practice.dart';

/// 卡片交互控制器：交互器与持久化状态的唯一通道。
class CardCtl {
  CardCtl(this.store, this.scope, this.advice);

  final AppStore store;
  final PeriodScope scope;
  final Advice advice;

  CardState get st => store.cardState(scope, advice.id);

  bool has(String part) => st.doneParts.contains(part);

  void mark(String part, bool on, {double? ratio}) {
    store.updateCard(scope, advice.id, (s) {
      on ? s.doneParts.add(part) : s.doneParts.remove(part);
      if (ratio != null) {
        s.completionRatio = ratio;
      } else if (targetParts.isNotEmpty) {
        s.completionRatio =
            targetParts.where(s.doneParts.contains).length / targetParts.length;
      }
    });
  }

  /// 该卡的目标部件（默认 parts；特殊卡可覆写）。
  List<String> get targetParts =>
      advice.parts.isNotEmpty ? advice.parts : [advice.title];

  T? extra<T>(String key) => st.extra[key] as T?;

  void setExtra(String key, Object? value) {
    store.updateCard(scope, advice.id, (s) => s.extra[key] = value);
  }

  void setRatio(double v) =>
      store.updateCard(scope, advice.id, (s) => s.completionRatio = v);

  void checkinStreak() {
    store.checkinStreak(advice.id, DateTime.now());
    mark('__checkin__', true, ratio: 1);
  }

  StreakState get streak => store.streakOf(advice.id);
}

/// 交互器分派中枢：13 种 act_type + 聚光专项。
class AdviceInteractor extends StatelessWidget {
  const AdviceInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    // 聚光专项：安全带四座舱 / 血压计 / 家务时薪
    switch (advice.id) {
      case 1:
        return CabinSeatsInteractor(advice: advice, scope: scope);
      case 7:
        return BloodPressureInteractor(advice: advice, scope: scope);
      case 136:
        return WageCalcInteractor(advice: advice, scope: scope);
    }

    return switch (advice.actType) {
      'haptic-toggle' => ToggleChipsInteractor(
        advice: advice,
        scope: scope,
        lockedCount: advice.id == 1 ? 2 : 0,
      ),
      'quick-checkin' => QuickCheckinInteractor(advice: advice, scope: scope),
      'daily-streak' => DailyStreakInteractor(advice: advice, scope: scope),
      'windowed-cadence' => WindowCadenceInteractor(
        advice: advice,
        scope: scope,
      ),
      'redline-stamp' => RedlineStampInteractor(advice: advice, scope: scope),
      'process-steps' => ProcessStepsInteractor(advice: advice, scope: scope),
      'decision-check' => DecisionCheckInteractor(advice: advice, scope: scope),
      'context-guard' => ContextGuardInteractor(advice: advice, scope: scope),
      'emergency-action' => EmergencyActionInteractor(
        advice: advice,
        scope: scope,
      ),
      'evidence-checklist' => EvidenceChecklistInteractor(
        advice: advice,
        scope: scope,
      ),
      'slider-calc' => SliderCalcInteractor(advice: advice, scope: scope),
      'wage-calc' => WageCalcInteractor(advice: advice, scope: scope),
      'zen-timer' => ZenTimerInteractor(advice: advice, scope: scope),
      _ => QuickCheckinInteractor(advice: advice, scope: scope),
    };
  }
}

// ============================================================
// 基础部件
// ============================================================

class ActionChip extends StatelessWidget {
  const ActionChip({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.icon,
    this.accent,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final c = accent ?? p.action;
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.16) : p.pillBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: on ? c.withValues(alpha: 0.6) : p.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check : (icon ?? Icons.radio_button_unchecked),
              size: 13,
              color: on ? c : p.inkMute,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? c : p.inkSub,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主行动按钮（打卡 / 铭记 / 确认）。
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.color,
    this.icon = Icons.check,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final c = color ?? p.emerald;
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          decoration: BoxDecoration(
            color: on ? c : c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: on ? c : c.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: on ? Colors.white : c),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 1. 触感卡扣 / 通用芯片组
// ============================================================

class ToggleChipsInteractor extends StatelessWidget {
  const ToggleChipsInteractor({
    super.key,
    required this.advice,
    required this.scope,
    this.lockedCount = 0,
  });

  final Advice advice;
  final PeriodScope scope;
  final int lockedCount;

  @override
  Widget build(BuildContext context) {
    final ctl = CardCtl(storeOf(context), scope, advice);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final part in advice.parts)
          ActionChip(
            label: part,
            on: ctl.has(part),
            onTap: () => ctl.mark(part, !ctl.has(part)),
          ),
      ],
    );
  }
}

// ============================================================
// 2. 行动打卡
// ============================================================

class QuickCheckinInteractor extends StatelessWidget {
  const QuickCheckinInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final ctl = CardCtl(storeOf(context), scope, advice);
    final done = ctl.st.isDone;
    return PrimaryAction(
      label: done
          ? '已完成 · 点击撤销'
          : advice.coreAction.length > 14
          ? '完成此项'
          : '完成：${advice.coreAction}',
      on: done,
      icon: done ? Icons.task_alt : Icons.check,
      onTap: () {
        if (done) {
          ctl.setRatio(0);
          storeOf(context)
              .updateCard(scope, advice.id, (s) => s.doneParts.clear());
        } else {
          ctl.mark('__checkin__', true, ratio: 1);
        }
      },
    );
  }
}

// ============================================================
// 3. 红线铭记：盖章
// ============================================================

class RedlineStampInteractor extends StatefulWidget {
  const RedlineStampInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  State<RedlineStampInteractor> createState() => _RedlineStampInteractorState();
}

class _RedlineStampInteractorState extends State<RedlineStampInteractor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final ctl = CardCtl(store, widget.scope, widget.advice);
    final stamped = ctl.has('stamp');

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            ctl.mark('stamp', !stamped, ratio: stamped ? 0 : 1);
            if (!stamped) _pop.forward(from: 0);
          },
          child: ScaleTransition(
            scale: Tween(
              begin: 0.72,
              end: 1.0,
            ).animate(CurvedAnimation(parent: _pop, curve: Curves.elasticOut)),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stamped ? p.rose : p.rose.withValues(alpha: 0.1),
                border: Border.all(
                  color: stamped ? p.rose : p.rose.withValues(alpha: 0.5),
                  width: stamped ? 2.2 : 1.4,
                ),
              ),
              child: Icon(
                stamped ? Icons.verified_user : Icons.gpp_maybe_outlined,
                size: 22,
                color: stamped ? Colors.white : p.rose,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stamped ? '已铭记红线 · 背熟即防' : '点击盖章铭记',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: stamped ? p.rose : p.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stamped ? '命中场景时会直接弹出速查卡' : '高频高后果内容 · 盖章后进入长期记忆',
                style: TextStyle(fontSize: 10.5, color: p.inkMute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 4. 每日连击
// ============================================================

class DailyStreakInteractor extends StatelessWidget {
  const DailyStreakInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  (String, String) _alarmPreset() {
    final t = advice.title;
    if (t.contains('起床')) return ('晨间闹钟', '07:00');
    if (t.contains('午睡') || t.contains('午休') || t.contains('小憩')) {
      return ('午休提醒', '12:45');
    }
    if (t.contains('睡前一小时') || (t.contains('屏幕') && t.contains('睡'))) {
      return ('离屏打卡', '21:30');
    }
    if (t.contains('睡')) return ('睡前提醒', '23:00');
    if (t.contains('刷牙') || t.contains('牙缝')) return ('早晚洗漱', '07:30 / 22:30');
    if (t.contains('步') || t.contains('力量') || t.contains('运动')) {
      return ('日间活力', '10:00 / 16:00');
    }
    if (t.contains('血压') || t.contains('吃药')) return ('慢病监测', '每日晨起定点');
    if (t.contains('戒烟')) return ('无烟生活', '全天守护');
    return ('每日提醒', '08:30');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final (alarmName, defaultTime) = _alarmPreset();
    final pickedTime = ctl.extra<String?>('alarm') ?? defaultTime;
    final streak = ctl.streak;
    final checkedToday = ctl.has('__checkin__');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 提醒时刻胶囊
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 13,
              color: p.action,
            ),
            const SizedBox(width: 5),
            Text(
              '$alarmName $pickedTime',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const Spacer(),
            _AlarmPicker(
              selected: pickedTime,
              onPick: (t) {
                HapticFeedback.selectionClick();
                ctl.setExtra('alarm', t);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 连击点阵：最近 14 天
        Row(
          children: [
            for (var i = 0; i < 14; i++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 13 ? 0 : 3),
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        i < (streak.days % 15) ||
                            (checkedToday && i == streak.days % 15)
                        ? p.emerald
                        : p.pillBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '连击 ${streak.days} 天',
              style: TextStyle(
                fontSize: 10.5,
                color: p.emerald,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PrimaryAction(
          label: checkedToday ? '今日已打卡 · ${streak.days} 连击' : '今日打卡',
          on: checkedToday,
          icon: checkedToday ? Icons.local_fire_department : Icons.check,
          color: p.emerald,
          onTap: () {
            if (checkedToday) {
              ctl.setRatio(0);
              storeOf(context)
                  .updateCard(scope, advice.id, (s) => s.doneParts.clear());
            } else {
              ctl.checkinStreak();
            }
          },
        ),
      ],
    );
  }
}

class _AlarmPicker extends StatelessWidget {
  const _AlarmPicker({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  static const options = ['06:30 晨光', '07:00 标准', '07:30 宽裕', '23:00 就寝'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () async {
        final t = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '快速切换每日提醒时刻',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final o in options)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      o.startsWith(selected)
                          ? Icons.check_circle
                          : Icons.schedule,
                      size: 18,
                      color: o.startsWith(selected) ? p.action : p.inkMute,
                    ),
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    onTap: () => Navigator.pop(context, o.split(' ').first),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (t != null) onPick(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: p.action.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '调时点',
              style: TextStyle(
                fontSize: 10.5,
                color: p.action,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.chevron_right, size: 13, color: p.inkMute),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 5. 持续窗口期
// ============================================================

class WindowCadenceInteractor extends StatelessWidget {
  const WindowCadenceInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  static const windowDays = 14;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final ctl = CardCtl(store, scope, advice);
    final anchor = store.ensureWindowAnchor(advice.id, DateTime.now());
    final elapsed = DateTime.now().difference(anchor).inDays + 1;
    final day = elapsed.clamp(1, windowDays);
    final chips = advice.caveats.isNotEmpty ? advice.caveats : ['完成主行动'];
    final chipsOn = chips.where(ctl.has).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '窗口期进行中：第 $day/$windowDays 天',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: day >= windowDays - 2 ? p.rose : p.amber,
              ),
            ),
            const Spacer(),
            Text(
              '剩余 ${windowDays - day} 天',
              style: TextStyle(fontSize: 10.5, color: p.inkMute),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: day / windowDays,
            minHeight: 5,
            backgroundColor: p.pillBg,
            valueColor: AlwaysStoppedAnimation(
              day >= windowDays - 2 ? p.rose : p.amber,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '安全防线 $chipsOn/${chips.length}',
              style: TextStyle(
                fontSize: 10.5,
                color: p.inkSub,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              chipsOn == chips.length ? '全部确认 · 提醒解除' : '逐条确认防线',
              style: TextStyle(
                fontSize: 10,
                color: chipsOn == chips.length ? p.emerald : p.inkMute,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in chips)
              ActionChip(
                label: chip,
                on: ctl.has(chip),
                accent: p.amber,
                icon: Icons.shield_outlined,
                onTap: () {
                  ctl.mark(chip, !ctl.has(chip));
                  if (chips.every(ctl.has)) {
                    HapticFeedback.heavyImpact();
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// 6. 办事分步
// ============================================================

class ProcessStepsInteractor extends StatelessWidget {
  const ProcessStepsInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final steps = advice.parts;

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
            child: _StepRow(
              index: i + 1,
              label: steps[i],
              on: ctl.has(steps[i]),
              onTap: () {
                HapticFeedback.selectionClick();
                ctl.mark(steps[i], !ctl.has(steps[i]));
              },
            ),
          ),
        if (steps.where(ctl.has).length == steps.length) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, size: 13, color: p.indigo),
              const SizedBox(width: 4),
              Text(
                '全部步骤完成，行动已闭环',
                style: TextStyle(
                  fontSize: 10.5,
                  color: p.indigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: on ? p.indigo.withValues(alpha: 0.08) : p.pillBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? p.indigo : Colors.transparent,
                border: Border.all(
                  color: on ? p.indigo : p.inkMute,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: on
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 10,
                          color: p.inkMute,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: on ? p.indigo : p.ink,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  decoration: on ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 7. 决策核对
// ============================================================

class DecisionCheckInteractor extends StatelessWidget {
  const DecisionCheckInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final rules = advice.parts;

    return Column(
      children: [
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                ctl.mark(rule, !ctl.has(rule));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ctl.has(rule)
                      ? p.indigo.withValues(alpha: 0.08)
                      : p.pillBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ctl.has(rule)
                        ? p.indigo.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ctl.has(rule) ? Icons.rule : Icons.rule_folder_outlined,
                      size: 15,
                      color: ctl.has(rule) ? p.indigo : p.inkMute,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: ctl.has(rule) ? p.ink : p.inkSub,
                          fontWeight: ctl.has(rule)
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 12, color: p.inkMute),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '决策场景触发时逐条核对 · 全勾即闭环',
                style: TextStyle(fontSize: 10, color: p.inkMute),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// 8. 情境拦截
// ============================================================

class ContextGuardInteractor extends StatelessWidget {
  const ContextGuardInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final guards = advice.parts;
    final allOn = guards.every(ctl.has);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: allOn
                ? p.emerald.withValues(alpha: 0.1)
                : p.rose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                allOn ? Icons.verified_user : Icons.gpp_bad_outlined,
                size: 14,
                color: allOn ? p.emerald : p.rose,
              ),
              const SizedBox(width: 6),
              Text(
                allOn ? '情境已确认 · 拦截解除' : '情境命中 · 先确认再行动',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: allOn ? p.emerald : p.rose,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in guards)
              ActionChip(
                label: g,
                on: ctl.has(g),
                accent: p.rose,
                icon: Icons.front_hand_outlined,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ctl.mark(g, !ctl.has(g));
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// 9. 紧急直达
// ============================================================

class EmergencyActionInteractor extends StatelessWidget {
  const EmergencyActionInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _EmergencyBtn(
                icon: Icons.phone_in_talk,
                label: '求助热线',
                color: p.rose,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('示例数据 · 热线拨打需真机权限')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EmergencyBtn(
                icon: Icons.stop_circle_outlined,
                label: '立即止付',
                color: p.amber,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  ctl.mark('止付', true, ratio: 1);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EmergencyBtn(
                icon: Icons.shield_outlined,
                label: '保存证据',
                color: p.action,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ctl.mark('证据', true, ratio: 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrimaryAction(
          label: ctl.st.isDone ? '紧急动作已执行 · 点击复位' : '已按指引处理完毕',
          on: ctl.st.isDone,
          color: p.rose,
          icon: Icons.emergency,
          onTap: () {
            if (ctl.st.isDone) {
              ctl.setRatio(0);
              storeOf(context)
                  .updateCard(scope, advice.id, (s) => s.doneParts.clear());
            } else {
              ctl.mark('处理完毕', true, ratio: 1);
            }
          },
        ),
      ],
    );
  }
}

class _EmergencyBtn extends StatelessWidget {
  const _EmergencyBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 10. 证据清单（文件保险箱插槽）
// ============================================================

class EvidenceChecklistInteractor extends StatelessWidget {
  const EvidenceChecklistInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final slots = advice.parts.length >= 4
        ? advice.parts.take(4).toList()
        : [...advice.parts, '其他关键凭证', '备份位置索引'].take(4).toList();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: [
        for (final slot in slots)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.mediumImpact();
              ctl.mark(slot, !ctl.has(slot));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: ctl.has(slot)
                    ? p.emerald.withValues(alpha: 0.1)
                    : p.pillBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ctl.has(slot)
                      ? p.emerald.withValues(alpha: 0.5)
                      : p.hairline,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    ctl.has(slot)
                        ? Icons.inventory
                        : Icons.inventory_2_outlined,
                    size: 16,
                    color: ctl.has(slot) ? p.emerald : p.inkMute,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slot,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: ctl.has(slot) ? p.emerald : p.inkSub,
                        fontWeight: ctl.has(slot)
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// 11. 测算滑块（通用 + 关键词特化）
// ============================================================

class SliderCalcInteractor extends StatelessWidget {
  const SliderCalcInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final t = advice.title;

    // 关键词特化：酒精代谢 / 日晒 / 遛狗 / 其他通用
    final (label, unit, max, fmt) = t.contains('酒')
        ? ('已饮', '标准杯', 10, (double v) => '约 ${_alcoholHours(v)} 小时代谢完毕')
        : t.contains('晒') || t.contains('太阳')
        ? (
            '日晒',
            '分钟',
            60,
            (double v) => v >= 15 && v <= 30
                ? '15-30 分钟 · 合成维 D 足量'
                : v < 15
                ? '偏短 · 维 D 合成不足'
                : '偏长 · 注意晒伤风险',
          )
        : t.contains('遛狗')
        ? (
            '遛狗',
            '分钟',
            120,
            (double v) => v >= 30 ? '达标 · 中等强度活动计入' : '偏短 · 建议 30 分钟起',
          )
        : ('强度', '档位', 10, (double v) => '当前 ${v.round()} 档');
    final value = ctl.extra<double>('slider') ?? (max * 0.3);
    final readout = fmt(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: value,
                  max: max.toDouble(),
                  divisions: max.toInt() * 2,
                  activeColor: p.action,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    ctl.setExtra('slider', v);
                    ctl.setRatio((v / max).clamp(0.0, 1.0) * 0.4);
                  },
                  onChangeEnd: (_) => ctl.setRatio(0.4),
                ),
              ),
            ),
            Text(
              '${value.round()} $unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.action,
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: p.pillBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(readout, style: TextStyle(fontSize: 11, color: p.inkSub)),
        ),
        const SizedBox(height: 8),
        PrimaryAction(
          label: ctl.has('applied') ? '已记录本次测算' : '记录本次测算',
          on: ctl.has('applied'),
          color: p.action,
          icon: Icons.calculate_outlined,
          onTap: () => ctl.mark(
            'applied',
            !ctl.has('applied'),
            ratio: ctl.has('applied') ? 0.4 : 1,
          ),
        ),
      ],
    );
  }

  static int _alcoholHours(double cups) => (cups * 1.5).ceil().clamp(1, 15);
}

// ============================================================
// 12. 计时屏息
// ============================================================

class ZenTimerInteractor extends StatelessWidget {
  const ZenTimerInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) => const BreathingPractice();
}
