import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

/// 离线决策树、清单生成器与精算微工具中枢
///
/// 严格遵循 DESIGN.md 规约：
/// - 纯色块表达状态、温暖纸质质感；
/// - 彻底禁用 Emoji，使用自绘细线图标；
/// - 纯单机数学计算与条件分支推演。
class ToolsSheet extends StatefulWidget {
  const ToolsSheet({super.key, this.initialTab = 0});

  final int initialTab;

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ToolsSheet(initialTab: initialTab)),
    );
  }

  @override
  State<ToolsSheet> createState() => _ToolsSheetState();
}

class _ToolsSheetState extends State<ToolsSheet> {
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
          '决策树与离线工具箱',
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
                  _navPill('决策树向导', 0, p),
                  const SizedBox(width: 8),
                  _navPill('清单生成器', 1, p),
                  const SizedBox(width: 8),
                  _navPill('精算微工具', 2, p),
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
                  _CalculatorsPanel(),
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
// 1. 决策树向导 (Decision Tree Engine)
// ============================================================================

class _DecisionTreePanel extends StatefulWidget {
  const _DecisionTreePanel();

  @override
  State<_DecisionTreePanel> createState() => _DecisionTreePanelState();
}

class _DecisionTreePanelState extends State<_DecisionTreePanel> {
  int? _activeTreeIndex;
  int _step = 0;
  final Map<int, int> _answers = {};

  static const _trees = [
    (
      title: '试用期被突发辞退 / 逼迫辞职',
      desc: '辞退通知书 · 个人原因陷阱 · 证据保全 · 经济补偿金标准',
      questions: [
        (
          q: '公司是否出具了盖有公章的书面《解除劳动合同通知书》？',
          options: ['是，已出具书面通知', '否，仅口头/微信通知我走人'],
        ),
        (
          q: 'HR 是否要求你签署“因个人原因申请离职”的表格？',
          options: ['是，催促我今天必须签', '否，未要求签署'],
        ),
        (
          q: '你是否已按时出勤且有打卡、工作成果、绩效考核记录？',
          options: ['是，均有留存证据', '否，证据较零散'],
        ),
      ],
      resultAction: '【红线禁令】绝对不要签署任何写有“自愿离职”、“个人原因辞职”的文件！主动回复书面声明：“本人不同意违法解除劳动关系，愿意继续履职”。',
      evidenceItems: [
        '工牌、劳动合同原件、社保缴费证明',
        '近 6 个月钉钉/飞书打卡记录截图、考勤汇总',
        '绩效考核合格证据、主管工作认可聊天记录',
        'HR 或领导要求离职的录音、微信沟通记录截图',
      ],
      lawQuote: '依据《劳动合同法》第 21、47、87 条，用人单位在试用期解除需证明不符合录用条件；违法解除应支付双倍赔偿金（2N）。可拨打 12333 申请调解与劳动仲裁。',
    ),
    (
      title: '老人被推销高额理财 / 以房养老',
      desc: '非标理财 · 抵押贷款风险 · 三问一打话术',
      questions: [
        (
          q: '对方是否宣称“国家扶持养老工程 / 年化收益率超 8% / 保本保息”？',
          options: ['是，承诺高额固定利息', '否，正常银行理财产品'],
        ),
        (
          q: '对方是否要求抵押房产证，或签署委托房屋处分公证书？',
          options: ['是，涉及房屋抵押/公证', '否，未涉及房产'],
        ),
      ],
      resultAction: '【最高红色警报】我国正规金融机构从未推出过向散户承诺保本且超 8% 的“以房养老”理财项目！立刻带老人离开推销现场，严禁抵押房产。',
      evidenceItems: [
        '推销宣传单页、合同草案复印件',
        '推销人员名片、机构工商执照全称',
        '转账银行流水、POS 机刷卡底单',
      ],
      lawQuote: '最高人民法院已将“套路贷以房养老”定性为非法集资与诈骗犯罪。发现被骗立即拨打 110，并带老人到不动产登记中心办理房屋异议登记，锁定产权。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);

    if (_activeTreeIndex == null) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trees.length,
        itemBuilder: (ctx, i) {
          final t = _trees[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _activeTreeIndex = i;
                _step = 0;
                _answers.clear();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppHairlineIcons.tree(color: p.action, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Text('进入向导', style: TextStyle(fontSize: 11, color: p.action, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(t.desc, style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.4)),
                ],
              ),
            ),
          );
        },
      );
    }

    final tree = _trees[_activeTreeIndex!];
    final isDone = _step >= tree.questions.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _activeTreeIndex = null),
              child: Row(
                children: [
                  AppHairlineIcons.cross(color: p.inkMute, size: 12),
                  const SizedBox(width: 4),
                  Text('返回列表', style: TextStyle(fontSize: 11, color: p.inkMute)),
                ],
              ),
            ),
            const Spacer(),
            Text(
              isDone ? '评估完成' : '步骤 ${_step + 1} / ${tree.questions.length}',
              style: TextStyle(fontSize: 11, color: p.inkSub, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isDone) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tree.questions[_step].q,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                for (var optIdx = 0; optIdx < tree.questions[_step].options.length; optIdx++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: p.hairline),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _answers[_step] = optIdx;
                          _step++;
                        });
                      },
                      child: Text(
                        tree.questions[_step].options[optIdx],
                        style: TextStyle(fontSize: 13, color: p.ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ] else ...[
          // 结果面板 (Result Sheet)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.error.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppHairlineIcons.shield(color: p.error, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '即刻行动指示',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.error),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tree.resultAction,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink, height: 1.5),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text('必须保全的证据清单（点击转入待办）', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final ev in tree.evidenceItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('· ', style: TextStyle(fontWeight: FontWeight.w900, color: p.action)),
                        Expanded(
                          child: Text(ev, style: TextStyle(fontSize: 12, color: p.inkSub, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.ink,
                      foregroundColor: p.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: AppHairlineIcons.check(color: p.surface, size: 12),
                    label: const Text('一键把证据清单加入待办', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      for (final ev in tree.evidenceItems) {
                        store.addUserTodo('【证据固定】$ev', note: '来自决策树向导');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已批量加入今日待办清单！'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: p.canvas, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    tree.lawQuote,
                    style: TextStyle(fontSize: 11, color: p.inkMute, height: 1.4),
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

// ============================================================================
// 2. 清单生成器 (Checklist Generator)
// ============================================================================

class _ChecklistGenPanel extends StatelessWidget {
  const _ChecklistGenPanel();

  static const _templates = [
    (
      title: '入职 7 天劳动合规排查清单',
      items: [
        '确认已签署书面劳动合同原件，并由公司盖章后自己拿回一份',
        '核对合同约定的基本工资、试用期长度、岗位与录用通知书一致',
        '确认社保公积金按实际工资基数足额缴纳（非按最低基数偷逃）',
        '备份入职录用通知、岗位职责说明书与第一天考勤记录',
      ],
    ),
    (
      title: '家庭老人防骗与财产安全季度排查',
      items: [
        '检查老人智能手机短信息，关闭免密支付与异常借贷授权',
        '核对老人房产证是否在身边安全存放（防抵押贷款套路）',
        '排查家里是否有来路不明的高价保健品、磁疗床垫或养老理财收据',
        '带老人重温防诈三问一打原则：只要转账买养老理财，先打电话给子女',
      ],
    ),
    (
      title: '家庭急救包与安全隐患月检',
      items: [
        '检查厨房燃气软管是否为防鼠咬金属包覆管、接口是否紧固',
        '排查急救药箱中硝酸甘油、碘伏、灭菌纱布有效期',
        '检查窗户高空限位器螺丝是否松动、防盗网逃生窗口钥匙位置',
        '电动自行车电池绝对不进楼、不入户充电',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (ctx, i) {
        final t = _templates[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final it in t.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: p.action, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(it, style: TextStyle(fontSize: 12, color: p.inkSub, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: p.hairline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: AppHairlineIcons.check(color: p.action, size: 12),
                  label: const Text('一键生成到待办清单', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    for (final it in t.items) {
                      store.addUserTodo(it, note: '来自【${t.title}】');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已成功为【${t.title}】生成 ${t.items.length} 项待办！')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// 3. 离线精算微工具箱 (Calculators)
// ============================================================================

class _CalculatorsPanel extends StatefulWidget {
  const _CalculatorsPanel();

  @override
  State<_CalculatorsPanel> createState() => _CalculatorsPanelState();
}

class _CalculatorsPanelState extends State<_CalculatorsPanel> {
  // APR 照妖镜
  final int _periods = 12;
  double _feeRate = 0.6; // 月费率 %

  // 保障缺口
  double _annualExpense = 8; // 万
  double _liabilities = 60; // 万
  final double _supportYears = 15; // 年

  double get realApr {
    // 粗估真实年化利率：按等额本息反推 IRR 近似公式 APR ≈ 2 * N / (N + 1) * 名义年费率
    final nominalYearly = _feeRate * 12;
    return nominalYearly * (2 * _periods) / (_periods + 1);
  }

  double get lifeInsuranceGap => _liabilities + _annualExpense * math.min(_supportYears, 10);

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- 真实年化利率换算器 ----
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppHairlineIcons.calculator(color: p.gold, size: 15),
                  const SizedBox(width: 8),
                  const Text('真实年化利率换算器 (APR 照妖镜)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text('揭开分期手续费“月息几厘”的真实借款成本', style: TextStyle(fontSize: 11, color: p.inkMute)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('名义月费率：${_feeRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('分期期数：$_periods 期', style: TextStyle(fontSize: 12, color: p.inkSub)),
                ],
              ),
              Slider(
                value: _feeRate,
                min: 0.2,
                max: 2.0,
                divisions: 18,
                activeColor: p.gold,
                onChanged: (v) => setState(() => _feeRate = v),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: realApr > 10 ? p.error.withValues(alpha: 0.1) : p.done.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '实际综合年化利率 ≈ ${realApr.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: realApr > 10 ? p.error : p.done,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      realApr > 10
                          ? '属于高成本信贷！分期随着本金逐月归还，实际资金占用减半，真实利息接近名义利率的两倍。'
                          : '利率在合理区间。按合同明确约定的 APR 为准。',
                      style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- 家庭寿险保障缺口速算 ----
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppHairlineIcons.shield(color: p.action, size: 15),
                  const SizedBox(width: 8),
                  const Text('家庭寿险保障缺口测算', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text('覆盖房贷车贷与子女赡养基本开销，拒绝保费超支', style: TextStyle(fontSize: 11, color: p.inkMute)),
              const SizedBox(height: 12),
              Text('家庭负债（房贷/车贷）：${_liabilities.round()} 万元', style: const TextStyle(fontSize: 12)),
              Slider(
                value: _liabilities,
                min: 0,
                max: 300,
                divisions: 30,
                activeColor: p.action,
                onChanged: (v) => setState(() => _liabilities = v),
              ),
              Text('年刚性生活开支：${_annualExpense.round()} 万元', style: const TextStyle(fontSize: 12)),
              Slider(
                value: _annualExpense,
                min: 3,
                max: 30,
                divisions: 27,
                activeColor: p.action,
                onChanged: (v) => setState(() => _annualExpense = v),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.surfaceGrey, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '建议定期寿险保额 ≈ ${lifeInsuranceGap.round()} 万元',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: p.action,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '原则：买纯消费型定期寿险（定寿），不要买带分红返还的两全险。30岁男性 100 万保额年保费仅需约千元左右。',
                      style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
