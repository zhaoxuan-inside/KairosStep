import 'package:flutter/material.dart';

import '../../models/advice.dart';
import 'share_card_dialog.dart';

/// 分享：精美海报图片卡片 + 文本复制。
class ShareSheet {
  static Future<void> open(BuildContext context, Advice advice) async {
    await ShareCardDialog.show(context, advice);
  }

  static String buildShareText(Advice a) =>
      '【数字阶跃 · 人生防线】${a.title}\n时机：${a.timingBadge}\n章节：${a.chapter}\n—— 来自数字阶跃 KairosStep（本地优先的人生建议行动系统）';
}
