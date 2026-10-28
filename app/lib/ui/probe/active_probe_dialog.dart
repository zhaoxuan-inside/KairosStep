import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../models/probe_model.dart';
import '../../state/app_store.dart';
import '../../state/probe_scheduler.dart';
import '../detail/advice_detail_sheet.dart';

/// 主动探测交互弹窗
class ActiveProbeDialog extends StatefulWidget {
  const ActiveProbeDialog({
    super.key,
    required this.payload,
    required this.scheduler,
  });

  final ProbePayload payload;
  final ProbeScheduler scheduler;

  static Future<void> show(
    BuildContext context, {
    required ProbePayload payload,
    required ProbeScheduler scheduler,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !payload.isMandatory,
      builder: (_) => PopScope(
        canPop: !payload.isMandatory,
        child: ActiveProbeDialog(
          payload: payload,
          scheduler: scheduler,
        ),
      ),
    );
  }

  @override
  State<ActiveProbeDialog> createState() => _ActiveProbeDialogState();
}

class _ActiveProbeDialogState extends State<ActiveProbeDialog> {
  // 记录每个问题的用户选择：questionId -> optionKey
  final Map<String, String> _selectedOptionKeys = {};

  @override
  void initState() {
    super.initState();
    // 默认不预选，强制用户如实点击，或预选第一个非空项
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final catalog = catalogOf(context);
    final payload = widget.payload;
    final isUrgent = payload.isMandatory;

    // 收集当前所有选中的选项所关联的建议列表
    final matchedAdviceIds = <int>{};
    for (final q in payload.questions) {
      final selectedKey = _selectedOptionKeys[q.id];
      if (selectedKey != null) {
        final opt = q.options.firstWhere(
          (o) => o.key == selectedKey,
          orElse: () => q.options.first,
        );
        matchedAdviceIds.addAll(opt.associatedAdviceIds);
      }
    }

    final matchedAdvices = matchedAdviceIds
        .map((id) => catalog.adviceById(id))
        .whereType<Advice>()
        .toList();

    return AlertDialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isUrgent ? p.amber.withValues(alpha: 0.8) : p.hairline,
          width: isUrgent ? 1.8 : 1.0,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: isUrgent
                  ? p.amber.withValues(alpha: 0.15)
                  : p.action.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isUrgent ? '🚨' : (payload.isMerged ? '🔄' : '🌿'),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  isUrgent
                      ? '紧急生命安全提醒'
                      : (payload.isMerged ? '主动综合情境探查' : '主动关怀探查'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isUrgent ? p.amber : p.action,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!isUrgent)
            IconButton(
              icon: Icon(Icons.close, size: 20, color: p.inkMute),
              onPressed: () {
                widget.scheduler.dismissCurrentPayload();
                Navigator.of(context).pop();
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payload.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                payload.description,
                style: TextStyle(fontSize: 12.5, color: p.inkSub, height: 1.4),
              ),
              const SizedBox(height: 16),

              // 逐题渲染选项
              for (int i = 0; i < payload.questions.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                _buildQuestionBlock(p, payload.questions[i]),
              ],

              // 针对性建议卡片反馈区
              if (matchedAdvices.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: p.action),
                    const SizedBox(width: 6),
                    Text(
                      '已为你精准匹配 ${matchedAdvices.length} 条针对性建议',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.action,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final a in matchedAdvices)
                  _buildMatchedAdviceItem(context, p, store, a),
              ],

              // 紧急拨号入口（如触发了急救或心理热线）
              if (matchedAdviceIds.contains(680)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.action,
                      side: BorderSide(color: p.action.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.phone_in_talk, size: 15),
                    label: const Text('一键拨打 12356 心理危机干预热线',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    onPressed: () => launchUrl(
                      Uri.parse('tel:12356'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ],
              if (isUrgent || matchedAdviceIds.contains(423) || matchedAdviceIds.contains(424)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.emergency, size: 16),
                    label: const Text('一键拨打 120 医疗急救',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    onPressed: () => launchUrl(
                      Uri.parse('tel:120'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 底部按钮栏
              Row(
                children: [
                  if (!isUrgent) ...[
                    PopupMenuButton<String>(
                      tooltip: '防打扰控制',
                      onSelected: (val) {
                        if (val == 'snooze') {
                          widget.scheduler.snoozeCurrentPayload(minutes: 30);
                          Navigator.of(context).pop();
                        } else if (val == 'dismiss_today') {
                          widget.scheduler.dismissForToday();
                          Navigator.of(context).pop();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'snooze',
                          child: Text('稍后 30 分钟提醒', style: TextStyle(fontSize: 12.5)),
                        ),
                        const PopupMenuItem(
                          value: 'dismiss_today',
                          child: Text('今日不再主动探查', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 14, color: p.inkSub),
                            const SizedBox(width: 4),
                            Text('防打扰', style: TextStyle(fontSize: 11.5, color: p.inkSub)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isUrgent ? p.amber : p.ink,
                      foregroundColor: isUrgent ? Colors.black87 : p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.scheduler.dismissCurrentPayload();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      isUrgent ? '我已了解并采取自救' : '确认记录',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionBlock(AppPalettes p, ProbeQuestion q) {
    final selectedKey = _selectedOptionKeys[q.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
        if (q.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            q.subtitle!,
            style: TextStyle(fontSize: 11.5, color: p.inkMute),
          ),
        ],
        const SizedBox(height: 10),
        for (final opt in q.options) ...[
          _buildOptionTile(p, q.id, opt, isSelected: selectedKey == opt.key),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildOptionTile(
    AppPalettes p,
    String questionId,
    ProbeOption opt, {
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedOptionKeys[questionId] = opt.key;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? p.action.withValues(alpha: 0.1)
              : p.pillBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? p.action : p.hairline,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(opt.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? p.action : p.ink,
                    ),
                  ),
                  if (opt.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      opt.description!,
                      style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 16, color: p.action)
            else
              Icon(Icons.radio_button_unchecked, size: 16, color: p.inkMute),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedAdviceItem(
    BuildContext context,
    AppPalettes p,
    AppStore store,
    Advice a,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.pillBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward, size: 14, color: p.inkMute),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  showAdviceDetail(context, a.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            a.coreAction,
            style: TextStyle(fontSize: 12, color: p.inkSub, height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${a.chapter} · #${a.id}',
                style: TextStyle(fontSize: 10.5, color: p.inkMute),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.addUserTodo(a.title, adviceId: a.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已将「${a.title}」加入今日专注清单')),
                  );
                },
                borderRadius: BorderRadius.circular(9999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.action.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_task, size: 12, color: p.action),
                      const SizedBox(width: 4),
                      Text(
                        '加入待办',
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
    );
  }
}
