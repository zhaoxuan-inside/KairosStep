import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../models/advice.dart';

/// 精美图片卡片分享弹窗：将建议渲染为海报级视觉卡片并导出图片分享
class ShareCardDialog extends StatefulWidget {
  const ShareCardDialog({super.key, required this.advice});

  final Advice advice;

  static Future<void> show(BuildContext context, Advice advice) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardDialog(advice: advice),
    );
  }

  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _isExporting = false;

  Future<Uint8List?> _captureCardBytes() async {
    try {
      final boundary =
          _cardBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing card image: $e');
      return null;
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    final bytes = await _captureCardBytes();
    setState(() => _isExporting = false);

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('卡片图片生成失败，请重试')));
      }
      return;
    }

    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'KairosStep_Advice_${widget.advice.id}.png',
          ),
        ],
        text: '【数字阶跃 · 人生防线】${widget.advice.title}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _copyText() {
    HapticFeedback.selectionClick();
    final a = widget.advice;
    final text =
        '【数字阶跃 · 人生防线】${a.title}\n时机：${a.timingBadge}\n章节：${a.chapter}\n—— 来自 KairosStep 本地优先防线系统';
    Clipboard.setData(ClipboardData(text: text));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('文案已成功复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final a = widget.advice;
    final domain = LifeDomain.ofChapter(a.chapter);

    return Container(
      margin: const EdgeInsets.only(top: 60),
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 拖动手柄
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.photo_size_select_actual_outlined,
                    size: 20,
                    color: p.action,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '分享专属精美卡片',
                    style: TextStyle(
                      fontSize: 16,
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
              const SizedBox(height: 12),

              // ---- 核心待捕获海报卡片 (RepaintBoundary) ----
              Center(
                child: RepaintBoundary(
                  key: _cardBoundaryKey,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          domain.accentColor.withValues(alpha: 0.12),
                          p.surface,
                          p.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: domain.accentColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 顶部 Branding
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: domain.accentColor.withValues(
                                  alpha: 0.18,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                domain.icon,
                                size: 16,
                                color: domain.accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KairosStep · 数字阶跃',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: p.ink,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '737 条实证实操生活防线',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: p.inkSub,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: domain.accentColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                domain.shortTitle,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: domain.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 时机 Badge 与章节
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: p.inkMute.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                a.timingBadge,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.action,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                a.chapter,
                                style: TextStyle(fontSize: 11, color: p.inkSub),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 大标题
                        Text(
                          a.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                            height: 1.45,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 核心操作拆解 (Parts items)
                        if (a.parts.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < a.parts.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < a.parts.length - 1 ? 6 : 0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: domain.accentColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            a.parts[i],
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: p.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // 底部签名与哲学
                        Divider(height: 1, color: p.hairline),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '拒绝早死与慢慢死 · 本地优先',
                              style: TextStyle(fontSize: 10, color: p.inkMute),
                            ),
                            Text(
                              '${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: p.inkMute,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---- 分享与复制操作按钮 ----
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.action,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.share, size: 18),
                label: Text(
                  _isExporting ? '正在生成精美卡片...' : '分享精美图片卡片',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _isExporting ? null : _shareImage,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.copy, size: 16, color: p.inkSub),
                label: Text(
                  '复制文本内容',
                  style: TextStyle(fontSize: 13, color: p.inkSub),
                ),
                onPressed: _copyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
