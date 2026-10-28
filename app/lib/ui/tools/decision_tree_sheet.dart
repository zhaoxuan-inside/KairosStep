import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

/// 独立决策树向导与清单生成器面板
class DecisionTreeSheet extends StatefulWidget {
  const DecisionTreeSheet({super.key, this.initialTab = 0});

  final int initialTab;

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DecisionTreeSheet(initialTab: initialTab)),
    );
  }

  @override
  State<DecisionTreeSheet> createState() => _DecisionTreeSheetState();
}

class _DecisionTreeSheetState extends State<DecisionTreeSheet> {
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
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
          '离线决策树向导',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _navPill('分支决策树', 0, p),
                  const SizedBox(width: 8),
                  _navPill('核心清单生成器', 1, p),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: const [
                  _DecisionTreePanel(),
                  _ChecklistGenPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navPill(String title, int idx, AppPalettes p) {
    final on = _currentTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentTab = idx);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.ink : p.pillBg,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? p.surface : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. 决策树向导面板 (Decision Tree Engine)
// ============================================================================

class _DecisionTreePanel extends StatefulWidget {
  const _DecisionTreePanel();

  @override
  State<_DecisionTreePanel> createState() => _DecisionTreePanelState();
}

class _DecisionTreePanelState extends State<_DecisionTreePanel> {
  String _selectedTreeId = 'labor';
  final Map<String, int> _answers = {};

  static const _trees = [
    (
      id: 'labor',
      name: '劳动争议 · 辞退与赔偿',
      desc: '遭遇违法解除、降薪调岗、逼迫离职或不续签时的维权路径推演',
      nodes: [
        (
          question: '公司是何种方式要求您离开的？',
          options: [
            '书面下达《解除劳动合同通知书》',
            'HR口头通知谈话，要求自己主动提交辞职信',
            '违法调岗降薪到偏远岗位逼迫自行离职',
            '合同到期公司不再续签',
          ],
        ),
        (
          question: '您在公司入职时是否依法签订了书面劳动合同？',
          options: [
            '入职 1 个月内已正常签订',
            '超过 1 个月未签，但有工作证/工资流水',
            '从未签订，且全部微信转账发工资',
          ],
        ),
        (
          question: '您在公司连续工作年限（以社保/入职记录为准）？',
          options: ['不满 6 个月', '6 个月至 1 年', '1 年至 3 年', '3 年以上'],
        ),
      ],
      conclusions: [
        '【违法解除 2N 赔偿】公司直接违法解除属于《劳动合同法》第48条情形，您有权索赔每工作满一年支付2个月工资的赔偿金（2N）。绝对不要在自愿离职单上签字！',
        '【被逼迫自离应对】HR口头威逼切勿冲动写辞职信！必须书面文字回复：“本人不同意降薪调岗/解除，正在正常履行工作职责”。保留工卡门禁记录。',
        '【双倍工资赔偿金】入职超过1个月未签劳动合同，可主张自第二个月起最多11个月的双倍工资差额！同时收集考勤表、工牌、工作群聊天记录。',
        '【到期不续签经济补偿 N】合同到期除非公司维持或提高待遇员工拒绝，否则公司应依法支付 N 个月工资补偿。保留续签谈话录音。',
      ],
      evidenceTips: [
        '工作证明（工牌、门禁卡、飞书/钉钉组织架构截图）',
        '工资流水（银行近 12 个月代发工资交易明细盖章）',
        '辞退证据（解除通知书原件、HR 谈话录音、通知邮件）',
        '考勤记录（打卡导出表、加班审批截图）',
      ],
    ),
    (
      id: 'rent',
      name: '房屋租赁 · 押金与违约退还',
      desc: '房东恶意扣押金、中途驱赶或违约涨租时的维权要点',
      nodes: [
        (
          question: '争议属于下列哪种情形？',
          options: [
            '合同到期正常交房，房东以微小磨损为由拒绝退还押金',
            '租期未满房东要卖房/自住要求提前搬离',
            '房屋漏水或设施严重损坏，房东拒绝维修影响居住',
            '二房东跑路或中介爆雷',
          ],
        ),
        (
          question: '当初入住时是否有留存交接记录？',
          options: [
            '有全屋高清录像与水电燃气底数交接单',
            '仅拍照了水电表，未仔细拍墙面磨损',
            '完全没有留下任何交接凭证',
          ],
        ),
      ],
      conclusions: [
        '【正常折旧不可扣押金】《民法典》明确规定房屋及设施自然老化折旧由出租人承担。出示入住交接视频，书面送达催告函，拒不退还向租赁协会及法院提起小额诉讼。',
        '【房东违约应赔付违约金】房东提前解约属单方违约，不仅必须退还全部剩余租金和押金，还应按合同赔偿违约金（通常为1个月租金），并承担合理搬家费。',
        '【房屋严重漏水退租权】房屋有危害健康或无法居住的瑕疵，经催告未在合理期限维修，承租人享有法定解除权，可免责解除并全额退还押金。',
        '【转租中介纠纷】核查大房东授权委托书，如系转租中介违约，向住建局物业管理科、12345市民热线进行投诉，同步去派出所调解。',
      ],
      evidenceTips: [
        '租房合同文本原件及签字页',
        '押金与各期租金转账电子回单',
        '入住交房与退租时的全屋视频记录',
        '与房东关于报修、退押金的完整微信聊天记录',
      ],
    ),
    (
      id: 'injury',
      name: '工伤认定 · 上班受伤与车祸',
      desc: '上下班途中交通事故、工作时间工作场所受伤的定责与待遇索赔',
      nodes: [
        (
          question: '受伤发生的具体时空情境？',
          options: [
            '上下班必经路线途中，发生非本人主要责任的交通事故',
            '在工作时间和工作场所内，因工作原因受到事故伤害',
            '因公外出期间，由于工作原因受到伤害或下落不明',
            '在工作岗位上突发疾病在48小时之内经抢救无效死亡',
          ],
        ),
        (
          question: '用人单位是否为您缴纳了工伤保险？',
          options: [
            '正常足额缴纳社保（含工伤险）',
            '单位未依法缴纳工伤保险',
            '属于第三方劳务派遣或外包用工',
          ],
        ),
      ],
      conclusions: [
        '【上下班交通事故工伤】必须取得交警部门出具的事故认定书（本人承担同等责任、次要责任或无责任）。自事故发生之日起 30 日内，用人单位应申请工伤认定；单位不申请的，职工本人或近亲属 1 年内可直接向人社局申请！',
        '【工作岗位事故伤害】第一时间告知主管并去正规公立医院就医，病历明确写明“因工受伤”，要求单位 30 天内申请工伤。保留现场目击证人证言。',
        '【单位未缴工伤险责任全包】《工伤保险条例》第62条明确：未参保期间发生工伤的，由该用人单位按照本条例规定的工伤保险待遇项目和标准支付全部费用！',
        '【劳务派遣工伤连带】由派遣单位申请工伤认定，用工单位协助，双方承担法定义务与连带赔偿责任。',
      ],
      evidenceTips: [
        '公安交管部门出具的《道路交通事故认定书》（非主责证明）',
        '医疗机构首诊病历原件（须记录为工伤起因）与发票清单',
        '考勤打卡记录与上下班通勤合理路线地图',
        '劳动合同或事实劳动关系证明材料',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final tree = _trees.firstWhere((t) => t.id == _selectedTreeId);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in _trees)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.name),
                    selected: _selectedTreeId == t.id,
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTreeId = t.id;
                          _answers.clear();
                        });
                      }
                    },
                    selectedColor: p.action,
                    backgroundColor: p.surface,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedTreeId == t.id ? FontWeight.w700 : FontWeight.w500,
                      color: _selectedTreeId == t.id ? Colors.white : p.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tree.desc, style: TextStyle(fontSize: 12, color: p.inkSub)),
              const SizedBox(height: 14),
              for (int qIdx = 0; qIdx < tree.nodes.length; qIdx++) ...[
                Text(
                  'Q${qIdx + 1}: ${tree.nodes[qIdx].question}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink),
                ),
                const SizedBox(height: 8),
                for (int oIdx = 0; oIdx < tree.nodes[qIdx].options.length; oIdx++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _answers['$qIdx'] = oIdx;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _answers['$qIdx'] == oIdx ? p.action.withValues(alpha: 0.15) : p.pillBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _answers['$qIdx'] == oIdx ? p.action : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _answers['$qIdx'] == oIdx ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 15,
                              color: _answers['$qIdx'] == oIdx ? p.action : p.inkMute,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tree.nodes[qIdx].options[oIdx],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _answers['$qIdx'] == oIdx ? p.action : p.ink,
                                  fontWeight: _answers['$qIdx'] == oIdx ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Builder(
          builder: (context) {
            final firstAns = _answers['0'] ?? 0;
            final conclusion = tree.conclusions[firstAns.clamp(0, tree.conclusions.length - 1)];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel_outlined, size: 16, color: p.amber),
                      const SizedBox(width: 6),
                      Text('维权结论与法理指引', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.amber)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(conclusion, style: TextStyle(fontSize: 12.5, color: p.ink, height: 1.5)),
                  const SizedBox(height: 12),
                  Text('必留存法庭证据清单：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink)),
                  const SizedBox(height: 6),
                  for (final ev in tree.evidenceTips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 13, color: p.emerald),
                          const SizedBox(width: 6),
                          Expanded(child: Text(ev, style: TextStyle(fontSize: 11.5, color: p.inkSub))),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ============================================================================
// 2. 清单生成器面板 (Checklist Generator)
// ============================================================================

class _ChecklistGenPanel extends StatefulWidget {
  const _ChecklistGenPanel();

  @override
  State<_ChecklistGenPanel> createState() => _ChecklistGenPanelState();
}

class _ChecklistGenPanelState extends State<_ChecklistGenPanel> {
  final Map<String, bool> _checks = {};

  static const _checklists = [
    (
      category: '租房交割验收清单',
      items: [
        '拍照录像全屋水表、电表、燃气表初始读数',
        '测试所有水龙头出水压力与下水道排水是否通畅',
        '开机测试空调冷暖制热及过滤网卫生状态',
        '测试卫生间马桶冲水与周边是否存在渗漏暗渍',
        '检查门窗锁具牢固性并要求房东在起租前更换锁芯',
      ],
    ),
    (
      category: '入职报到避坑清单',
      items: [
        '确认劳动合同主体与发放 Offer 的公司完全一致',
        '核对试用期薪资不得低于转正薪资的 80%',
        '确认劳动合同明确载明五险一金缴纳基数与比例',
        '拒签任何放弃社保、自愿加班不计薪的补充协议',
        '保留签字盖章后的劳动合同原件一份自存',
      ],
    ),
    (
      category: '就医急诊随身包清单',
      items: [
        '医保卡原件 / 手机开通医保电子凭证',
        '既往重要门诊病历、出院小结与检查报告单',
        '目前正在服用的所有药品包装盒照片或药单',
        '身份证原件与医保关联银行卡',
        '备用充电宝、数据线与少量现金零钱',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final group in _checklists) ...[
          Text(group.category, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              children: [
                for (final item in group.items)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: p.emerald,
                    value: _checks[item] ?? false,
                    title: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        color: (_checks[item] ?? false) ? p.inkMute : p.ink,
                        decoration: (_checks[item] ?? false) ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    onChanged: (v) => setState(() => _checks[item] = v ?? false),
                    secondary: IconButton(
                      icon: Icon(Icons.add_task, size: 16, color: p.action),
                      tooltip: '加入自建待办',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        store.addUserTodo('【${group.category}】$item', note: '来自决策清单生成器');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已将“$item”加入专属待办'), duration: const Duration(seconds: 2)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
