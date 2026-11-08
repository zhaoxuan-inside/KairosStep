import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/sound.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../models/style.dart';
import '../../state/app_store.dart';
import '../widgets/confetti_burst.dart';
import 'spotlight_interactors.dart';
import 'task_interactors.dart';
import '../emergency/emergency_sheet.dart';

import 'package:url_launcher/url_launcher.dart';

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
      store.catalog.displayBindings
          .bindingOf(advice.id)
          ?.stringListParam('items') ??
      (advice.parts.isNotEmpty ? advice.parts : [advice.title]);

  bool get _durable =>
      store.catalog.displayBindings
              .bindingOf(advice.id)
              ?.params['completion'] ==
          'acknowledgement' ||
      const {
        'record',
        'deadline',
        'writing',
      }.contains(store.catalog.displayBindings.bindingOf(advice.id)?.override);
  T? extra<T>(String key) =>
      (_durable ? store.interactionData(advice.id)[key] : st.extra[key]) as T?;

  void setExtra(String key, Object? value) {
    if (_durable) {
      store.setInteractionValue(advice.id, key, value);
      return;
    }
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
    // 聚光专项分派数据化于 L5 display_bindings.json（override → 专属交互器）
    final catalog = storeOf(context).catalog;
    final binding = catalog.displayBindings.bindingOf(advice.id);
    switch (binding?.override) {
      case 'cabin-seats':
        return CabinSeatsInteractor(advice: advice, scope: scope);
      case 'blood-pressure':
        return BloodPressureInteractor(advice: advice, scope: scope);
      case 'wage-calc':
        return WageCalcInteractor(advice: advice, scope: scope);
      case 'record':
        return NumericRecordInteractor(advice: advice, scope: scope);
      case 'deadline':
        return DeadlineInteractor(advice: advice, scope: scope);
      case 'writing':
        return WrittenPlanInteractor(advice: advice, scope: scope);
    }

    return switch (binding?.style ?? advice.actType) {
      'haptic-toggle' => ToggleChipsInteractor(
        advice: advice,
        scope: scope,
        lockedCount: binding?.intParam('lockedCount', 0) ?? 0,
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
      'slider-calc' => NumericRecordInteractor(advice: advice, scope: scope),
      'wage-calc' => WageCalcInteractor(advice: advice, scope: scope),
      'zen-timer' => ZenTimerInteractor(advice: advice, scope: scope),
      _ => QuickCheckinInteractor(advice: advice, scope: scope),
    };
  }
}

List<String> interactionItems(BuildContext context, Advice advice) {
  final items = catalogOf(context).displayBindings
      .bindingOf(advice.id)
      ?.stringListParam('items');
  return items != null && items.isNotEmpty
      ? items
      : advice.parts.isNotEmpty
      ? advice.parts
      : [advice.title];
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

/// 动态部件列表（安全防线 chips / 办事分步 / 红线规则 / 守护名单 / 占位格）
/// 的统一完成度口径：已确认部件 / 全部部件——与普通建议的 isDone 判定一致，
/// 驱动今日流「完成后沉底」排序，排序不再区分建议类型。
double _dynamicRatio(List<String> parts, String toggled, CardCtl ctl) {
  if (parts.isEmpty) return 0;
  final on = parts.where((x) => x == toggled ? !ctl.has(x) : ctl.has(x)).length;
  return on / parts.length;
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
          child: TweenAnimationBuilder<double>(
            // 打卡状态翻转时内容做一次弹性 pop（on: 自 0.8 放大 / off: 自 1.15 收敛）
            key: ValueKey(on),
            tween: Tween(begin: on ? 0.8 : 1.15, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
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
        for (final part in interactionItems(context, advice))
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
          : catalogOf(context).displayBindings
                        .bindingOf(advice.id)
                        ?.params['actionLabel']
                    as String? ??
                (advice.coreAction.length > 14
                    ? '完成此项'
                    : '完成：${advice.coreAction}'),
      on: done,
      icon: done ? Icons.task_alt : Icons.check,
      onTap: () {
        final store = storeOf(context);
        if (done) {
          ctl.setRatio(0);
          store.updateCard(scope, advice.id, (s) => s.doneParts.clear());
          _syncTodoDone(store, done: false);
        } else {
          ctl.mark('__checkin__', true, ratio: 1);
          _syncTodoDone(store, done: true);
          // 完成建议：上行双音 + 自被打卡卡片位置迸发礼花
          SoundFx.play(Sfx.success);
          ConfettiBurst.show(context, origin: ConfettiBurst.originOf(context));
        }
      },
    );
  }

  /// 自建待办卡的完成态与 UserTodoItem.isDone 保持一致
  /// （独立专区已移除，勾选走普通建议卡打卡路径，持久化数据仍需对齐）。
  void _syncTodoDone(AppStore store, {required bool done}) {
    if (advice.chapter != '我的自建待办') return;
    final todoId = store.todoIdBySyntheticAdvice(advice.id);
    if (todoId == null) return;
    for (final t in store.userTodos) {
      if (t.id == todoId) {
        if (t.isDone != done) store.toggleUserTodo(todoId);
        return;
      }
    }
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
    final stamped = ctl.extra<bool>('readAcknowledged') ?? ctl.has('stamp');

    void toggle() {
      ctl.setExtra('readAcknowledged', !stamped);
      ctl.mark('stamp', !stamped, ratio: 0);
      setState(() {});
      if (!stamped) _pop.forward(from: 0);
    }

    return InkWell(
      onTap: toggle,
      child: Row(
        children: [
          GestureDetector(
            onTap: toggle,
            child: ScaleTransition(
              scale: Tween(begin: 0.72, end: 1.0).animate(
                CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
              ),
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
                  stamped ? '已标记阅读 · 点击撤销' : '标记已阅读',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: stamped ? p.rose : p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '阅读标记仅保存在本机，不代表已掌握或风险已解除',
                  style: TextStyle(fontSize: 10.5, color: p.inkMute),
                ),
              ],
            ),
          ),
        ],
      ),
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

  /// 闹钟预设数据化于 L2 act_styles.json（daily-streak.params.alarmPresets，
  /// 与原关键词 if 链同序、首个命中即止；fallback 兜底）。
  (String, String) _alarmPreset(ActStyleDef? style) {
    final t = advice.title;
    final presets = ((style?.params['alarmPresets'] as List?) ?? const [])
        .map((e) => AlarmPreset.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final preset in presets) {
      if (preset.matches(t)) return (preset.alarmName, preset.defaultTime);
    }
    return ('每日提醒', '08:30');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final ctl = CardCtl(store, scope, advice);
    final (alarmName, defaultTime) = _alarmPreset(
      store.catalog.actStyles.style('daily-streak'),
    );
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
              options: _AlarmPicker.optionsOf(
                store.catalog.actStyles.style('daily-streak'),
              ),
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
              // 完成建议：上行双音 + 自被打卡卡片位置迸发礼花
              SoundFx.play(Sfx.success);
              ConfettiBurst.show(
                context,
                origin: ConfettiBurst.originOf(context),
              );
            }
          },
        ),
      ],
    );
  }
}

class _AlarmPicker extends StatelessWidget {
  const _AlarmPicker({
    required this.selected,
    required this.options,
    required this.onPick,
  });

  final String selected;
  final List<String> options;
  final ValueChanged<String> onPick;

  /// 快捷时刻选项来自 L2 act_styles.json（daily-streak.params.quickOptions）
  static List<String> optionsOf(ActStyleDef? style) =>
      ((style?.params['quickOptions'] as List?) ?? const []).cast<String>();

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
  @override
  Widget build(BuildContext context) =>
      DeadlineInteractor(advice: advice, scope: scope);
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
    final steps = interactionItems(context, advice);

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
                ctl.mark(
                  steps[i],
                  !ctl.has(steps[i]),
                  ratio: _dynamicRatio(steps, steps[i], ctl),
                );
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
                '已核对当前全部步骤',
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
    final rules = interactionItems(context, advice);

    return Column(
      children: [
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                ctl.mark(
                  rule,
                  !ctl.has(rule),
                  ratio: _dynamicRatio(rules, rule, ctl),
                );
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
                '逐条核对相关条件 · 勾选不代表决策结果正确',
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
    final guards = interactionItems(context, advice);
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
                allOn ? '已核对 · 仍需遵守上述限制' : '请先核对适用情境与限制',
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
                  ctl.mark(g, !ctl.has(g), ratio: 0);
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
    final phones = RegExp(r'(?<![0-9])(?:110|119|120)(?![0-9])')
        .allMatches(advice.title)
        .map((m) => m.group(0)!)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final text in interactionItems(context, advice))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final phone in phones)
              FilledButton.icon(
                icon: const Icon(Icons.phone),
                label: Text('拨打 $phone'),
                onPressed: () async {
                  final opened = await launchUrl(
                    Uri(scheme: 'tel', path: phone),
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('未能打开拨号界面，请使用系统电话拨打 $phone')),
                    );
                  }
                },
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.emergency_outlined),
              label: const Text('打开紧急求助'),
              onPressed: () => EmergencySheet.show(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('此卡提供求助入口与指引，不将点击按钮记为已经脱险或处理完成。'),
      ],
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
    final slots = interactionItems(context, advice);

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
              ctl.mark(
                slot,
                !ctl.has(slot),
                ratio: _dynamicRatio(slots, slot, ctl),
              );
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
  Widget build(BuildContext context) =>
      NumericRecordInteractor(advice: advice, scope: scope);
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
