import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

/// 卡内基式 4 步周复盘全屏沉浸向导
///
/// 严格遵循 DESIGN.md 规约：
/// - 纯色块表达（森林绿方章、温暖纸感底色）；
/// - 彻底禁用 Emoji，使用自绘细线图标；
/// - 聚焦 4 步认知跃迁：【事实】→【反应】→【反思】→【下次只改哪一句话】。
class CarnegieReviewSheet extends StatefulWidget {
  const CarnegieReviewSheet({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, anim, secondAnim) => const CarnegieReviewSheet(),
        transitionsBuilder: (context, anim, secondAnim, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
      ),
    );
  }

  @override
  State<CarnegieReviewSheet> createState() => _CarnegieReviewSheetState();
}

class _CarnegieReviewSheetState extends State<CarnegieReviewSheet> {
  int _step = 0; // 0, 1, 2, 3
  String _tag = '职场沟通';

  final _factCtl = TextEditingController();
  final _actionCtl = TextEditingController();
  final _reactionCtl = TextEditingController();
  final _sentenceCtl = TextEditingController();

  bool _isStamped = false;

  @override
  void dispose() {
    _factCtl.dispose();
    _actionCtl.dispose();
    _reactionCtl.dispose();
    _sentenceCtl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _prev() {
    HapticFeedback.lightImpact();
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    setState(() => _isStamped = true);

    final store = storeOf(context);
    store.addCarnegieReview(
      eventFact: _factCtl.text.isEmpty ? '日常沟通情境' : _factCtl.text,
      myAction: _actionCtl.text.isEmpty ? '下意识辩驳' : _actionCtl.text,
      theirReaction: _reactionCtl.text.isEmpty ? '对方沉默或对抗' : _reactionCtl.text,
      nextOneSentence: _sentenceCtl.text.isEmpty ? '我理解你的感受，这事先放 24 小时再定。' : _sentenceCtl.text,
      tag: _tag,
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

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
          '卡内基式 4 步周复盘',
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 步进度指示条
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: i <= _step ? p.done : p.hairline,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // 主卡片视图
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Stack(
                    children: [
                      _buildCurrentStep(context, p),
                      if (_isStamped)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _stampWidget(p),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 底部步进按钮栏
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: p.inkSub,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _prev,
                      child: const Text('上一步', style: TextStyle(fontSize: 13)),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.ink,
                      foregroundColor: p.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _next,
                    child: Text(
                      _step == 3 ? '落印完成复盘' : '下一步',
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

  Widget _buildCurrentStep(BuildContext context, AppPalettes p) {
    switch (_step) {
      case 0:
        return _step1Fact(p);
      case 1:
        return _step2Action(p);
      case 2:
        return _step3Reaction(p);
      case 3:
      default:
        return _step4NextSentence(p);
    }
  }

  Widget _step1Fact(AppPalettes p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.pillBg, borderRadius: BorderRadius.circular(9999)),
              child: Text('步骤 1 / 4', style: TextStyle(fontSize: 10, color: p.inkMute, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('客观事实', style: TextStyle(fontSize: 11, color: p.inkSub)),
          ],
        ),
        const SizedBox(height: 14),
        Text('本周发生过哪次关键摩擦或决策？', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('客观还原发生了什么，不要带有情绪评价。', style: TextStyle(fontSize: 12, color: p.inkSub)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          children: [
            for (final t in const ['职场沟通', '伴侣分歧', '消费谈判', '长辈沟通', '朋友借钱'])
              GestureDetector(
                onTap: () => setState(() => _tag = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tag == t ? p.ink : p.surfaceGrey,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 11,
                      color: _tag == t ? p.surface : p.ink,
                      fontWeight: _tag == t ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _factCtl,
            maxLines: null,
            expands: true,
            style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.5),
            decoration: InputDecoration(
              hintText: '例：周四下午评审会上，同事当面质疑我的方案漏洞，我当时感到面子挂不住……',
              hintStyle: TextStyle(fontSize: 12.5, color: p.inkMute),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _step2Action(AppPalettes p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.pillBg, borderRadius: BorderRadius.circular(9999)),
              child: Text('步骤 2 / 4', style: TextStyle(fontSize: 10, color: p.inkMute, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('下意识反应', style: TextStyle(fontSize: 11, color: p.inkSub)),
          ],
        ),
        const SizedBox(height: 14),
        Text('你当时做了什么？说了哪句话？', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('还原你第一时间的言行，无论是否冲动。', style: TextStyle(fontSize: 12, color: p.inkSub)),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _actionCtl,
            maxLines: null,
            expands: true,
            style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.5),
            decoration: InputDecoration(
              hintText: '例：我立刻打断对方，急于辩解并列举了对方上一季度的差错……',
              hintStyle: TextStyle(fontSize: 12.5, color: p.inkMute),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _step3Reaction(AppPalettes p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.pillBg, borderRadius: BorderRadius.circular(9999)),
              child: Text('步骤 3 / 4', style: TextStyle(fontSize: 10, color: p.inkMute, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('对方反应与代价', style: TextStyle(fontSize: 11, color: p.inkSub)),
          ],
        ),
        const SizedBox(height: 14),
        Text('对方的反应如何？付出了什么代价？', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('冲突升级了吗？是否多花了冤枉钱或造成内耗？', style: TextStyle(fontSize: 12, color: p.inkSub)),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _reactionCtl,
            maxLines: null,
            expands: true,
            style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.5),
            decoration: InputDecoration(
              hintText: '例：气氛瞬间结冰，会议延误了半小时，我也整晚焦虑不安没睡好……',
              hintStyle: TextStyle(fontSize: 12.5, color: p.inkMute),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _step4NextSentence(AppPalettes p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.done.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9999)),
              child: Text('认知跃迁 · 核心一步', style: TextStyle(fontSize: 10, color: p.done, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('黄金一句话', style: TextStyle(fontSize: 11, color: p.gold)),
          ],
        ),
        const SizedBox(height: 14),
        Text('下次再遇到，你只改口说哪一句话？', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('把你的情绪内耗，收敛为一句平静、有边界的行动。', style: TextStyle(fontSize: 12, color: p.inkSub)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.hairline),
            ),
            child: TextField(
              controller: _sentenceCtl,
              maxLines: null,
              expands: true,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: '例：“你指出的这个细节很重要，我今晚把补充数据整理到文档里同步大家。”',
                hintStyle: TextStyle(fontSize: 13, color: p.inkMute, fontWeight: FontWeight.normal),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stampWidget(AppPalettes p) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 2.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: p.done, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '已省察',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.done,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
