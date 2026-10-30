import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';

/// 建议详情层：底部滑出、只读，不影响勾选闭环。
Future<void> showAdviceDetail(BuildContext context, int id) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AdviceDetailSheet(adviceId: id),
  );
}

class AdviceDetailSheet extends StatelessWidget {
  const AdviceDetailSheet({super.key, required this.adviceId});

  final int adviceId;

  static const pad = EdgeInsets.symmetric(horizontal: 18);

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final catalog = catalogOf(context);
    final advice = catalog.byId[adviceId];
    final d = catalog.detailOf(adviceId);
    if (advice == null || d == null) return const SizedBox(height: 120);
    final summary = d.humanized.isNotEmpty ? d.humanized : _lead(d.plain ?? '');
    final explanation = _withoutRepeatedLead(d.plain, summary);

    final gradeColor =
        d.grade == 'A' ? p.emerald : d.grade == 'B' ? p.action : p.amber;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: pad,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.pillBg,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    advice.timingBadge,
                    style: TextStyle(fontSize: 9.5, color: p.inkSub),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '证据等级 ${d.grade}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: pad.add(const EdgeInsets.only(top: 10)),
            child: Text(advice.title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (summary.isNotEmpty)
            Padding(
              padding: pad.add(const EdgeInsets.only(top: 8)),
              child: Text(summary, style: const TextStyle(fontSize: 12.5, height: 1.6)),
            ),
          const SizedBox(height: 14),
          ExpansionTile(
            title: const Text('查看成本、依据与补充说明', style: TextStyle(fontSize: 12.5)),
            childrenPadding: pad,
            children: [
              _section(context, '成本', d.cost),
              _section(context, '完整解释', explanation),
              _section(context, '收益 · 研究数据', d.benefit),
          if (d.sources.isNotEmpty)
            Padding(
              padding: pad.add(const EdgeInsets.only(bottom: 10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('来源', style: _labelStyle(p)),
                  const SizedBox(height: 6),
                  for (final s in d.sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '· ${s.first}${s.length > 1 && s[1].isNotEmpty ? '\n  ${s[1]}' : ''}',
                        style: TextStyle(fontSize: 11, height: 1.5, color: p.inkSub),
                      ),
                    ),
                ],
              ),
            ),
              _section(context, '备注与争议', d.notes, muted: true),
            ],
          ),
          if (d.rel.isNotEmpty) ...[
            Padding(
              padding: pad,
              child: Text('关联建议', style: _labelStyle(p)),
            ),
            Padding(
              padding: pad.add(const EdgeInsets.only(top: 6)),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rid in d.rel)
                    if (catalog.byId[rid] != null)
                      relatedChip(context, catalog.byId[rid]!),
                ],
              ),
            ),
          ],
          Padding(
            padding: pad.add(const EdgeInsets.only(top: 10, bottom: 6)),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.action.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                icon: Icon(Icons.add_task, size: 15, color: p.action),
                label: Text(
                  '加入我的待办清单',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: p.action,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  final store = storeOf(context);
                  store.addUserTodo(advice.title, adviceId: advice.id);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已将建议加入你的待办清单'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: pad.add(const EdgeInsets.only(top: 14)),
            child: Text(
              '内容整理自《高性价比人生指南》第 $adviceId 条 · 请结合自身情况判断',
              style: TextStyle(fontSize: 10, color: p.inkMute),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle(AppPalettes p) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: p.inkMute,
      );

  String _lead(String plain) {
    final sentence = RegExp(r'[。！？]').firstMatch(plain);
    if (sentence != null && sentence.end <= 180) {
      return plain.substring(0, sentence.end);
    }
    return plain.length <= 180 ? plain : '';
  }

  String? _withoutRepeatedLead(String? plain, String lead) {
    if (plain == null || lead.isEmpty || !plain.startsWith(lead)) return plain;
    return plain.substring(lead.length).trim();
  }

  Widget _section(BuildContext context, String label, String? text, {bool muted = false}) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final p = AppPalettes.of(context);
    return Padding(
      padding: pad.add(const EdgeInsets.only(bottom: 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle(p)),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: muted ? p.inkMute : p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// 关联建议跳转胶囊（复用卡片 ActionChip 视觉，点击叠开详情）。
Widget relatedChip(BuildContext context, Advice advice) {
  final p = AppPalettes.of(context);
  return InkWell(
    borderRadius: BorderRadius.circular(9999),
    onTap: () {
      Navigator.of(context).pop();
      showAdviceDetail(context, advice.id);
    },
    child: Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.pillBg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        advice.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: p.inkSub),
      ),
    ),
  );
}
