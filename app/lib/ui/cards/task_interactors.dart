import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/advice.dart';
import 'interactors.dart';

/// Enter actual observations. No prefilled measurements and no inferred diagnosis.
class NumericRecordInteractor extends StatefulWidget {
  const NumericRecordInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });
  final Advice advice;
  final PeriodScope scope;
  @override
  State<NumericRecordInteractor> createState() =>
      _NumericRecordInteractorState();
}

class _NumericRecordInteractorState extends State<NumericRecordInteractor> {
  final _form = GlobalKey<FormState>();
  final Map<String, String> _input = {};
  @override
  Widget build(BuildContext context) {
    final binding = catalogOf(context).displayBindings
        .bindingOf(widget.advice.id);
    final fields = ((binding?.params['fields'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final ctl = CardCtl(storeOf(context), widget.scope, widget.advice);
    final history = ctl.extra<List>('records') ?? const [];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                key: ValueKey('record-${widget.advice.id}-${field['key']}'),
                decoration: InputDecoration(
                  labelText: field['label'] as String,
                  suffixText: field['unit'] as String?,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => _input[field['key'] as String] = value,
                validator: (value) {
                  final number = double.tryParse(value?.trim() ?? '');
                  if (number == null || !number.isFinite) return '请输入实际数值';
                  if (number < (field['min'] as num) ||
                      number > (field['max'] as num)) {
                    return '请核对数值与单位';
                  }
                  return null;
                },
              ),
            ),
          if (fields.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存本次实际记录'),
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                final values = {
                  for (final field in fields)
                    field['key'] as String: double.parse(
                      _input[field['key']]!.trim(),
                    ),
                };
                if (values.containsKey('sys') &&
                    values.containsKey('dia') &&
                    values['sys']! <= values['dia']!) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请核对收缩压与舒张压的输入顺序')),
                  );
                  return;
                }
                final entry = {
                  'at': DateTime.now().toIso8601String(),
                  'values': values,
                };
                ctl.setExtra(
                  'records',
                  [
                    ...history,
                    entry,
                  ].reversed.take(100).toList().reversed.toList(),
                );
                ctl.mark('recorded', true, ratio: 1);
                setState(() {});
              },
            ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('已保存 ${history.length} 次记录（保留最近100次）'),
            for (final entry in history.reversed.take(3))
              Text(
                '${(entry['at'] as String).replaceFirst('T', ' ').substring(0, 16)} · ${fields.map((f) => '${f['label']} ${(entry['values'] as Map)[f['key']]} ${f['unit'] ?? ''}').join(' / ')}',
              ),
          ],
        ],
      ),
    );
  }
}

/// Dates only start after explicit user confirmation; legal periods are never guessed.
class DeadlineInteractor extends StatelessWidget {
  const DeadlineInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });
  final Advice advice;
  final PeriodScope scope;
  @override
  Widget build(BuildContext context) {
    final ctl = CardCtl(storeOf(context), scope, advice);
    final binding = catalogOf(context).displayBindings.bindingOf(advice.id);
    final labels = binding?.stringListParam('deadlines') ?? const ['自行确认的截止日期'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('按实际事件与适用规则确认日期；查看卡片不会启动倒计时。设置日期不等于完成事项，也不会自动开启通知。'),
        for (final label in labels)
          Builder(
            builder: (context) {
              final date = DateTime.tryParse(
                ctl.extra<String>('deadline:$label') ?? '',
              );
              final now = DateTime.now();
              final days = date
                  ?.difference(DateTime(now.year, now.month, now.day))
                  .inDays;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                subtitle: Text(
                  date == null
                      ? '未设置'
                      : '${date.toIso8601String().substring(0, 10)} · ${days! < 0 ? '已过期 ${-days} 天' : '剩余 $days 天'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (date != null)
                      IconButton(
                        tooltip: '清除日期',
                        icon: const Icon(Icons.clear),
                        onPressed: () => ctl.setExtra('deadline:$label', null),
                      ),
                    IconButton(
                      tooltip: '设置日期',
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date ?? now,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          ctl.setExtra(
                            'deadline:$label',
                            picked.toIso8601String(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class WrittenPlanInteractor extends StatefulWidget {
  const WrittenPlanInteractor({
    super.key,
    required this.advice,
    required this.scope,
  });
  final Advice advice;
  final PeriodScope scope;
  @override
  State<WrittenPlanInteractor> createState() => _WrittenPlanInteractorState();
}

class _WrittenPlanInteractorState extends State<WrittenPlanInteractor> {
  final Map<String, String> _values = {};
  @override
  Widget build(BuildContext context) {
    final ctl = CardCtl(storeOf(context), widget.scope, widget.advice);
    final labels = catalogOf(context).displayBindings
        .bindingOf(widget.advice.id)!
        .stringListParam('fields');
    return Column(
      children: [
        for (final label in labels)
          TextFormField(
            initialValue: ctl.extra<String>('plan:$label') ?? '',
            decoration: InputDecoration(labelText: label),
            onChanged: (value) => _values[label] = value,
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final values = {
              for (final label in labels)
                label:
                    (_values[label] ?? ctl.extra<String>('plan:$label') ?? '')
                        .trim(),
            };
            if (values.values.any((value) => value.isEmpty)) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请填写时间、地点或情境及具体行动')));
              return;
            }
            for (final entry in values.entries) {
              ctl.setExtra('plan:${entry.key}', entry.value);
            }
            ctl.mark('plan', true, ratio: 1);
          },
          child: const Text('保存行动计划'),
        ),
      ],
    );
  }
}
