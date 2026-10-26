import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import 'interactors.dart';

/// 聚光专项 1 —— 建议 1「系安全带」：四座拟物车舱。
///
/// 主驾/副驾预锁，后排两座点击扣紧；四座全锁 → 卡片闭环。
class CabinSeatsInteractor extends StatelessWidget {
  const CabinSeatsInteractor({super.key, required this.advice, required this.scope});

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final rearL = ctl.has('后排左');
    final rearR = ctl.has('后排右');
    final allLocked = rearL && rearR;

    // 完成度 = 后排两座扣紧比例（主/副驾预锁不计入交互目标）。
    void toggleSeat(String seat, bool cur) {
      final other = seat == '后排左' ? ctl.has('后排右') : ctl.has('后排左');
      final lockedCount = (cur ? 0 : 1) + (other ? 1 : 0);
      ctl.mark(seat, !cur, ratio: lockedCount / 2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('车舱安全带锁止状态', style: TextStyle(fontSize: 10.5, color: p.inkMute)),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: [
            _seat(context, '主驾', locked: true, on: true, onTap: () {}),
            _seat(context, '副驾', locked: true, on: true, onTap: () {}),
            _seat(context, '后排左', locked: false, on: rearL, onTap: () {
              HapticFeedback.mediumImpact();
              toggleSeat('后排左', rearL);
            }),
            _seat(context, '后排右', locked: false, on: rearR, onTap: () {
              HapticFeedback.mediumImpact();
              toggleSeat('后排右', rearR);
            }),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: allLocked
                ? p.emerald.withValues(alpha: 0.12)
                : p.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                allLocked ? Icons.verified_user : Icons.warning_amber_rounded,
                size: 14,
                color: allLocked ? p.emerald : p.amber,
              ),
              const SizedBox(width: 6),
              Text(
                allLocked ? '四座全部锁止 · 出发' : '后排未扣好 · 碰撞飞弹风险',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: allLocked ? p.emerald : p.amber,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seat(
    BuildContext context,
    String label, {
    required bool locked,
    required bool on,
    required VoidCallback onTap,
  }) {
    final p = AppPalettes.of(context);
    final c = locked ? p.emerald : (on ? p.emerald : p.amber);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.12) : p.pillBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? c.withValues(alpha: 0.55) : p.hairline,
            width: on ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              on ? Icons.check_circle : Icons.error_outline,
              size: 14,
              color: c,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label: ${on ? '已扣好' : '扣上'}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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

/// 聚光专项 2 —— 建议 7「量血压」：血压滑杆 + 服药打卡。
class BloodPressureInteractor extends StatelessWidget {
  const BloodPressureInteractor({super.key, required this.advice, required this.scope});

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final sys = ctl.extra<double>('sys') ?? 125;
    final dia = ctl.extra<double>('dia') ?? 80;
    final recorded = ctl.has('记录');
    final level = sys < 120 && dia < 80
        ? (p.emerald, '正常')
        : sys < 140 && dia < 90
            ? (p.amber, '偏高 · 复测并关注')
            : (p.rose, '超标 · 按医嘱干预');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${sys.round()}',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: level.$1,
              ),
            ),
            Text(
              ' / ${dia.round()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.inkMute,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('mmHg', style: TextStyle(fontSize: 10, color: p.inkMute)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: level.$1.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                level.$2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: level.$1,
                ),
              ),
            ),
          ],
        ),
        _bpSlider(context, ctl, '收缩压 (高压)', 'sys', sys, 90, 180),
        _bpSlider(context, ctl, '舒张压 (低压)', 'dia', dia, 50, 120),
        const SizedBox(height: 8),
        PrimaryAction(
          label: recorded ? '今日已记录' : '记录今日读数',
          on: recorded,
          icon: Icons.monitor_heart_outlined,
          color: p.rose,
          onTap: () {
            if (recorded) {
              ctl.setRatio(0);
              storeOf(context).updateCard(scope, advice.id, (s) => s.doneParts.clear());
            } else {
              HapticFeedback.mediumImpact();
              ctl.mark('记录', true, ratio: 1);
            }
          },
        ),
      ],
    );
  }

  Widget _bpSlider(
    BuildContext context,
    CardCtl ctl,
    String label,
    String key,
    double value,
    double min,
    double max,
  ) {
    final p = AppPalettes.of(context);
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(label, style: TextStyle(fontSize: 10.5, color: p.inkSub)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) ~/ 5),
            activeColor: p.rose,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              ctl.setExtra(key, v);
              ctl.setRatio(0.3);
            },
          ),
        ),
      ],
    );
  }
}

/// 聚光专项 3 —— 建议 136「家务外包」：时薪决策计算器。
///
/// 外包月成本 ÷ 每月耗时 = 等效时薪；与你自己的实际时薪对比即得结论。
class WageCalcInteractor extends StatelessWidget {
  const WageCalcInteractor({super.key, required this.advice, required this.scope});

  final Advice advice;
  final PeriodScope scope;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final ctl = CardCtl(storeOf(context), scope, advice);
    final cost = ctl.extra<double>('cost') ?? 1500;
    final hours = ctl.extra<double>('hours') ?? 20;
    final myWage = ctl.extra<double>('myWage') ?? 80;
    final outsourcedWage = hours > 0 ? cost / hours : 0.0;
    final worth = myWage > outsourcedWage;
    final computed = ctl.has('computed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, '外包月成本', '${cost.round()} 元', cost, 200, 6000, 100,
            (v) => ctl.setExtra('cost', v)),
        _row(context, '每月耗时', '${hours.round()} 小时', hours, 2, 60, 1,
            (v) => ctl.setExtra('hours', v)),
        _row(context, '你的税后时薪', '${myWage.round()} 元', myWage, 10, 500, 5,
            (v) => ctl.setExtra('myWage', v)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (worth ? p.emerald : p.amber).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '等效时薪 ${outsourcedWage.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: worth ? p.emerald : p.amber,
                    ),
                  ),
                  Text(' 元/时', style: TextStyle(fontSize: 11, color: p.inkSub)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                worth
                    ? '你的时薪 > 外包时薪 · 划算：把时间还给高价值事项'
                    : '外包时薪 ≥ 你的时薪 · 不划算：自己做或压价再谈',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: worth ? p.emerald : p.amber,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PrimaryAction(
          label: computed ? '决策已记录' : '按此结论执行',
          on: computed,
          icon: Icons.calculate_outlined,
          color: p.emerald,
          onTap: () => ctl.mark('computed', !computed, ratio: computed ? 0 : 1),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String valueText,
    double value,
    double min,
    double max,
    double step,
    ValueChanged<double> onChanged,
  ) {
    final p = AppPalettes.of(context);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: TextStyle(fontSize: 11, color: p.inkSub)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / step).round(),
            activeColor: p.action,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
        SizedBox(
          width: 74,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: p.ink,
            ),
          ),
        ),
      ],
    );
  }
}
