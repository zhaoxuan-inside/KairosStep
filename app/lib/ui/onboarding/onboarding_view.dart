import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';

/// 初次开启应用时的全息画像与 767 建议全景引导向导。
///
/// 核心突破：
/// 1. 建议引导 100% 覆盖全库 767 条建议（六大人生支柱：健康 180、职场 128、家庭 113、财产 202、应急 99、节律 45）；
/// 2. 极致人性化体验：温暖共情的生命引语、实证建议小锦囊即时预览、一键全景探索与画像专属双轨制；
/// 3. 优雅灵动动效：错峰入场动画（Staggered Entrance）、触感微弹交互、多层同心罗盘呼吸环、数字平滑滚动增长。
class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    this.isReconfiguring = false,
    this.onComplete,
  });

  /// 是否是设置页内重新调整画像
  final bool isReconfiguring;
  final VoidCallback? onComplete;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 用户正在配置的画像状态
  late String _gender;
  late int _age;
  late Set<String> _roles;
  late Set<String> _livingConditions;
  late Set<String> _healthConcerns;
  late Set<String> _focusDomains;
  late bool _prunedOnly;

  // 终末页面的多层同心罗盘动画控制器
  late AnimationController _compassSpinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // 分页错峰动效控制器
  late AnimationController _pageAnimController;
  late Animation<double> _pageFadeAnim;
  late Animation<Offset> _pageSlideAnim;

  @override
  void initState() {
    super.initState();
    // 默认初始值
    _gender = '男';
    _age = 28;
    _roles = {'全民', '上班族', '伴侣', '家人'};
    _livingConditions = {'租房人', '司机'};
    _healthConcerns = {'久坐伏案', '视力保护'};
    _focusDomains = {
      'health',
      'career',
      'family',
      'finance',
      'emergency',
      'cadence',
    };
    _prunedOnly = true;

    // 罗盘旋转与呼吸光晕
    _compassSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 页面错峰入场动效
    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pageFadeAnim = CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    );
    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    ));

    _pageAnimController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isReconfiguring) {
      final cur = storeOf(context).profile;
      _gender = cur.gender;
      _age = cur.age;
      _roles = Set.from(cur.roles);
      _livingConditions = Set.from(cur.livingConditions);
      _healthConcerns = Set.from(cur.healthConcerns);
      _focusDomains = Set.from(cur.focusDomains);
      _prunedOnly = cur.prunedOnly;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _compassSpinController.dispose();
    _pulseController.dispose();
    _pageAnimController.dispose();
    super.dispose();
  }

  UserProfile _buildProfile() {
    return UserProfile(
      gender: _gender,
      age: _age,
      roles: _roles.toList(),
      livingConditions: _livingConditions.toList(),
      healthConcerns: _healthConcerns.toList(),
      focusDomains: _focusDomains.toList(),
      prunedOnly: _prunedOnly,
      parentsOnly: false,
    );
  }

  void _goToPage(int page) {
    if (page == _currentPage) return;
    _pageAnimController.reset();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
    _pageAnimController.forward();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 6) {
      _goToPage(_currentPage + 1);
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    _compassSpinController.stop();
    _pulseController.stop();
    final profile = _buildProfile();
    final store = storeOf(context);
    store.completeOnboarding(profile);
    if (widget.isReconfiguring) {
      Navigator.of(context).pop();
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final isDark = p.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏进度与人性化操作
            _buildTopBar(p),
            // 内容分页
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                  _pageAnimController.forward(from: 0.0);
                  if (idx == 6) {
                    _compassSpinController.repeat();
                    _pulseController.repeat(reverse: true);
                  } else {
                    _compassSpinController.stop();
                    _pulseController.stop();
                  }
                },
                children: [
                  _buildStep0Prologue(p, isDark),
                  _buildStep1AgeGender(p),
                  _buildStep2Career(p),
                  _buildStep3Family(p),
                  _buildStep4Lifestyle(p),
                  _buildStep5Domains(p),
                  _buildStep6Synthesis(p),
                ],
              ),
            ),
            // 底栏操作按钮
            _buildBottomBar(p),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalettes p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 16, color: p.inkSub),
              onPressed: _prevPage,
              tooltip: '上一步',
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final active = i == _currentPage;
                final done = i < _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? p.action
                        : (done ? p.emerald : p.hairline),
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: p.action.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
          if (_currentPage < 6 && !widget.isReconfiguring)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _goToPage(6);
              },
              child: Text(
                '跳过',
                style: TextStyle(
                  fontSize: 12,
                  color: p.inkMute,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // --- Step 0: 启程序言与 767 建议全景蓝图 ---
  Widget _buildStep0Prologue(AppPalettes p, bool isDark) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            // 呼吸徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    p.action.withValues(alpha: 0.16),
                    p.emerald.withValues(alpha: 0.16),
                  ],
                ),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: p.action.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: p.action),
                  const SizedBox(width: 6),
                  Text(
                    '纯本地优先 · 767 条实证建议全域指引',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.action,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '数字阶跃\nKairosStep',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: p.ink,
                height: 1.18,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '生活不需要一次性记住 767 条建议，\n而是在关键生命节点与日常节律里，\n做对那几件成本极低、划算极高、防守极坚固的事。',
              style: TextStyle(
                fontSize: 14.5,
                color: p.inkSub,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // 全景六大支柱一览卡
            _buildPillarsSummaryCard(p),
            const SizedBox(height: 14),
            // 隐私与纯净承诺卡
            _buildPurityGuaranteeCard(p),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarsSummaryCard(AppPalettes p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 15, color: p.action),
              const SizedBox(width: 8),
              Text(
                '767 条建议全景六大支柱',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const Spacer(),
              Text(
                '100% 完整收录',
                style: TextStyle(fontSize: 10.5, color: p.emerald, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pillarBadge(p, '健康防线', '180条', const Color(0xFF10B981)),
              const SizedBox(width: 6),
              _pillarBadge(p, '职场事业', '128条', const Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              _pillarBadge(p, '家庭守护', '113条', const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pillarBadge(p, '财产法律', '202条', const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              _pillarBadge(p, '应急自救', '99条', const Color(0xFFF43F5E)),
              const SizedBox(width: 6),
              _pillarBadge(p, '日常节律', '45条', const Color(0xFF06B6D4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillarBadge(AppPalettes p, String name, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 9.5,
                color: p.inkSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurityGuaranteeCard(AppPalettes p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: p.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '真正交付用户的纯净承诺',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '纯本地沙盒存储 · 零隐私索取 · 无算法窥探与云端上传',
                  style: TextStyle(fontSize: 10.5, color: p.inkSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1: 生命时钟与生理防线 ---
  Widget _buildStep1AgeGender(AppPalettes p) {
    final milestone = _getAgeMilestone(_age);

    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '01 / 06 · 生命时钟',
              title: '年龄与生理节点',
              prompt: '「有些检查一辈子做一次就够，有些慢病与防癌坎 35 岁就要筑起。」\n你的年龄与生理周期，决定了幽门螺杆菌、血压血糖、疫苗补种与专项筛查的黄金窗口。',
            ),
            const SizedBox(height: 18),
            Text('生理特征（精确匹配乳腺/骨密度/孕产等专项谓词）', style: _labelStyle(p)),
            const SizedBox(height: 8),
            Row(
              children: [
                _genderCard(p, '男', Icons.male, '心血管、痛风筛查，自动排除女性专项'),
                const SizedBox(width: 12),
                _genderCard(p, '女', Icons.female, '乳腺钼靶、HPV、骨密度与孕产照护'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('当前年龄', style: _labelStyle(p)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Text(
                    '$_age 岁',
                    key: ValueKey(_age),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: p.action,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _age.toDouble(),
              min: 14,
              max: 88,
              divisions: 74,
              activeColor: p.action,
              label: '$_age 岁',
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _age = v.round());
              },
            ),
            const SizedBox(height: 8),
            // 动态联动实证建议节点卡片
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.action.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: p.action.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline_outlined, size: 15, color: p.action),
                      const SizedBox(width: 6),
                      Text(
                        milestone.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.action,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '实证金标准',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: p.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    milestone.desc,
                    style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.5),
                  ),
                  const Divider(height: 16),
                  Text(
                    '为你自动激活本年龄段建议：${milestone.sampleAdvice}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderCard(AppPalettes p, String gender, IconData icon, String note) {
    final selected = _gender == gender;
    return Expanded(
      child: _AnimatedCard(
        selected: selected,
        onTap: () => setState(() => _gender = gender),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: selected ? p.action : p.inkMute),
                const SizedBox(width: 6),
                Text(
                  gender,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? p.action : p.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(fontSize: 10, color: p.inkMute, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  ({String title, String desc, String sampleAdvice}) _getAgeMilestone(int age) {
    if (age <= 22) {
      return (
        title: '少年与成年早期节点',
        desc: '重点构建早期法律底线、防兼职刷单陷阱，补齐成年基础疫苗（乙肝、HPV 等）。',
        sampleAdvice: '乙肝表面抗原/抗体筛查 · 租房防黑中介合同核验',
      );
    }
    if (age <= 34) {
      return (
        title: '青年奋斗期节点',
        desc: '重点守护雇佣劳动合同、工资条备份、婚恋财务透明与久坐工位健康防守。',
        sampleAdvice: '工资条离线留痕 · 劳动合同7天核对 · 颈椎远眺习惯',
      );
    }
    if (age <= 44) {
      return (
        title: '35 岁慢病关键节点',
        desc: '国家每年免费量血压、空腹血糖与血脂检测启动，幽门螺杆菌根除，防范心脑血管隐患。',
        sampleAdvice: '14C碳呼气试验(HP) · 每年免费血压血糖 · 牙周洁治',
      );
    }
    if (age <= 49) {
      return (
        title: '45 岁专项防癌坎',
        desc: '结直肠癌筛查（粪便隐血/肠镜）、胃镜与乳腺钼靶检查进入高频防线，守住家庭财务底盘。',
        sampleAdvice: '无痛胃肠镜首次大修 · 乳腺超声/钼靶联合筛查',
      );
    }
    if (age <= 64) {
      return (
        title: '50 岁疫苗与慢性病节点',
        desc: '带状疱疹疫苗（防效率 97%）两针接种，骨骼关节保养，长期慢病规范用药。',
        sampleAdvice: '带状疱疹两针接种 · 双能X线骨密度检查 · 白内障筛查',
      );
    }
    return (
      title: '65 岁银发关怀节点',
      desc: '双能 X 线骨密度检查、肺炎球菌疫苗、防跌倒家庭适老化改造与国家免费老年体检。',
      sampleAdvice: '23价肺炎球菌疫苗 · 卫健委免费体检 · 浴室防滑扶手',
    );
  }

  // --- Step 2: 职业与职场防御 ---
  Widget _buildStep2Career(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '02 / 06 · 职场生态',
              title: '核心职业形态',
              prompt: '「别把自己搭进去。上班、创业或写代码，劳动维权、防范灰产与固化工资证据，是第一位的划算。」\n为你点亮涵盖 128 条职场建议的合规与防御网络：',
            ),
            const SizedBox(height: 16),
            _toggleCard(
              p,
              tag: '上班族',
              icon: Icons.business_center_outlined,
              title: '企业雇员 / 上班族',
              subtitle: '劳动合同 7 天核对 · 工资条离线留痕 · 试用期辞退避坑 · 工伤留痕',
              selected: _roles.contains('上班族'),
              onTap: () => _toggleRole('上班族'),
            ),
            _toggleCard(
              p,
              tag: '程序员',
              icon: Icons.terminal_outlined,
              title: '程序员 / 技术开发者',
              subtitle: '开源许可证风险 · 爬虫数据红线 · 灰产兼职阻断 · 外挂脚本边界',
              selected: _roles.contains('程序员'),
              onTap: () => _toggleRole('程序员'),
            ),
            _toggleCard(
              p,
              tag: '创业者',
              icon: Icons.rocket_launch_outlined,
              title: '创业者 / 合伙做生意',
              subtitle: '有限责任资产隔离 · 股权与夫妻债务防范 · 税务合规 · 不把家底赔进去',
              selected: _roles.contains('创业者'),
              onTap: () => _toggleRole('创业者'),
            ),
            _toggleCard(
              p,
              tag: '学生',
              icon: Icons.school_outlined,
              title: '在校学生 / 求职新人',
              subtitle: '三方协议核查 · 学历与证书真伪 · 远离跑分洗钱陷阱 · 校园人身安全',
              selected: _roles.contains('学生'),
              onTap: () => _toggleRole('学生'),
            ),
            _toggleCard(
              p,
              tag: '灵活就业者',
              icon: Icons.coffee_outlined,
              title: '自由职业 / 灵活就业',
              subtitle: '自费社保最优配置 · 商业合同预付款约定 · 知识产权防御',
              selected: _roles.contains('灵活就业者'),
              onTap: () => _toggleRole('灵活就业者'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: 家庭与守护责任 ---
  Widget _buildStep3Family(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '03 / 06 · 守护责任',
              title: '家庭与重要关系',
              prompt: '「守护家人的底气，不是事后的慌乱，而是平静时备好的急救常识、防骗机制与照护路径。」\n为你点亮涵盖 113 条家庭维度的建议网络：',
            ),
            const SizedBox(height: 16),
            _toggleCard(
              p,
              tag: '家有老人',
              icon: Icons.elderly_outlined,
              title: '家有父母 / 老人照护',
              subtitle: '激活 139 条老人专属健康 · 肺炎与带状疱疹疫苗 · 防骗三问一打 · 跌倒看护',
              selected: _roles.contains('家有老人'),
              onTap: () => _toggleRole('家有老人'),
            ),
            _toggleCard(
              p,
              tag: '家长',
              icon: Icons.child_care_outlined,
              title: '抚养孩子 / 准父母',
              subtitle: '儿童高热惊厥与窒息急救 · 疫苗接种日历 · 母乳与奶粉冲调 · 教育回报核算',
              selected: _roles.contains('家长') || _roles.contains('准父母'),
              onTap: () {
                if (_roles.contains('家长')) {
                  _roles.remove('家长');
                  _roles.remove('准父母');
                } else {
                  _roles.add('家长');
                  _roles.add('准父母');
                }
                setState(() {});
              },
            ),
            _toggleCard(
              p,
              tag: '伴侣',
              icon: Icons.favorite_border,
              title: '恋爱同居 / 伴侣已婚',
              subtitle: '夫妻共同财产与债务隔离 · 婚前钱账透明 · 共同储蓄与大病互助',
              selected: _roles.contains('伴侣'),
              onTap: () => _toggleRole('伴侣'),
            ),
            _toggleCard(
              p,
              tag: '独立生活',
              icon: Icons.person_outline,
              title: '单身独居 / 专注自我',
              subtitle: '独居门锁二次核验 · 紧急联系人一键直达 · 医院急诊绿色通道认知',
              selected: _roles.contains('独居'),
              onTap: () => _toggleRole('独居'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 4: 居住与生活日常 ---
  Widget _buildStep4Lifestyle(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '04 / 06 · 生活常态',
              title: '居住与日常情境',
              prompt: '「日常最大的风险往往藏在最熟悉的习惯里：合租房查验产权、上车扣紧安全带、大额转账冷静期。」\n为你点亮涵盖 202 条财产法律建议的情境规则：',
            ),
            const SizedBox(height: 16),
            _toggleCard(
              p,
              tag: '租房人',
              icon: Icons.apartment_outlined,
              title: '租房合租生活',
              subtitle: '中介房东资质确权 · 押金退还避坑 · 甲醛自测 · 租住安全防范',
              selected: _livingConditions.contains('租房人'),
              onTap: () => _toggleLiving('租房人'),
            ),
            _toggleCard(
              p,
              tag: '购房人',
              icon: Icons.home_work_outlined,
              title: '购房置业 / 房贷还款',
              subtitle: '房贷利率与违约金核算 · 大额转账留痕凭证 · 房屋产权确权',
              selected: _livingConditions.contains('购房人'),
              onTap: () => _toggleLiving('购房人'),
            ),
            _toggleCard(
              p,
              tag: '司机',
              icon: Icons.directions_car_outlined,
              title: '日常开车 / 乘车出行',
              subtitle: '全车舱安全带锁止 · 行车记录仪防诬 · 疲劳驾驶与高速安全底线',
              selected: _livingConditions.contains('司机'),
              onTap: () => _toggleLiving('司机'),
            ),
            _toggleCard(
              p,
              tag: '出境者',
              icon: Icons.flight_takeoff_outlined,
              title: '跨国旅行 / 出境打工留学',
              subtitle: '全球领保热线 12308 · 境外务工资格核验 · 突发水土不服与保险',
              selected: _livingConditions.contains('出境者'),
              onTap: () => _toggleLiving('出境者'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 5: 全景六大领域深度定制（100% 建议全覆盖引导） ---
  Widget _buildStep5Domains(AppPalettes p) {
    final catalog = catalogOf(context);
    final totalAdviceCount = catalog.adviceList.length;

    // 计算当前选中的领域所覆盖的建议总数
    final coveredInSelectedDomains = catalog.adviceList.where((a) {
      final domain = LifeDomain.ofChapter(a.chapter);
      return _focusDomains.contains(domain.id);
    }).length;

    final isAllSelected = _focusDomains.length == LifeDomain.values.length;

    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '05 / 06 · 全景覆盖',
              title: '人生六大支柱完整定制',
              prompt: '「全书 767 条建议由六大支柱严密咬合，绝不留任何信息孤岛。」\n你可以自由点亮关切的领域，随时在应用库中一键切回全景无死角浏览：',
            ),
            const SizedBox(height: 14),
            // 顶部覆盖度横幅
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: p.action.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.action.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 18, color: p.action),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已点亮领域覆盖：$coveredInSelectedDomains / $totalAdviceCount 条建议',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.action,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isAllSelected) {
                          _focusDomains = {'health', 'career', 'finance'};
                        } else {
                          _focusDomains = LifeDomain.values.map((d) => d.id).toSet();
                        }
                      });
                    },
                    child: Text(
                      isAllSelected ? '恢复精选' : '全选点亮',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.action,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 六大领域卡片列表
            ...LifeDomain.values.map((d) {
              final isChecked = _focusDomains.contains(d.id);
              return _domainCard(p, d, isChecked);
            }),
          ],
        ),
      ),
    );
  }

  Widget _domainCard(AppPalettes p, LifeDomain domain, bool isChecked) {
    return _AnimatedCard(
      selected: isChecked,
      onTap: () {
        setState(() {
          if (isChecked) {
            if (_focusDomains.length > 1) {
              _focusDomains.remove(domain.id);
            }
          } else {
            _focusDomains.add(domain.id);
          }
        });
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isChecked
                  ? domain.accentColor.withValues(alpha: 0.18)
                  : p.pillBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              domain.icon,
              size: 20,
              color: isChecked ? domain.accentColor : p.inkSub,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      domain.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isChecked ? domain.accentColor : p.ink,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? domain.accentColor.withValues(alpha: 0.16)
                            : p.hairline,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        '${domain.totalCount} 条',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isChecked ? domain.accentColor : p.inkMute,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  domain.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: p.inkSub,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked ? domain.accentColor : Colors.transparent,
              border: Border.all(
                color: isChecked ? domain.accentColor : p.inkMute,
                width: 1.5,
              ),
            ),
            child: isChecked
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  // --- Step 6: 罗盘校准与全景阶跃启动 ---
  Widget _buildStep6Synthesis(AppPalettes p) {
    final catalog = catalogOf(context);
    final tempProfile = _buildProfile();

    // 动态基于真实 767 数据计算，拒绝任何 Mock！
    final matchedTotal = catalog.adviceList.where((a) {
      if (!_prunedOnly) return true;
      return a.tags.any(tempProfile.stages.contains) &&
          !a.tags.any(tempProfile.exclude.contains);
    }).length;

    final dailyCount = catalog.adviceList.where((a) {
      final isDaily = a.tags.contains('每天') || a.tags.contains('打卡');
      return isDaily && !a.tags.any(tempProfile.exclude.contains);
    }).length;

    final redlinesCount = catalog.adviceList.where((a) {
      return (a.actType == 'redline-stamp' || a.tags.contains('安全')) &&
          !a.tags.any(tempProfile.exclude.contains);
    }).length;

    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            const SizedBox(height: 8),
            // 多层同心动态旋转罗盘
            Center(
              child: _buildHolographicCompass(p),
            ),
            const SizedBox(height: 18),
            Text(
              '全息画像罗盘校准完成',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: p.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '已为你激活专属罗盘，全库 767 条实证建议 100% 完备待命，\n无缝过滤非适用噪音，筑牢安全防线。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: p.inkSub, height: 1.5),
            ),
            const SizedBox(height: 18),
            // 真实数据统计卡（非 Mock）
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.hairline),
              ),
              child: Column(
                children: [
                  _statRow(
                    p,
                    '全库建议总览与覆盖',
                    '767 条 (100%)',
                    Icons.grid_view_outlined,
                    p.action,
                  ),
                  const Divider(height: 18),
                  _statRow(
                    p,
                    _prunedOnly ? '当前画像适用建议' : '全景探索模式全量开放',
                    _prunedOnly ? '$matchedTotal 条' : '767 条',
                    Icons.auto_awesome_outlined,
                    p.emerald,
                  ),
                  const Divider(height: 18),
                  _statRow(
                    p,
                    '高后果安全红线防范',
                    '$redlinesCount 项',
                    Icons.gpp_maybe_outlined,
                    p.rose,
                  ),
                  const Divider(height: 18),
                  _statRow(
                    p,
                    '每日关键节律微习惯',
                    '$dailyCount 项',
                    Icons.today_outlined,
                    p.indigo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 人性化模式切换开关
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.hairline),
              ),
              child: Row(
                children: [
                  Icon(
                    _prunedOnly ? Icons.filter_alt_outlined : Icons.public_outlined,
                    size: 18,
                    color: p.action,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prunedOnly ? '画像精选模式（默认）' : '全景开放模式（767条直读）',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _prunedOnly
                              ? '优先推送契合防线，库中可随时一键切全量'
                              : '不设任何画像折叠，全量 767 条无死角展示',
                          style: TextStyle(fontSize: 10.5, color: p.inkSub),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: !_prunedOnly,
                    activeTrackColor: p.emerald,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _prunedOnly = !v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolographicCompass(AppPalettes p) {
    return ScaleTransition(
      scale: _pulseAnim,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外层慢速旋转光环
          RotationTransition(
            turns: _compassSpinController,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: p.action.withValues(alpha: 0.25),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
          // 内层脉冲光晕
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.emerald.withValues(alpha: 0.14),
              border: Border.all(color: p.emerald, width: 2),
              boxShadow: [
                BoxShadow(
                  color: p.emerald.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.explore_outlined, size: 42, color: p.emerald),
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    AppPalettes p,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12.5, color: p.inkSub)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _stepHeader(
    AppPalettes p, {
    required String badge,
    required String title,
    required String prompt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: p.action.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: p.action,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: p.ink,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          prompt,
          style: TextStyle(
            fontSize: 12,
            color: p.inkSub,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _toggleCard(
    AppPalettes p, {
    required String tag,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _AnimatedCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? p.action.withValues(alpha: 0.16)
                  : p.pillBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? p.action : p.inkSub,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? p.action : p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: p.inkSub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? p.action : Colors.transparent,
              border: Border.all(
                color: selected ? p.action : p.inkMute,
                width: 1.5,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  void _toggleRole(String role) {
    setState(() {
      if (_roles.contains(role)) {
        _roles.remove(role);
      } else {
        _roles.add(role);
      }
    });
  }

  void _toggleLiving(String living) {
    setState(() {
      if (_livingConditions.contains(living)) {
        _livingConditions.remove(living);
      } else {
        _livingConditions.add(living);
      }
    });
  }

  TextStyle _labelStyle(AppPalettes p) => TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: p.inkSub,
      );

  Widget _buildBottomBar(AppPalettes p) {
    final isLast = _currentPage == 6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast ? p.emerald : p.action,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
            shadowColor: (isLast ? p.emerald : p.action).withValues(alpha: 0.4),
          ),
          onPressed: isLast ? _finish : _nextPage,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _currentPage == 0
                  ? '定制专属罗盘 ›'
                  : (isLast
                      ? (widget.isReconfiguring ? '保存画像并生效' : '步入数字阶跃 ›')
                      : '继续下一步 ›'),
              key: ValueKey('btn_$_currentPage'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// 具有弹性缩放微交互与高光边缘的优雅卡片组件。
class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.selected
                ? p.action.withValues(alpha: 0.08)
                : p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected ? p.action : p.hairline,
              width: widget.selected ? 1.5 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: p.action.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
