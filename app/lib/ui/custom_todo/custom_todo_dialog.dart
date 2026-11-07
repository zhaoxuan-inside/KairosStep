import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';

/// 完整自建待办创建弹窗：支持标题、内容、触发频次、自定义生活时段
/// （提醒时点 = 时段开始时间）与多选提前提醒
class CustomTodoDialog extends StatefulWidget {
  const CustomTodoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // 键盘弹出时由内容区自行避让，避免路由动画期间 IME 与弹层同时改变约束
      builder: (_) => const CustomTodoDialog(),
    );
  }

  @override
  State<CustomTodoDialog> createState() => _CustomTodoDialogState();
}

class _CustomTodoDialogState extends State<CustomTodoDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // 所属生活时段（自定义起止）：提醒时点 = 时段开始时间
  TimeOfDay _periodStart = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _periodEnd = const TimeOfDay(hour: 20, minute: 0);
  List<int> _leadMinutes = const [0]; // 0(准时), 5, 15, 30，可多选且至少保留一项
  String _frequency = 'daily'; // 'daily', 'workday', 'weekend', 'weekly', 'monthly', 'once'
  bool _titleError = false; // 空标题提交时在标题框标红

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
    (1440, '提前 1 天'),
    (4320, '提前 3 天'),
    (7200, '提前 5 天'),
    (10080, '提前 7 天'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickPeriodTime({required bool isStart}) async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _periodStart : _periodEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      // 空标题不再用 SnackBar 拦截，而是直接在标题框标红提示。
      HapticFeedback.heavyImpact();
      setState(() => _titleError = true);
      return;
    }

    HapticFeedback.mediumImpact();
    final store = storeOf(context);
    final startStr = _formatTime(_periodStart);

    final item = UserTodoItem(
      id: UserTodoItem.newId(),
      title: title,
      content: _contentController.text.trim(),
      triggerTime: startStr, // 触发时点 = 时段开始
      periodStart: startStr,
      periodEnd: _formatTime(_periodEnd),
      timePeriod: 'all_day', // 遗留字段：旧版预设键，自定义时段不再使用
      reminderTimes: [startStr], // 提醒时点 = 时段开始时间
      leadMinutes: _leadMinutes,
      frequency: _frequency,
      createdAt: DateTime.now(),
    );

    // 在 pop 之前取齐 messenger 与配色：pop 后 context 已失活，再 lookup 会抛
    // 「deactivated widget's ancestor」框架异常（设备上表现为保存后无反馈/报错）。
    final messenger = ScaffoldMessenger.of(context);
    final snackbarColor = AppPalettes.of(context).action;
    final snackbarText = '已添加待办「$title」，提醒将于 $startStr 触发';

    store.addUserTodoItem(item);
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(snackbarText),
        backgroundColor: snackbarColor,
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
                  Expanded(
                    child: Text(
                      '新建待办事项',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. 待办标题
              Text('待办标题', style: _labelStyle(p)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                // 不在弹层入场动画期间自动拉起输入法：部分 Android 设备/输入法
                // 会在路由动画中同时改窗口 inset，导致弹层反复重建甚至闪退。
                autofocus: false,
                onChanged: (_) {
                  // 开始输入即撤销标红，避免成功作答后红框残留。
                  if (_titleError) setState(() => _titleError = false);
                },
                decoration: InputDecoration(
                  hintText: '如：早起空腹测血压、带头盔出发、复核劳动合同...',
                  hintStyle: TextStyle(fontSize: 13, color: p.inkMute),
                  filled: true,
                  fillColor: p.pillBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _titleError ? p.rose : p.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _titleError ? p.rose : p.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _titleError ? p.rose : p.action),
                  ),
                ),
              ),
              if (_titleError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '请填写待办标题',
                    style: TextStyle(fontSize: 11.5, color: p.rose),
                  ),
                ),
              const SizedBox(height: 16),

              // 2. 详细内容/执行要点
              Text('操作指引与补充内容', style: _labelStyle(p)),
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

              // 3. 触发频次
              Text('触发频次', style: _labelStyle(p)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: p.pillBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _frequency,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: p.surface,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    icon: Icon(Icons.expand_more_rounded, size: 18, color: p.inkSub),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                    items: _freqOptions.map((f) {
                      final selected = f.$1 == _frequency;
                      return DropdownMenuItem(
                        value: f.$1,
                        child: Row(
                          children: [
                            Expanded(child: Text(f.$2)),
                            if (selected)
                              Icon(Icons.check_rounded, size: 16, color: p.action),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _frequency = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. 所属生活时段（自定义起止；提醒时点 = 开始时间）
              Text('所属生活时段', style: _labelStyle(p)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _periodBox(p, isStart: true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('至', style: TextStyle(fontSize: 12, color: p.inkMute)),
                  ),
                  Expanded(child: _periodBox(p, isStart: false)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '提醒将在时段开始时间触发',
                style: TextStyle(fontSize: 11, color: p.inkMute),
              ),
              const SizedBox(height: 18),

              // 5. 提前提醒范围（可多选）
              Text('提前提醒范围', style: _labelStyle(p)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _leadOptions.map((opt) {
                  final sel = _leadMinutes.contains(opt.$1);
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
                      setState(() {
                        if (v) {
                          _leadMinutes = [..._leadMinutes, opt.$1]..sort();
                        } else if (_leadMinutes.length > 1) {
                          _leadMinutes =
                              _leadMinutes.where((m) => m != opt.$1).toList();
                        }
                        // 仅剩最后一项时取消不生效：至少保留一个提醒基准。
                      });
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

  /// 所属生活时段起止选择框（点击弹系统时间选择器）
  Widget _periodBox(AppPalettes p, {required bool isStart}) {
    final t = isStart ? _periodStart : _periodEnd;
    return InkWell(
      onTap: () => _pickPeriodTime(isStart: isStart),
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
              _formatTime(t),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ],
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
