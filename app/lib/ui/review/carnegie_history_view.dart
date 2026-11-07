import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

/// 卡内基周复盘历史：已沉淀的认知跃迁列表（最新在前）。
class CarnegieHistoryView extends StatelessWidget {
  const CarnegieHistoryView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CarnegieHistoryView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final reviews = store.carnegieReviews;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          icon: AppHairlineIcons.cross(color: p.ink, size: 14),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '复盘历史',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: reviews.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppHairlineIcons.carnegie(color: p.gold, size: 28),
                      const SizedBox(height: 12),
                      Text(
                        '还没有复盘记录',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '在今日页完成一次卡内基式 4 步周复盘，\n沉淀的认知跃迁会出现在这里。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: p.inkMute, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: reviews.length,
                itemBuilder: (context, i) {
                  final r = reviews[i];
                  final t = r.createdAt;
                  final dateStr =
                      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: p.pillBg,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                r.tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: p.inkSub,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: TextStyle(fontSize: 10, color: p.inkMute),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _factRow(p, '客观事实', r.eventFact),
                        _factRow(p, '我的言行', r.myAction),
                        _factRow(p, '对方反应与代价', r.theirReaction),
                        const SizedBox(height: 8),
                        // 黄金一句话：本次复盘的认知跃迁，高亮呈现
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: p.done.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: p.done.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '下次只改这一句',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: p.done,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.nextOneSentence,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _factRow(AppPalettes p, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.inkMute),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(fontSize: 12.5, color: p.ink, height: 1.5),
          ),
        ],
      ),
    );
  }
}
