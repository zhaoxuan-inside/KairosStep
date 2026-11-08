import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import 'interactors.dart';
import 'task_interactors.dart';

/// 聚光专项 1 —— 建议 1「系安全带」：四座拟物车舱。
///
/// 主驾/副驾预锁，后排两座点击扣紧；四座全锁 → 卡片闭环。
class CabinSeatsInteractor extends StatelessWidget {
  const CabinSeatsInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });
  final Advice advice;
  final PeriodScope scope;
  @override
  Widget build(BuildContext context) =>
      ToggleChipsInteractor(advice: advice, scope: scope);
}

class BloodPressureInteractor extends StatelessWidget {
  const BloodPressureInteractor({
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

/// 聚光专项 3 —— 建议 136「家务外包」：时薪决策计算器。
///
/// 外包月成本 ÷ 每月耗时 = 等效时薪；与你自己的实际时薪对比即得结论。
class WageCalcInteractor extends StatelessWidget {
  const WageCalcInteractor({
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
    final cost = ctl.extra<double>('cost') ?? 1500;
    final hours = ctl.extra<double>('hours') ?? 20;
    final myWage = ctl.extra<double>('myWage') ?? 80;
    final outsourcedWage = hours > 0 ? cost / hours : 0.0;
    final worth = myWage > outsourcedWage;
    final computed = ctl.has('computed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('初始值为示例，请改成实际数值。时薪不等于可实际增加的收入，结果仅用于成本比较。'),
        _row(
          context,
          '外包月成本',
          '${cost.round()} 元',
          cost,
          200,
          6000,
          100,
          (v) => ctl.setExtra('cost', v),
        ),
        _row(
          context,
          '每月耗时',
          '${hours.round()} 小时',
          hours,
          2,
          60,
          1,
          (v) => ctl.setExtra('hours', v),
        ),
        _row(
          context,
          '你的税后时薪',
          '${myWage.round()} 元',
          myWage,
          10,
          500,
          5,
          (v) => ctl.setExtra('myWage', v),
        ),
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
                    ? '外包等效成本低于所填时薪，仍需考虑预算与实际可用时间'
                    : '外包等效成本不低于所填时薪，可继续比较质量与时间价值',
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
          label: computed ? '比较已记录' : '保存本次比较',
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
