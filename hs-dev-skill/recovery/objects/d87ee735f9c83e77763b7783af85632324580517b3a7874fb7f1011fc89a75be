import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

/// 已排除建议管理面板 (补全画像不足的反悔中枢)
class ExcludedAdvicesView extends StatelessWidget {
  const ExcludedAdvicesView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExcludedAdvicesView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final catalog = catalogOf(context);
    final excludedIds = store.excludedAdviceIds.toList();
    final excludedAdvices = catalog.adviceList.where((a) => excludedIds.contains(a.id)).toList();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: AppHairlineIcons.cross(color: p.ink, size: 14),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '已排除建议管理',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: p.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: excludedAdvices.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppHairlineIcons.check(color: p.emerald, size: 28),
                      const SizedBox(height: 12),
                      Text(
                        '当前无任何已排除建议',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '在日常卡片右上角点击叉号，可将不契合自身的建议移出日常流，在此可随时一键恢复。',
                        style: TextStyle(fontSize: 12, color: p.inkMute, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: excludedAdvices.length,
                itemBuilder: (ctx, idx) {
                  final a = excludedAdvices[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${a.id} · ${a.chapter}',
                                style: TextStyle(fontSize: 10.5, color: p.inkMute, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a.title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.emerald.withValues(alpha: 0.14),
                            foregroundColor: p.emerald,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: AppHairlineIcons.check(color: p.emerald, size: 12),
                          label: const Text('重新启用', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            store.restoreAdvice(a.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
