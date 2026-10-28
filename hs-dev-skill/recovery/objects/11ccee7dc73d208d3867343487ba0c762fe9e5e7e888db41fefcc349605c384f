import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/advice.dart';

/// 分享：文案复制 + 系统分享。
///
/// 跨平台策略：系统分享走 share_plus（全平台），复制文案走系统剪贴板；
/// Web 端系统分享自动降级，复制始终可用。
class ShareSheet {
  static Future<void> open(BuildContext context, Advice advice) async {
    final text = buildShareText(advice);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('分享这条建议', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                advice.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('系统分享'),
                onPressed: () async {
                  final box = context.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(
                      text: text,
                      sharePositionOrigin:
                          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制文案'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('文案已复制')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String buildShareText(Advice a) =>
      '【数字阶跃 · 今日行动】${a.title}\n时机：${a.timingBadge}\n—— 来自数字阶跃 KairosStep（本地优先的人生建议行动系统）';
}
