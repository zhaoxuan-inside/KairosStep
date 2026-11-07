import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import '../detail/advice_detail_sheet.dart';

/// 全局一键紧急模式全屏看板
///
/// 严格遵循 DESIGN.md 规约：
/// - 纯色块表达（朱红 #E33A22 紧急态、曜石黑 #121212 底色）；
/// - 彻底禁用 Emoji，使用自绘细线图标；
/// - 极速直拨大按钮（120、110、12356）+ 4 选 1 突发自救速查卡 + 紧急联系人。
class EmergencySheet extends StatefulWidget {
  const EmergencySheet({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, anim, secondAnim) => const EmergencySheet(),
        transitionsBuilder: (context, anim, secondAnim, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencyGuideItem {
  const _EmergencyGuideItem({
    required this.title,
    required this.sub,
    required this.steps,
    this.badge,
  });

  final String title;
  final String sub;
  final List<String> steps;
  final String? badge;
}

class _EmergencySheetState extends State<EmergencySheet> {
  int _selectedTab = 0;
  String _searchQuery = '';

  static const List<_EmergencyGuideItem> _allGuides = [
    _EmergencyGuideItem(
      title: '突发胸痛 / 疑似卒中',
      sub: '黄金抢救窗口 · 切勿盲目服药',
      badge: '心脑急危',
      steps: [
        '立刻让患者平卧或半卧，解开领扣，绝对不要用力摇晃或扶其走动。',
        '卒中 FAST 简易识别：看脸对称否、双臂平举是否单侧下垂、说话是否含糊。',
        '立刻拨打 120，清晰告知：“疑似心梗/脑卒中、具体小区单元楼层”。',
        '在救护车到达前，除医生明确指导外，切勿盲目喂水或乱服阿司匹林/硝酸甘油。',
      ],
    ),
    _EmergencyGuideItem(
      title: '异物卡喉 / 海姆立克',
      sub: '黄金 4 分钟 · 拍背加腹部冲击 · 意识丧失立刻 CPR',
      badge: '呼吸梗阻',
      steps: [
        '区分意识与梗阻程度：若患者能咳嗽或说话，鼓励其用力自主咳嗽，切勿拍背干扰；若无法发声、不能咳嗽、口唇发绀，立刻开展急救。',
        '掌根拍背 5 次：协助患者身体前倾，站在其侧后方，用一只手的掌根在两肩胛骨之间用力向前上方叩击 5 次。',
        '腹部冲击 5 次（成人与 1 岁以上）：站在身后，一手握拳拇指侧抵住肚脐上方两横指处，另一手抱拳向内向上快速冲击 5 次。',
        '拍背 5 次与冲击 5 次循环；患者一旦昏迷倒地，立即呼救打 120 并立刻开始心肺复苏（CPR），每次人工呼吸前检查口腔并取出可见异物。',
      ],
    ),
    _EmergencyGuideItem(
      title: '火灾烟雾 / 中毒逃生',
      sub: '低姿撤离 · 拒绝湿毛巾侥幸',
      badge: '火险中毒',
      steps: [
        '火灾浓烟致死率超 80%，摸门把手发烫切勿开门，立即堵死门缝退守有窗房间。',
        '撤离时身体压低至 50 厘米以下（离地面最近处氧气最足、温度最低）。',
        '不要贪恋任何财物，一旦逃出绝对不要重返火场。',
        '发生燃气泄漏或一氧化碳中毒时，严禁开灯开开关，轻开门窗后到室外拨打 119。',
      ],
    ),
    _EmergencyGuideItem(
      title: '严重烫伤 / 烧伤急救',
      sub: '冲-脱-泡-盖-送 · 忌涂牙膏酱油',
      badge: '创伤救护',
      steps: [
        '【冲】立即用 15~20℃ 流动冷水轻柔冲洗创面 15~30 分钟，迅速带走热量止痛。',
        '【脱】在冷水中小心剪开或除去衣物，若衣物粘连表皮切勿强行撕拉，保留粘连部分。',
        '【泡】若疼痛剧烈，可继续将受伤部位浸泡在洁净冷水中 10~30 分钟。',
        '【盖与送】用清洁无菌纱布或干净棉布轻盖创面；切勿涂抹牙膏、酱油、香油或草药；大面积烫伤尽快送医。',
      ],
    ),
    _EmergencyGuideItem(
      title: '遭遇暴力冲突 / 欠薪取证',
      sub: '人身安全第一 · 证据链静默留存',
      badge: '人身劳资',
      steps: [
        '遭遇人身威胁或非法拘禁时，以人身安全为最高优先级，切勿激怒施暴者。',
        '在衣袋内开启手机长按录音或视频后台留存。',
        '劳资冲突/被逼辞职时：绝对不要在“自愿离职单”上签字，文字回复“不同意解除”。',
        '事后第一时间去公立医院开具伤情诊断证明，并保留全部门诊病历与费用发票。',
      ],
    ),
    _EmergencyGuideItem(
      title: '高温中暑 / 热射病',
      sub: '先降温后转运 · 清醒补淡盐水 · 昏迷绝不喂水',
      badge: '夏季酷暑',
      steps: [
        '脱离高温环境：迅速移至阴凉通风处，解开衣扣、平卧并将双脚稍垫高，保持呼吸道通畅。',
        '强力物理降温：青壮年优先冷水浸泡，老人或有基础病者全身喷水或湿毛巾敷贴并强力扇风；在颈部、腋下、腹股沟放置冰袋。',
        '科学小口补水：只要患者神志清醒，少量多次喝凉淡盐水或电解质运动饮料（每小时 500~1000ml），切勿猛灌，严禁饮酒或高糖饮料。',
        '识别热射病危象：体温超 40℃、皮肤灼热无汗、谵妄抽搐或叫不醒时立即打 120！遵循“先降温后转运”，昏迷者严禁给水！',
      ],
    ),
  ];

  /// 根据当前环境月份与用户画像对自救速查指南动态排序
  List<_EmergencyGuideItem> _getRankedGuides(UserProfile profile) {
    final month = DateTime.now().month;
    final isSummer = month >= 6 && month <= 9;
    final isColdSeason = month >= 10 || month <= 3;

    final list = List<_EmergencyGuideItem>.from(_allGuides);
    list.sort((a, b) {
      double scoreA = 50.0;
      double scoreB = 50.0;

      // 评估 A
      scoreA += _evalGuideScore(a, profile, isSummer, isColdSeason);
      // 评估 B
      scoreB += _evalGuideScore(b, profile, isSummer, isColdSeason);

      return scoreB.compareTo(scoreA);
    });
    return list;
  }

  double _evalGuideScore(_EmergencyGuideItem g, UserProfile p, bool isSummer, bool isColdSeason) {
    double s = 50.0;
    if (g.title.contains('胸痛') || g.title.contains('卒中')) {
      if (p.hasHypertension) s += 120.0;
      if (p.hasDiabetes) s += 40.0;
      if (p.age >= 45) s += 30.0;
      if (isColdSeason) s += 40.0; // 冬春寒冷季节血管痉挛高发
    } else if (g.title.contains('中暑') || g.title.contains('热射病')) {
      if (isSummer) {
        s += 60.0;
      } else if (isColdSeason) {
        s -= 150.0; // 冬天极低优先级
      }
    } else if (g.title.contains('海姆立克') || g.title.contains('卡喉')) {
      if (p.hasChildren || p.childAgeStage == 'infant') s += 80.0;
    } else if (g.title.contains('火灾') || g.title.contains('中毒')) {
      if (p.hasPipedGas) s += 30.0;
      if (isColdSeason) s += 30.0; // 冬天门窗紧闭一氧化碳高发
    } else if (g.title.contains('暴力') || g.title.contains('欠薪')) {
      if (p.roles.contains('上班族')) s += 25.0;
    }
    return s;
  }

  /// 对备查库条目依据环境和画像动态重排
  List<Advice> _rankEmergencyAdvices(List<Advice> rawList, UserProfile p) {
    final month = DateTime.now().month;
    final isSummer = month >= 6 && month <= 9;
    final isColdSeason = month >= 10 || month <= 3;

    final scored = rawList.map((a) {
      double s = 50.0;
      final text = '${a.title} ${a.chapter} ${a.tags.join(" ")}'.toLowerCase();

      if (text.contains('胸痛') || text.contains('心梗') || text.contains('卒中') || text.contains('心脏骤停')) {
        if (p.hasHypertension) s += 120.0;
        if (p.hasDiabetes) s += 40.0;
        if (p.age >= 45) s += 35.0;
        if (isColdSeason) s += 40.0;
      }
      if (text.contains('中暑') || text.contains('热射病') || text.contains('高温天气')) {
        if (isSummer) {
          s += 60.0;
        } else if (isColdSeason) {
          s -= 120.0;
        }
      }
      if (text.contains('工伤') || text.contains('被撞') || text.contains('车祸') || text.contains('骨折')) {
        if (p.hasCar || p.hasTwowheeler) s += 50.0;
        if (p.roles.contains('上班族')) s += 30.0;
      }
      if (text.contains('跌倒') || text.contains('防跌倒') || text.contains('老人')) {
        if (p.hasAgingParents) s += 70.0;
      }
      if (text.contains('异物') || text.contains('呛咳') || text.contains('海姆立克')) {
        if (p.hasChildren) s += 60.0;
      }
      return (advice: a, score: s);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.advice).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = storeOf(context);
    final contacts = store.emergencyContacts;

    return Scaffold(
      backgroundColor: const Color(0xFF141312),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // 顶部导航：朱红醒目标签 + 安全退出
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE33A22),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppHairlineIcons.emergencyBell(color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      const Text(
                        '紧急模式 · 离线全速就绪',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFCCCAC7),
                    backgroundColor: const Color(0xFF262524),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: AppHairlineIcons.cross(color: const Color(0xFFCCCAC7), size: 12),
                  label: const Text('退出', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ---- 第一行：极速直拨大按钮 (120 / 110 / 12356) ----
            Row(
              children: [
                Expanded(
                  child: _dialCard(
                    numStr: '120',
                    label: '医疗急救',
                    color: const Color(0xFFE33A22),
                    onTap: () => _dialAlert(context, '120', '医疗急救'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dialCard(
                    numStr: '110',
                    label: '人身报警',
                    color: const Color(0xFF2A72DE),
                    onTap: () => _dialAlert(context, '110', '人身报警'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dialCard(
                    numStr: '12356',
                    label: '心理危机',
                    color: const Color(0xFFBC924C),
                    onTap: () => _dialAlert(context, '12356', '自杀心理危机干预'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ---- 第二行：突发自救速查指南 (环境与画像智能加权排序) ----
            Builder(
              builder: (context) {
                final rankedGuides = _getRankedGuides(store.profile);
                final currentIdx = _selectedTab.clamp(0, rankedGuides.length - 1);
                final activeGuide = rankedGuides[currentIdx];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '突发情境自救速查',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBC924C).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '画像环境智能优选',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFFBC924C), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < rankedGuides.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedTab = i);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: currentIdx == i
                                        ? const Color(0xFFE33A22)
                                        : const Color(0xFF262524),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        rankedGuides[i].title,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: currentIdx == i ? FontWeight.w700 : FontWeight.w400,
                                          color: currentIdx == i ? Colors.white : const Color(0xFFA8A5A0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1E1D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF383533)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  activeGuide.sub,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFBC924C),
                                  ),
                                ),
                              ),
                              if (activeGuide.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE33A22).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    activeGuide.badge!,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFE33A22), fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < activeGuide.steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF33312F),
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      activeGuide.steps[i],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFECECEC),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),

            // ---- 第三行：预设紧急联系人 ----
            Row(
              children: [
                Text(
                  '预设紧急联系人',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showAddContactModal(context, store),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262524),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Text(
                      '添加联系人',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2A72DE), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (contacts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1E1D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF383533)),
                ),
                child: Center(
                  child: Text(
                    '暂未设置本地紧急联系人，建议预设父母/伴侣电话',
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ),
              )
            else
              for (var i = 0; i < contacts.length; i++)
                _contactCard(context, contacts[i], () => store.removeEmergencyContact(i)),
            const SizedBox(height: 24),

            // ---- 第四行：突发与急救事件备查库（仅在突发状况时按需检索） ----
            Row(
              children: [
                Text(
                  '突发与急救条目备查库',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE33A22).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: const Color(0xFFE33A22).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    '仅突发时使用',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFE33A22),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1E1D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF383533)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: TextField(
                style: const TextStyle(fontSize: 12.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '搜索突发急救（如：中暑、海姆立克、烫伤、骨折、蛇咬伤）',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 16),
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final ranked = _rankEmergencyAdvices(store.emergencyAdvices, store.profile);
                final list = ranked.where((a) {
                  if (_searchQuery.isEmpty) return true;
                  final text = '${a.title} ${a.chapter} ${a.tags.join(" ")}'.toLowerCase();
                  return text.contains(_searchQuery);
                }).toList();

                if (list.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1E1D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '未找到相关急救条目',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  );
                }

                // 展示前 10 条（或搜索结果）
                final displayList = _searchQuery.isEmpty ? list.take(8).toList() : list;
                return Column(
                  children: [
                    for (final a in displayList)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1E1D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF383533)),
                        ),
                        // ListTile 需自有 Material 承载墨水涟漪，否则被外层
                        // 带背景色的 Container 遮挡并触发框架断言
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            title: Text(
                              a.title,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE33A22).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      a.timingBadge.isNotEmpty ? a.timingBadge : '突发应急',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFFE33A22),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      a.chapter,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Color(0xFF838280),
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              showAdviceDetail(context, a.id);
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialCard({
    required String numStr,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              numStr,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, EmergencyContact c, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1E1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF383533)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2A72DE).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              c.relation,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2A72DE)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _dialAlert(context, c.phone, '${c.relation} ${c.name}'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(c.phone, style: const TextStyle(fontSize: 11.5, color: Color(0xFFA8A5A0))),
                        const SizedBox(width: 6),
                        const Icon(Icons.phone, size: 12, color: Color(0xFF2A72DE)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: AppHairlineIcons.cross(color: const Color(0xFF838280), size: 12),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  void _dialAlert(BuildContext context, String numStr, String name) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1E1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('拨打 $numStr ($name)', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          '将直接调用系统电话拨打 $numStr。请在接通后保持冷静，清晰说明您所在具体地点与事件要点。',
          style: const TextStyle(color: Color(0xFFCCCAC7), fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Color(0xFF838280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE33A22)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse('tel:$numStr');
              bool launched = false;
              try {
                // 优先以系统外部拨号应用方式调起
                launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                launched = false;
              }
              if (!launched) {
                try {
                  launched = await launchUrl(uri);
                } catch (_) {
                  launched = false;
                }
              }
              if (!launched && context.mounted) {
                await Clipboard.setData(ClipboardData(text: numStr));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFE33A22),
                    content: Text(
                      '当前设备无法直接调用拨号，已将紧急号码 $numStr 复制到剪贴板',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text('立即呼叫', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddContactModal(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 键盘弹出时由内容区自行避让，避免路由动画期间 IME 与弹层同时改变约束
      builder: (_) => _AddContactSheet(store: store),
    );
  }
}

/// 添加紧急联系人弹层：与全局弹层视觉一致（surface 底 + 圆角 24 + 胶囊字段）。
///
/// 两条录入路径：系统通讯录选择器（用户主动挑选单个联系人，无需通讯录权限）
/// 与手动填写；姓名与电话为必填，缺失时就地标红提示。
class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.store});

  final AppStore store;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  static const _contactsChannel = MethodChannel('kairostep/contacts');

  final _nameCtl = TextEditingController();
  final _relCtl = TextEditingController();
  final _phoneCtl = TextEditingController();

  bool _nameError = false;
  bool _phoneError = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _relCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    HapticFeedback.selectionClick();
    try {
      // 系统联系人选择器：仅返回用户主动选中的那一条，无需 READ_CONTACTS 权限
      final picked =
          await _contactsChannel.invokeMapMethod<String, dynamic>(
        'pickContact',
      );
      if (!mounted || picked == null) return;
      final name = (picked['name'] as String? ?? '').trim();
      final phone = (picked['phone'] as String? ?? '').trim();
      setState(() {
        if (name.isNotEmpty) {
          _nameCtl.text = name;
          _nameError = false;
        }
        if (phone.isNotEmpty) {
          _phoneCtl.text = phone;
          _phoneError = false;
        }
      });
    } on MissingPluginException {
      _fallbackNoContacts();
    } on PlatformException {
      _fallbackNoContacts();
    } catch (_) {
      _fallbackNoContacts();
    }
  }

  void _fallbackNoContacts() {
    // 桌面端/模拟器无通讯录应用：降级为手动填写
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前设备无法打开通讯录，请手动填写')),
    );
  }

  void _submit() {
    final name = _nameCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _nameError = name.isEmpty;
        _phoneError = phone.isEmpty;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    widget.store.addEmergencyContact(
      name,
      phone,
      _relCtl.text.trim().isEmpty ? '亲属' : _relCtl.text.trim(),
    );
    Navigator.of(context).pop();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  Icon(Icons.person_add_alt_1_rounded, color: p.rose, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '添加本地紧急联系人',
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
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.action.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  minimumSize: const Size(double.infinity, 42),
                ),
                onPressed: _pickFromContacts,
                icon: Icon(Icons.contacts_rounded, size: 16, color: p.action),
                label: Text(
                  '从通讯录选择',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.action,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '仅读取你主动选中的那一条，数据不出本机',
                style: TextStyle(fontSize: 10.5, color: p.inkMute),
              ),
              const SizedBox(height: 14),
              _field(
                p,
                controller: _nameCtl,
                hint: '姓名',
                error: _nameError,
                errorText: '请填写姓名',
                onChanged: () {
                  if (_nameError) setState(() => _nameError = false);
                },
              ),
              const SizedBox(height: 12),
              _field(p, controller: _relCtl, hint: '关系'),
              const SizedBox(height: 12),
              _field(
                p,
                controller: _phoneCtl,
                hint: '电话号码',
                keyboardType: TextInputType.phone,
                error: _phoneError,
                errorText: '请填写电话号码',
                onChanged: () {
                  if (_phoneError) setState(() => _phoneError = false);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.action,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    '保存到本机',
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

  Widget _field(
    AppPalettes p, {
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool error = false,
    String? errorText,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged?.call(),
          style: TextStyle(fontSize: 13.5, color: p.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: p.inkMute),
            filled: true,
            fillColor: p.pillBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error ? p.rose : p.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error ? p.rose : p.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error ? p.rose : p.action),
            ),
          ),
        ),
        if (error && errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText,
              style: TextStyle(fontSize: 11.5, color: p.rose),
            ),
          ),
      ],
    );
  }
}
