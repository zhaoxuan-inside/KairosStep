import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';

/// 完整自建待办创建弹窗：支持标题、内容、触发时间、时段范围、多提醒时点、提前提醒与频次
class CustomTodoDialog extends StatefulWidget {
  const CustomTodoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomTodoDialog(),
    );
  }

  @override
  State<CustomTodoDialog> createState() => _CustomTodoDialogState();
}

class _CustomTodoDialogState extends State<CustomTodoDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  TimeOfDay? _triggerTime = const TimeOfDay(hour: 8, minute: 30);
  String _timePeriod = 'all_day';
  final List<String> _reminderTimes = ['08:30'];
  int _leadMinutes = 0; // 0, 5, 15, 30
  String _frequency = 'daily'; // 'daily', 'workday', 'weekend', 'weekly', 'monthly', 'once'

  static const _periodOptions = [
    ('all_day', '全天守护'),
    ('morning', '晨间 (05:00-09:30)'),
    ('focus', '上午专注 (09:30-12:00)'),
    ('afternoon', '午后 (12:00-18:00)'),
    ('evening', '傍晚 (18:00-22:00)'),
    ('night', '夜间 (22:00-05:00)'),
  ];

  static const _freqOptions = [
    ('daily', '每天'),
    ('workday', '工作日'),
    ('weekend', '周末'),
    ('weekly', '每周'),
    ('monthly', '每月'),
    ('once', '仅一次'),
  ];

  static const _leadOptions = [
    (0, '准时提醒'),
    (5, '提前 5 分钟'),
    (15, '提前 15 分钟'),
    (30, '提前 30 分钟'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTriggerTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _triggerTime ?? const TimeOfDay(hour: 8, minute: 30),
    );
    if (picked != null) {
      setState(() {
        _triggerTime = picked;
        final timeStr = _formatTime(picked);
        if (!_reminderTimes.contains(timeStr)) {
          _reminderTimes.insert(0, timeStr);
        }
      });
    }
  }

  Future<void> _addReminderTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final str = _formatTime(picked);
      if (!_reminderTimes.contains(str)) {
        setState(() {
          _reminderTimes.add(str);
          _reminderTimes.sort();
        });
      }
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入待办标题')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final store = storeOf(context);
    final triggerTimeStr = _triggerTime != null ? _formatTime(_triggerTime!) : null;

    final item = UserTodoItem(
      id: 'todo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      content: _contentController.text.trim(),
      triggerTime: triggerTimeStr,
      timePeriod: _timePeriod,
      reminderTimes: _reminderTimes,
      leadMinutes: _leadMinutes,
      frequency: _frequency,
      createdAt: DateTime.now(),
    );

    store.addUserTodoItem(item);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加待办「$title」${_reminderTimes.isNotEmpty ? "，并注册 ${_reminderTimes.length} 个弹窗提醒" : ""}'),
        backgroundColor: AppPalettes.of(context).action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 60, bottom: bottomInset),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动手柄与标题
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: p.inkMute.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.add_task, color: p.action, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '新建自建待办 · 生活防线',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: p.inkSub),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. 待办标题
              Text('待办标题 (必填)', style: _labelStyle(p)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '如：早起空腹测血压、带头盔出发、复核劳动合同...',
                  hintStyle: TextStyle(fontSize: 13, color: p.inkMute),
                  filled: true,
                  fillColor: p.pillBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 详细内容/执行要点
              Text('操作指引与补充内容 (选填)', style: _labelStyle(p)),
              const SizedBox(height: 6),
              TextField(
                controller: _contentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '记录该任务的落地细节、准备清单或防线要领...',
                  hintStyle: TextStyle(fontSize: 12.5, color: p.inkMute),
                  filled: true,
                  fillColor: p.pillBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. 触发时间与触发频次
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('具体触发时间点', style: _labelStyle(p)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTriggerTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: p.pillBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.hairline),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: p.action),
                                const SizedBox(width: 8),
                                Text(
                                  _triggerTime != null ? _formatTime(_triggerTime!) : '未指定',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('触发频次/周期', style: _labelStyle(p)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: p.pillBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.hairline),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _frequency,
                              isExpanded: true,
                              items: _freqOptions.map((f) {
                                return DropdownMenuItem(
                                  value: f.$1,
                                  child: Text(f.$2, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _frequency = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 4. 时段范围 (对应当下与日常时间流)
              Text('所属生活时段 (用于时间尺与视窗过滤)', style: _labelStyle(p)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: p.pillBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _timePeriod,
                    isExpanded: true,
                    items: _periodOptions.map((po) {
                      return DropdownMenuItem(
                        value: po.$1,
                        child: Text(po.$2, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _timePeriod = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 5. 提醒时间列表与提前提醒
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('弹窗提醒时刻列表 (注册器免扫描)', style: _labelStyle(p)),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: Icon(Icons.add_alarm, size: 14, color: p.action),
                    label: Text('加时点', style: TextStyle(fontSize: 12, color: p.action)),
                    onPressed: _addReminderTime,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _reminderTimes)
                    Chip(
                      backgroundColor: p.action.withValues(alpha: 0.1),
                      label: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.action,
                        ),
                      ),
                      deleteIcon: Icon(Icons.close, size: 14, color: p.action),
                      onDeleted: () {
                        setState(() => _reminderTimes.remove(t));
                      },
                    ),
                  if (_reminderTimes.isEmpty)
                    Text(
                      '未添加弹窗提醒时点（仅在对应待办流中呈现）',
                      style: TextStyle(fontSize: 12, color: p.inkMute),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 6. 提前提醒范围
              Text('提前提醒范围', style: _labelStyle(p)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _leadOptions.map((opt) {
                  final sel = _leadMinutes == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: sel,
                    selectedColor: p.action,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: sel ? Colors.white : p.ink,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    onSelected: (v) {
                      if (v) setState(() => _leadMinutes = opt.$1);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.action,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    '保存并注入生活防线',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(AppPalettes p) => TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: p.ink,
      );
}
