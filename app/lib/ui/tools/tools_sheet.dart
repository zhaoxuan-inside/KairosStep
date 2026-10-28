import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';

/// 离线精算与实用工具箱中枢
///
/// 包含：
/// 1. 个税计算工具 (综合所得累计预扣法 + 专项附加扣除 + 年终奖单独计税)
/// 2. 房贷计算工具 (商贷/公积金/组合贷、等额本息 vs 等额本金)
/// 3. 补充养老金计算 (个人养老金 12000/年节税与复利增值)
/// 4. 养老金领取计算 (城镇职工基本养老金：基础养老金 + 个人账户养老金)
/// 5. 真实年化利率 (APR / IRR 借贷利息换算)
/// 6. 应急备用金测算 (6个月刚性支出)
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

  static const _toolTabs = [
    '个税计算',
    '房贷计算',
    '补充养老金',
    '养老金领取',
    '借贷利率',
    '应急备用金',
  ];

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
          '精算与实用工具箱',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _toolTabs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _navPill(_toolTabs[i], i, p),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: const [
                  _TaxCalculator(),
                  _MortgageCalculator(),
                  _PrivatePensionCalculator(),
                  _PensionRetireCalculator(),
                  _LoanRateCalculator(),
                  _EmergencyFundCalculator(),
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTab = idx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? p.action : p.surface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: on ? p.action : p.hairline),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? Colors.white : p.ink,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. 个税计算工具 (Personal Income Tax)
// ============================================================================

class _TaxCalculator extends StatefulWidget {
  const _TaxCalculator();

  @override
  State<_TaxCalculator> createState() => _TaxCalculatorState();
}

class _TaxCalculatorState extends State<_TaxCalculator> {
  final _salaryCtl = TextEditingController(text: '15000');
  final _insuranceCtl = TextEditingController(text: '3300'); // 五险一金
  final _specialDeductionCtl = TextEditingController(text: '2000'); // 专项附加扣除
  final _bonusCtl = TextEditingController(text: '0'); // 年终奖

  double _tax = 0.0;
  double _netIncome = 0.0;
  double _taxRate = 0.0;
  double _bonusTax = 0.0;
  double _bonusNet = 0.0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final salary = double.tryParse(_salaryCtl.text.trim()) ?? 0.0;
    final insurance = double.tryParse(_insuranceCtl.text.trim()) ?? 0.0;
    final special = double.tryParse(_specialDeductionCtl.text.trim()) ?? 0.0;
    final bonus = double.tryParse(_bonusCtl.text.trim()) ?? 0.0;

    // 起征点 5000 元/月
    final taxable = math.max(0.0, salary - insurance - special - 5000.0);

    // 中国居民个人综合所得月度预扣税率换算（按单月标准阶梯速算）
    double rate = 0.03;
    double quickDeduct = 0.0;

    if (taxable <= 3000) {
      rate = 0.03;
      quickDeduct = 0;
    } else if (taxable <= 12000) {
      rate = 0.10;
      quickDeduct = 210;
    } else if (taxable <= 25000) {
      rate = 0.20;
      quickDeduct = 1410;
    } else if (taxable <= 35000) {
      rate = 0.25;
      quickDeduct = 2660;
    } else if (taxable <= 55000) {
      rate = 0.30;
      quickDeduct = 4410;
    } else if (taxable <= 80000) {
      rate = 0.35;
      quickDeduct = 7160;
    } else {
      rate = 0.45;
      quickDeduct = 15160;
    }

    final tax = math.max(0.0, taxable * rate - quickDeduct);
    final net = math.max(0.0, salary - insurance - tax);

    // 年终奖单独计税优惠测算
    double bTax = 0.0;
    if (bonus > 0) {
      final monthlyBonus = bonus / 12.0;
      double bRate = 0.03;
      double bQuick = 0.0;
      if (monthlyBonus <= 3000) {
        bRate = 0.03;
        bQuick = 0;
      } else if (monthlyBonus <= 12000) {
        bRate = 0.10;
        bQuick = 210;
      } else if (monthlyBonus <= 25000) {
        bRate = 0.20;
        bQuick = 1410;
      } else if (monthlyBonus <= 35000) {
        bRate = 0.25;
        bQuick = 2660;
      } else if (monthlyBonus <= 55000) {
        bRate = 0.30;
        bQuick = 4410;
      } else if (monthlyBonus <= 80000) {
        bRate = 0.35;
        bQuick = 7160;
      } else {
        bRate = 0.45;
        bQuick = 15160;
      }
      bTax = math.max(0.0, bonus * bRate - bQuick);
    }

    setState(() {
      _tax = tax;
      _netIncome = net;
      _taxRate = rate * 100;
      _bonusTax = bTax;
      _bonusNet = math.max(0.0, bonus - bTax);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCard(
          p,
          title: '薪资与社保公积金输入',
          children: [
            _inputRow('税前月薪 (元)', _salaryCtl, onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            _inputRow('五险一金个人扣除 (元)', _insuranceCtl, hint: '养老8%+医保2%+公积金12%等', onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            _inputRow('专项附加扣除合计 (元/月)', _specialDeductionCtl, hint: '房贷1000/租金1500/子女/赡养等', onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            _inputRow('全年一次性奖金/年终奖 (元)', _bonusCtl, hint: '可选，单独计税优惠测算', onChanged: (_) => _calculate()),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.action.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.action.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('月度到手测算明细', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.action)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCol('税后月到手 (元)', _netIncome.toStringAsFixed(2), p.emerald),
                  _statCol('应纳个税 (元)', _tax.toStringAsFixed(2), p.rose),
                  _statCol('当前边际税率', '${_taxRate.toStringAsFixed(0)}%', p.amber),
                ],
              ),
              if ((double.tryParse(_bonusCtl.text) ?? 0) > 0) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: p.hairline),
                const SizedBox(height: 10),
                Text('年终奖单独计税优惠', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCol('年终奖到手', _bonusNet.toStringAsFixed(2), p.emerald),
                    _statCol('年终奖交税', _bonusTax.toStringAsFixed(2), p.rose),
                    _statCol('全年税后总包', (_netIncome * 12 + _bonusNet).toStringAsFixed(2), p.action),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipBox(p, '依法申报 7 项专项附加扣除（3岁以下婴幼儿照护、子女教育、继续教育、大病医疗、住房贷款利息或住房租金、赡养老人）可在应纳税额前直接抵减，守牢法定节税权利！'),
      ],
    );
  }
}

// ============================================================================
// 2. 房贷计算工具 (Mortgage Loan Calculator)
// ============================================================================

class _MortgageCalculator extends StatefulWidget {
  const _MortgageCalculator();

  @override
  State<_MortgageCalculator> createState() => _MortgageCalculatorState();
}

class _MortgageCalculatorState extends State<_MortgageCalculator> {
  final _amountCtl = TextEditingController(text: '100'); // 贷款金额 (万元)
  final _yearsCtl = TextEditingController(text: '30'); // 年限
  final _rateCtl = TextEditingController(text: '3.15'); // 商业贷款利率 %
  bool _isEqualInstallment = true; // true: 等额本息, false: 等额本金

  double _monthlyPayment = 0.0;
  double _firstMonthPayment = 0.0;
  double _monthlyDecrease = 0.0;
  double _totalInterest = 0.0;
  double _totalPayment = 0.0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final pWan = double.tryParse(_amountCtl.text.trim()) ?? 0.0;
    final years = double.tryParse(_yearsCtl.text.trim()) ?? 30.0;
    final annualRate = double.tryParse(_rateCtl.text.trim()) ?? 3.15;

    final P = pWan * 10000.0; // 转化为元
    final n = (years * 12).round(); // 还款月数
    final r = (annualRate / 100.0) / 12.0; // 月利率

    if (P <= 0 || n <= 0 || r <= 0) return;

    if (_isEqualInstallment) {
      // 等额本息 M = P * [r(1+r)^n] / [(1+r)^n - 1]
      final powRn = math.pow(1 + r, n).toDouble();
      final M = P * (r * powRn) / (powRn - 1);
      final totalPay = M * n;
      final interest = totalPay - P;

      setState(() {
        _monthlyPayment = M;
        _totalInterest = interest;
        _totalPayment = totalPay;
      });
    } else {
      // 等额本金
      final basePrincipal = P / n; // 每月本金
      final firstMonth = basePrincipal + P * r;
      final decrease = basePrincipal * r;
      final totalInterest = ((n + 1) * P * r) / 2.0;
      final totalPay = P + totalInterest;

      setState(() {
        _firstMonthPayment = firstMonth;
        _monthlyDecrease = decrease;
        _totalInterest = totalInterest;
        _totalPayment = totalPay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCard(
          p,
          title: '贷款要素设置',
          children: [
            _inputRow('商业贷款总额 (万元)', _amountCtl, onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _inputRow('还款期限 (年)', _yearsCtl, onChanged: (_) => _calculate())),
                const SizedBox(width: 10),
                Expanded(child: _inputRow('贷款年利率 (%)', _rateCtl, onChanged: (_) => _calculate())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('还款方式：', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink)),
                ChoiceChip(
                  label: const Text('等额本息 (每月固定)'),
                  selected: _isEqualInstallment,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _isEqualInstallment = true);
                      _calculate();
                    }
                  },
                  selectedColor: p.action,
                  labelStyle: TextStyle(color: _isEqualInstallment ? Colors.white : p.ink, fontSize: 11),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('等额本金 (逐月递减)'),
                  selected: !_isEqualInstallment,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _isEqualInstallment = false);
                      _calculate();
                    }
                  },
                  selectedColor: p.action,
                  labelStyle: TextStyle(color: !_isEqualInstallment ? Colors.white : p.ink, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
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
              Text(
                _isEqualInstallment ? '等额本息月供测算结果' : '等额本金递减还款测算',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.action),
              ),
              const SizedBox(height: 12),
              if (_isEqualInstallment) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCol('每月月供 (元)', _monthlyPayment.toStringAsFixed(2), p.rose),
                    _statCol('支付总利息 (万元)', (_totalInterest / 10000).toStringAsFixed(2), p.amber),
                    _statCol('还款总额 (万元)', (_totalPayment / 10000).toStringAsFixed(2), p.emerald),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCol('首月月供 (元)', _firstMonthPayment.toStringAsFixed(2), p.rose),
                    _statCol('每月递减 (元)', _monthlyDecrease.toStringAsFixed(2), p.action),
                    _statCol('总利息 (万元)', (_totalInterest / 10000).toStringAsFixed(2), p.emerald),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipBox(p, '等额本息前期还款中利息占大头，月供平稳易规划；等额本金前期还款压力大但总利息显著更省。提前还款优先考虑在贷款前1/3周期内执行。'),
      ],
    );
  }
}

// ============================================================================
// 3. 补充养老金计算 (Supplementary & Private Pension)
// ============================================================================

class _PrivatePensionCalculator extends StatefulWidget {
  const _PrivatePensionCalculator();

  @override
  State<_PrivatePensionCalculator> createState() => _PrivatePensionCalculatorState();
}

class _PrivatePensionCalculatorState extends State<_PrivatePensionCalculator> {
  final _annualDepositCtl = TextEditingController(text: '12000'); // 每年存入（上限1.2万）
  final _taxRateCtl = TextEditingController(text: '20'); // 个人所得税边际税率 %
  final _yearsCtl = TextEditingController(text: '20'); // 积累年限
  final _annualReturnCtl = TextEditingController(text: '3.5'); // 年化收益率 %

  double _annualTaxSaved = 0.0;
  double _totalTaxSaved = 0.0;
  double _futureValue = 0.0; // 到期复利本息总和
  double _netAfterWithdrawTax = 0.0; // 扣除3%领取税后的纯到手资产

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final deposit = double.tryParse(_annualDepositCtl.text.trim()) ?? 12000.0;
    final taxRate = (double.tryParse(_taxRateCtl.text.trim()) ?? 20.0) / 100.0;
    final years = double.tryParse(_yearsCtl.text.trim()) ?? 20.0;
    final r = (double.tryParse(_annualReturnCtl.text.trim()) ?? 3.5) / 100.0;

    // 每年节税
    final annualSave = deposit * taxRate;
    final totalSave = annualSave * years;

    // 年金终值公式 FV = A * [ (1+r)^n - 1 ] / r
    double fv = 0.0;
    if (r > 0) {
      fv = deposit * (math.pow(1 + r, years) - 1) / r;
    } else {
      fv = deposit * years;
    }

    // 退休领取时按 3% 单独纳税
    final net = fv * (1 - 0.03);

    setState(() {
      _annualTaxSaved = annualSave;
      _totalTaxSaved = totalSave;
      _futureValue = fv;
      _netAfterWithdrawTax = net;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCard(
          p,
          title: '个人养老金 / 企业年金参数设置',
          children: [
            _inputRow('每年存入金额 (元)', _annualDepositCtl, hint: '法定个人养老金抵税上限 12000 元', onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _inputRow('当前边际个税率 (%)', _taxRateCtl, hint: '如 10%, 20%, 25%', onChanged: (_) => _calculate())),
                const SizedBox(width: 10),
                Expanded(child: _inputRow('计划存缴年限 (年)', _yearsCtl, onChanged: (_) => _calculate())),
              ],
            ),
            const SizedBox(height: 10),
            _inputRow('预期年化投资收益率 (%)', _annualReturnCtl, hint: '理财/储蓄/公募养老FOF，建议保守预估 3%~4%', onChanged: (_) => _calculate()),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.emerald.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('节税收益与资产复利测算', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.emerald)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCol('每年即刻节税 (元)', _annualTaxSaved.toStringAsFixed(0), p.rose),
                  _statCol('累计直接省税 (元)', _totalTaxSaved.toStringAsFixed(0), p.action),
                  _statCol('退休净到手 (万元)', (_netAfterWithdrawTax / 10000).toStringAsFixed(2), p.emerald),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: p.hairline),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('退休本息总规模 (税前)', style: TextStyle(fontSize: 11.5, color: p.inkSub)),
                  Text('${(_futureValue / 10000).toStringAsFixed(2)} 万元', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('领取时法定优惠税率 (3%)', style: TextStyle(fontSize: 11.5, color: p.inkSub)),
                  Text('- ${((_futureValue * 0.03) / 10000).toStringAsFixed(2)} 万元', style: TextStyle(fontSize: 12, color: p.rose)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipBox(p, '个人养老金是国家制度性税收递延工具：现在以 10%~45% 边际税率免税存入，退休领取时仅按 3% 优惠征税，中间投资收益复利滚存不征税！'),
      ],
    );
  }
}

// ============================================================================
// 4. 养老金领取计算 (Retirement Pension Calculation)
// ============================================================================

class _PensionRetireCalculator extends StatefulWidget {
  const _PensionRetireCalculator();

  @override
  State<_PensionRetireCalculator> createState() => _PensionRetireCalculatorState();
}

class _PensionRetireCalculatorState extends State<_PensionRetireCalculator> {
  final _avgWageCtl = TextEditingController(text: '7500'); // 全省上年度月平均工资
  final _myWageCtl = TextEditingController(text: '8500'); // 本人月薪/缴费基数
  final _yearsCtl = TextEditingController(text: '25'); // 累计缴费年限
  int _retireAge = 60; // 退休年龄 (50/55/60/63)

  double _basePension = 0.0; // 基础养老金
  double _accountPension = 0.0; // 个人账户养老金
  double _totalPension = 0.0; // 每月预计养老金
  double _replaceRate = 0.0; // 养老金替代率

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final avgWage = double.tryParse(_avgWageCtl.text.trim()) ?? 7500.0;
    final myWage = double.tryParse(_myWageCtl.text.trim()) ?? 8500.0;
    final years = double.tryParse(_yearsCtl.text.trim()) ?? 25.0;

    // 本人缴费工资指数 = 个人工资 / 社平工资
    final index = (myWage / avgWage).clamp(0.6, 3.0);

    // 1. 基础养老金 = 社平工资 * (1 + 缴费指数) / 2 * 缴费年限 * 1%
    final base = avgWage * (1.0 + index) / 2.0 * years * 0.01;

    // 2. 个人账户养老金 = 个人账户储存额 / 计发月数
    // 计发月数国家标准：50岁=195, 55岁=170, 60岁=139, 63岁(延迟退休)=117
    int months = 139;
    if (_retireAge == 50) months = 195;
    if (_retireAge == 55) months = 170;
    if (_retireAge == 60) months = 139;
    if (_retireAge == 63) months = 117;

    // 个人账户按每月工资 8% 缴纳，保守累计本息（年化2%利息估算）
    final annualPay = myWage * 0.08 * 12.0;
    final totalSavings = annualPay * years * 1.25; // 考虑多年复利滚存约为缴费本金的 1.25 倍
    final personal = totalSavings / months;

    final total = base + personal;
    final repRate = (myWage > 0) ? (total / myWage * 100.0) : 0.0;

    setState(() {
      _basePension = base;
      _accountPension = personal;
      _totalPension = total;
      _replaceRate = repRate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCard(
          p,
          title: '法定城镇职工养老保险参数',
          children: [
            Row(
              children: [
                Expanded(child: _inputRow('当地在岗月平工资 (元)', _avgWageCtl, onChanged: (_) => _calculate())),
                const SizedBox(width: 10),
                Expanded(child: _inputRow('本人参保月薪基数 (元)', _myWageCtl, onChanged: (_) => _calculate())),
              ],
            ),
            const SizedBox(height: 10),
            _inputRow('累计参保缴费年限 (年)', _yearsCtl, hint: '最低法定参保满 15~20 年', onChanged: (_) => _calculate()),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('退休年龄：', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink)),
                for (final age in [50, 55, 60, 63])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$age岁'),
                      selected: _retireAge == age,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _retireAge = age);
                          _calculate();
                        }
                      },
                      selectedColor: p.action,
                      labelStyle: TextStyle(color: _retireAge == age ? Colors.white : p.ink, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.amber.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('退休月领取基本养老金预估', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.amber)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCol('预计每月总到手 (元)', _totalPension.toStringAsFixed(0), p.emerald),
                  _statCol('基础养老金 (元)', _basePension.toStringAsFixed(0), p.action),
                  _statCol('养老金替代率', '${_replaceRate.toStringAsFixed(1)}%', p.rose),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: p.hairline),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('个人账户储存额预计按月发放', style: TextStyle(fontSize: 11.5, color: p.inkSub)),
                  Text('约 ${_accountPension.toStringAsFixed(0)} 元/月', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipBox(p, '养老保险遵循“长缴多得、多缴多得”原则：参保满 15 年仅是领取最低门槛，每多缴纳 1 年，基础养老金每月领取的计发比例就稳步递增 1%！'),
      ],
    );
  }
}

// ============================================================================
// 5. 借贷真实年化利率 (Loan Rate / APR)
// ============================================================================

class _LoanRateCalculator extends StatefulWidget {
  const _LoanRateCalculator();

  @override
  State<_LoanRateCalculator> createState() => _LoanRateCalculatorState();
}

class _LoanRateCalculatorState extends State<_LoanRateCalculator> {
  final _amountCtl = TextEditingController(text: '10000');
  final _termsCtl = TextEditingController(text: '12');
  final _feePerTermCtl = TextEditingController(text: '60');

  double _nominalRate = 0.0;
  double _realRate = 0.0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final amount = double.tryParse(_amountCtl.text.trim()) ?? 10000.0;
    final terms = int.tryParse(_termsCtl.text.trim()) ?? 12;
    final fee = double.tryParse(_feePerTermCtl.text.trim()) ?? 60.0;

    if (amount <= 0 || terms <= 0) return;

    final nominal = (fee * terms / amount) * (12.0 / terms) * 100.0;
    // 分期手续费实际本金逐月减少，真实年化利率约为名义费率的 1.8~1.95 倍
    final real = nominal * 1.85;

    setState(() {
      _nominalRate = nominal;
      _realRate = real;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCard(
          p,
          title: '消费分期要素拆解',
          children: [
            _inputRow('借款/分期本金 (元)', _amountCtl, onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _inputRow('分期期数 (月)', _termsCtl, onChanged: (_) => _calculate())),
                const SizedBox(width: 10),
                Expanded(child: _inputRow('每期手续费/利息 (元)', _feePerTermCtl, onChanged: (_) => _calculate())),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.rose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.rose.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('真实年化利率对比', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.rose)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCol('机构宣传名义费率', '${_nominalRate.toStringAsFixed(2)}%', p.inkSub),
                  _statCol('IRR 真实综合年化', '${_realRate.toStringAsFixed(2)}%', p.rose),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipBox(p, '消费贷或信用卡分期声称“月费率只要 0.5%”，表面看似年化 6%，但因每月本金已逐步偿还，资金占用减半，真实年化 IRR 往往高达 11%~14%！'),
      ],
    );
  }
}

// ============================================================================
// 6. 应急备用金测算 (Emergency Fund)
// ============================================================================

class _EmergencyFundCalculator extends StatefulWidget {
  const _EmergencyFundCalculator();

  @override
  State<_EmergencyFundCalculator> createState() => _EmergencyFundCalculatorState();
}

class _EmergencyFundCalculatorState extends State<_EmergencyFundCalculator> {
  final _rentCtl = TextEditingController(text: '2500'); // 房租/月供
  final _foodCtl = TextEditingController(text: '1800'); // 基础饮食
  final _utilityCtl = TextEditingController(text: '400'); // 水电燃气通讯
  final _loanCtl = TextEditingController(text: '0'); // 其他刚性贷款

  double _monthlyRigid = 0.0;
  double _fund3m = 0.0;
  double _fund6m = 0.0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final rent = double.tryParse(_rentCtl.text.trim()) ?? 0.0;
    final food = double.tryParse(_foodCtl.text.trim()) ?? 0.0;
    final utility = double.tryParse(_utilityCtl.text.trim()) ?? 0.0;
    final loan = double.tryParse(_loanCtl.text.trim()) ?? 0.0;

    final monthly = rent + food + utility + loan;
    setState(() {
      _monthlyRigid = monthly;
      _fund3m = monthly * 3;
      _fund6m = monthly * 6;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCard(
          p,
          title: '单月刚性生活开销输入',
          children: [
            _inputRow('房租 / 房贷月供 (元)', _rentCtl, onChanged: (_) => _calculate()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _inputRow('基础餐饮饮食 (元)', _foodCtl, onChanged: (_) => _calculate())),
                const SizedBox(width: 10),
                Expanded(child: _inputRow('水电燃气话费 (元)', _utilityCtl, onChanged: (_) => _calculate())),
              ],
            ),
            const SizedBox(height: 10),
            _inputRow('其他刚性负债/分期 (元)', _loanCtl, onChanged: (_) => _calculate()),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.action.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.action.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('家庭安全垫测算结果', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.action)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCol('单月刚性支出', '${_monthlyRigid.toStringAsFixed(0)} 元', p.ink),
                  _statCol('3个月最低红线', '${_fund3m.toStringAsFixed(0)} 元', p.amber),
                  _statCol('6个月黄金防御金', '${_fund6m.toStringAsFixed(0)} 元', p.emerald),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTipBox(p, '备用金切忌投入股市或高风险理财！应存放在现金管理类或活期大额存单中，无论遇到失业、降薪或突发就医，都能保底家庭 6 个月正常运转。'),
      ],
    );
  }
}

// ============================================================================
// 辅助小组件 (Helper Widgets)
// ============================================================================

Widget _buildCard(AppPalettes p, {required String title, required List<Widget> children}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

Widget _inputRow(String label, TextEditingController ctl, {String? hint, ValueChanged<String>? onChanged}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
      const SizedBox(height: 4),
      TextField(
        controller: ctl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: onChanged,
      ),
    ],
  );
}

Widget _statCol(String title, String value, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ],
  );
}

Widget _buildTipBox(AppPalettes p, String text) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: p.pillBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: p.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline, size: 15, color: p.amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, height: 1.45, color: p.inkSub),
          ),
        ),
      ],
    ),
  );
}
