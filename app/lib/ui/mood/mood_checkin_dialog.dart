import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';

/// 情绪晴雨表与心情关怀弹窗：按用户身份进行侧面温和关怀，在低落/高压时主动提供防线支持
class MoodCheckinDialog extends StatefulWidget {
  const MoodCheckinDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MoodCheckinDialog(),
    );
  }

  @override
  State<MoodCheckinDialog> createState() => _MoodCheckinDialogState();
}

class _MoodCheckinDialogState extends State<MoodCheckinDialog> {
  int _step = 0; // 0: 整体心情, 1: 角色情境追问, 2: 关怀与防线指引

  // 状态记录
  String? _moodLevel; // 'great', 'calm', 'tired', 'stressed', 'depressed'
  String? _workStudyFeeling;
  String? _relationshipFeeling;

  static const _moodOptions = [
    ('great', '😊', '充实愉悦', '状态在线，心情开阔'),
    ('calm', '😌', '平和从容', '不急不缓，节奏稳定'),
    ('tired', '🥱', '略显疲惫', '有点透支，需要喘息'),
    ('stressed', '😫', '压力山大', '事情堆积，倍感紧绷'),
    ('depressed', '🌧️', '情绪低落', '提不起劲，陷入消沉'),
  ];

  void _onSelectMood(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _moodLevel = key;
      _step = 1;
    });
  }

  void _finishCheckin() {
    HapticFeedback.mediumImpact();
    setState(() {
      _step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final profile = store.profile;

    final isStudent = profile.roles.contains('学生');
    final isWorker = profile.roles.contains('上班族') || profile.isProgrammer;
    final isEntrepreneur = profile.isEntrepreneur || profile.roles.contains('创业者');

    return Container(
      margin: const EdgeInsets.only(top: 80),
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
                  Icon(Icons.spa_outlined, color: p.action, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '今日心情关照 · 心理韧性',
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

              if (_step == 0) _buildStep0Mood(p),
              if (_step == 1) _buildStep1RoleContext(p, isWorker, isStudent, isEntrepreneur),
              if (_step == 2) _buildStep2ResultAndCare(p, store),
            ],
          ),
        ),
      ),
    );
  }

  // 阶段 0: 基础心情
  Widget _buildStep0Mood(AppPalettes p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '你今天的心情怎么样？',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.ink),
        ),
        const SizedBox(height: 6),
        Text(
          '如实倾听内心的感受。KairosStep 绝不在日常清单直接向你生硬推送重度心理条目，仅在察觉你需要时温柔守护。',
          style: TextStyle(fontSize: 13, height: 1.5, color: p.inkSub),
        ),
        const SizedBox(height: 20),
        for (final item in _moodOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _onSelectMood(item.$1),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: p.pillBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.hairline),
                ),
                child: Row(
                  children: [
                    Text(item.$2, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$4,
                            style: TextStyle(fontSize: 12, color: p.inkSub),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: p.inkMute),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 阶段 1: 角色适应性问候
  Widget _buildStep1RoleContext(
    AppPalettes p,
    bool isWorker,
    bool isStudent,
    bool isEntrepreneur,
  ) {
    String q1Title;
    List<String> q1Options;
    String q2Title;
    List<String> q2Options;

    if (isWorker) {
      q1Title = '上班工作感受怎么样？';
      q1Options = ['高效推进', '按部就班', '沟通心累', '加班透支/严重内耗'];
      q2Title = '和同事/领导的关系怎么样？';
      q2Options = ['相处融洽', '各司其职/保持距离', '偶有摩擦分歧', '人际孤立/被刁难'];
    } else if (isStudent) {
      q1Title = '上课与学业压力怎么样？';
      q1Options = ['轻松跟上', '学业适中', '备考吃力', '焦虑迷茫/严重跟不上'];
      q2Title = '和同学/室友相处怎么样？';
      q2Options = ['非常融洽', '普通客气', '孤单疏离', '有矛盾摩擦'];
    } else if (isEntrepreneur) {
      q1Title = '经营与业务推进怎么样？';
      q1Options = ['按计划突破', '平稳运行', '现金流紧绷', '焦虑失眠/举步维艰'];
      q2Title = '合伙人与团队协作怎么样？';
      q2Options = ['心齐力足', '偶有争执', '理念分歧', '孤立无援'];
    } else {
      q1Title = '今日的生活节奏怎么样？';
      q1Options = ['轻松自在', '节奏适中', '琐碎忙碌', '身心疲惫'];
      q2Title = '与周围人相处怎么样？';
      q2Options = ['温暖愉快', '平淡自处', '略感孤独', '心累心烦'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q1Title,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.ink),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: q1Options.map((opt) {
            final sel = _workStudyFeeling == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: sel,
              selectedColor: p.action,
              labelStyle: TextStyle(
                fontSize: 13,
                color: sel ? Colors.white : p.ink,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (v) {
                if (v) setState(() => _workStudyFeeling = opt);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          q2Title,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.ink),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: q2Options.map((opt) {
            final sel = _relationshipFeeling == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: sel,
              selectedColor: p.action,
              labelStyle: TextStyle(
                fontSize: 13,
                color: sel ? Colors.white : p.ink,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (v) {
                if (v) setState(() => _relationshipFeeling = opt);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.action,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_workStudyFeeling != null && _relationshipFeeling != null)
                ? _finishCheckin
                : null,
            child: const Text('查看今日心理韧性建议', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // 阶段 2: 结果反馈与精准建议提供
  Widget _buildStep2ResultAndCare(AppPalettes p, AppStore store) {
    final isLowMood = _moodLevel == 'stressed' ||
        _moodLevel == 'depressed' ||
        (_workStudyFeeling?.contains('内耗') ?? false) ||
        (_workStudyFeeling?.contains('透支') ?? false) ||
        (_relationshipFeeling?.contains('刁难') ?? false);

    final catalog = catalogOf(context);
    final advice568 = catalog.adviceById(568);
    final advice113 = catalog.adviceById(113);
    final advice680 = catalog.adviceById(680);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLowMood
                ? p.amber.withValues(alpha: 0.1)
                : p.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLowMood ? p.amber.withValues(alpha: 0.3) : p.emerald.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLowMood ? '🌧️' : '🌿',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLowMood ? '察觉到了你的紧绷与不易' : '状态很稳，继续保持',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLowMood ? p.amber : p.emerald,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLowMood
                          ? '工作或生活可能会有失控的时刻。KairosStep 为你调取了最顶级的实证解压干预方案，请对自己多一点宽容。'
                          : '保持这种从容与秩序感，KairosStep 会在后台继续为你守好各项生活底线。',
                      style: TextStyle(fontSize: 13, height: 1.45, color: p.inkSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (isLowMood) ...[
          Text('为你特选的即时心理减压指引', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.ink)),
          const SizedBox(height: 10),

          if (advice568 != null)
            _buildAdviceCareTile(
              p,
              icon: Icons.directions_run_outlined,
              title: '心情差到抑郁的程度，就去走或者跑',
              desc: '身体运动抗抑郁的效应量跟强度成正比，快速走或慢跑 20 分钟能迅速打破反刍思维恶性循环。',
              onAddTodo: () {
                store.addUserTodo('走或跑 20 分钟（运动抗抑郁）', adviceId: 568);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入今日专注清单')));
              },
            ),

          if (advice113 != null)
            _buildAdviceCareTile(
              p,
              icon: Icons.wb_sunny_outlined,
              title: '情绪低落时先做性价比最高的自救几件事',
              desc: '动起来、多见户外自然光、今晚按时早睡、找信赖的人倾诉。',
              onAddTodo: () {
                store.addUserTodo('外出见光散步 15 分钟', adviceId: 113);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入今日专注清单')));
              },
            ),

          if (advice680 != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.action.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.action.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_in_talk, size: 18, color: p.action),
                      const SizedBox(width: 8),
                      Text(
                        '国家免费心理援助热线',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.action),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '要人陪着说话请拨打 12356（全国心理危机干预热线）；青少年学生拨打 12355。无需独自硬扛。',
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: p.inkSub),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: p.action),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.call, size: 15),
                      label: const Text('一键拨打 12356 心理援助'),
                      onPressed: () => launchUrl(Uri.parse('tel:12356')),
                    ),
                  ),
                ],
              ),
            ),
        ],

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.action,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成今日状态记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildAdviceCareTile(
    AppPalettes p, {
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onAddTodo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: p.action),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 12, height: 1.4, color: p.inkSub)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: Icon(Icons.add, size: 14, color: p.action),
              label: Text('加入今日待办', style: TextStyle(fontSize: 12, color: p.action)),
              onPressed: onAddTodo,
            ),
          ),
        ],
      ),
    );
  }
}
