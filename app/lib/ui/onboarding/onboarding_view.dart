import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';

/// 初次开启应用时的优雅全息画像引导向导。
///
/// 引导语深度融合《高性价比人生指南》767 条实证建议：
/// - 生命节点（年龄/生理性别/健康筛查包）
/// - 职场防线（上班族/程序员灰产红线/创业合规）
/// - 家庭守护（老人照护/育儿急救/伴侣财产底线）
/// - 生活常态（租房/购房/司机安全带/出境）
/// 交互体验：柔和分页动效、触感反馈、卡片微弹动效、实时画像命中测算。
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
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 用户正在配置的画像状态
  late String _gender;
  late int _age;
  late Set<String> _roles;
  late Set<String> _livingConditions;
  late Set<String> _healthConcerns;

  // 终末页面的动画控制器
  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );

    // 默认初始值
    _gender = '男';
    _age = 28;
    _roles = {'全民', '上班族', '伴侣', '家人'};
    _livingConditions = {'租房人'};
    _healthConcerns = {'久坐伏案'};
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
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  UserProfile _buildProfile() {
    return UserProfile(
      gender: _gender,
      age: _age,
      roles: _roles.toList(),
      livingConditions: _livingConditions.toList(),
      healthConcerns: _healthConcerns.toList(),
      prunedOnly: true,
      parentsOnly: false,
    );
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    HapticFeedback.mediumImpact();
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
            // 顶栏进度与导航
            _buildTopBar(p),
            // 内容分页
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                  if (idx == 5) {
                    _animController.repeat(reverse: true);
                  } else {
                    _animController.stop();
                  }
                },
                children: [
                  _buildStep0Prologue(p, isDark),
                  _buildStep1AgeGender(p),
                  _buildStep2Career(p),
                  _buildStep3Family(p),
                  _buildStep4Lifestyle(p),
                  _buildStep5Synthesis(p),
                ],
              ),
            ),
            // 底栏切换按钮
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
              children: List.generate(6, (i) {
                final active = i == _currentPage;
                final done = i < _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? p.action
                        : (done ? p.emerald : p.hairline),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                );
              }),
            ),
          ),
          if (_currentPage < 5 && !widget.isReconfiguring)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _pageController.animateToPage(
                  5,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                );
              },
              child: Text(
                '默认',
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

  // --- Step 0: 启程序言 ---
  Widget _buildStep0Prologue(AppPalettes p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: p.action.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '纯本地优先 · 767 条实证建议转化',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.action,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '数字阶跃\nKairosStep',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: p.ink,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '生活不需要一次性记住 767 条建议，\n只需要在关键节点与日常时钟里，\n做对那几件真正划算的事。',
            style: TextStyle(
              fontSize: 15,
              color: p.inkSub,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _buildPurityGuaranteeCard(p),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPurityGuaranteeCard(AppPalettes p) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.shield_outlined, size: 16, color: p.emerald),
              const SizedBox(width: 8),
              Text(
                '真正交付用户的纯净承诺',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bullet(p, '100% 离线沙盒存储，不上传任何云端服务器'),
          _bullet(p, '零隐私索取：不访问通讯录、相册、蓝牙与麦克风'),
          _bullet(p, '无算法窥探与广告画像，所有计算纯在你的手机端完成'),
        ],
      ),
    );
  }

  Widget _bullet(AppPalettes p, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✓ ', style: TextStyle(color: p.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1: 生命节点与健康防线 ---
  Widget _buildStep1AgeGender(AppPalettes p) {
    final milestone = _getAgeMilestone(_age);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      children: [
        _stepHeader(
          p,
          badge: '01 / 04 · 生命时钟',
          title: '年龄与生理节点',
          prompt: '「有些检查一辈子做一次就够，有些慢病与防癌坎 35 岁就要筑起。」\n你的年龄与生理周期，决定了幽门螺杆菌、血压血糖、疫苗补种与专项筛查的黄金时间窗。',
        ),
        const SizedBox(height: 20),
        Text('生理性别（决定乳腺/骨密度/孕产等专项谓词）', style: _labelStyle(p)),
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
            Text(
              '$_age 岁',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: p.action,
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
            setState(() => _age = v.round());
          },
        ),
        const SizedBox(height: 10),
        // 动态根据年龄呈现的《人生指南》实证节点解析
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.action.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline_outlined, size: 14, color: p.action),
                  const SizedBox(width: 6),
                  Text(
                    milestone.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.action,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                milestone.desc,
                style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _genderCard(AppPalettes p, String gender, IconData icon, String note) {
    final selected = _gender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _gender = gender);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? p.action.withValues(alpha: 0.12) : p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? p.action : p.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
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
      ),
    );
  }

  ({String title, String desc}) _getAgeMilestone(int age) {
    if (age <= 22) {
      return (
        title: '少年与成年早期节点',
        desc: '重点构建早期法律底线、防兼职刷单陷阱，补齐成年基础疫苗（乙肝、HPV 等）。'
      );
    }
    if (age <= 34) {
      return (
        title: '青年奋斗期节点',
        desc: '重点守护雇佣劳动合同、工资条备份、婚恋财务透明与久坐工位健康防守。'
      );
    }
    if (age <= 44) {
      return (
        title: '35 岁慢病关键节点',
        desc: '国家每年免费量血压、空腹血糖与血脂检测启动，幽门螺杆菌根除，防范心脑血管隐患。'
      );
    }
    if (age <= 49) {
      return (
        title: '45 岁专项防癌坎',
        desc: '结直肠癌筛查（粪便隐血/肠镜）、胃镜与乳腺钼靶检查进入高频防线，守住家庭财务底盘。'
      );
    }
    if (age <= 64) {
      return (
        title: '50 岁疫苗与慢性病节点',
        desc: '带状疱疹疫苗（防效率 97%）两针接种，骨骼关节保养，长期慢病规范用药。'
      );
    }
    return (
      title: '65 岁银发关怀节点',
      desc: '双能 X 线骨密度检查、肺炎球菌疫苗、防跌倒家庭适老化改造与国家免费老年体检。'
    );
  }

  // --- Step 2: 职业与职场防御 ---
  Widget _buildStep2Career(AppPalettes p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      children: [
        _stepHeader(
          p,
          badge: '02 / 04 · 职场生态',
          title: '核心职业形态',
          prompt: '「别把自己搭进去。上班、创业或写代码，劳动维权、防范灰产与固化工资证据，是第一位的划算。」\n系统将为你激活专属的法律红线与职场防御规则：',
        ),
        const SizedBox(height: 16),
        _toggleCard(
          p,
          tag: '上班族',
          icon: Icons.business_center_outlined,
          title: '企业雇员 / 上班族',
          subtitle: '劳动合同 7 天核对 · 工资条离线留痕 · 试用期辞退避坑 · 工伤维权',
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
    );
  }

  // --- Step 3: 家庭与守护责任 ---
  Widget _buildStep3Family(AppPalettes p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      children: [
        _stepHeader(
          p,
          badge: '03 / 04 · 守护责任',
          title: '家庭与重要关系',
          prompt: '「守护家人的底气，不是事后的焦虑慌乱，而是提前掌握急救常识、防骗机制与照护路径。」\n你此刻肩负着哪些亲情与守护职责？',
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
    );
  }

  // --- Step 4: 居住与生活日常 ---
  Widget _buildStep4Lifestyle(AppPalettes p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      children: [
        _stepHeader(
          p,
          badge: '04 / 04 · 生活常态',
          title: '居住与日常情境',
          prompt: '「日常最大的风险往往藏在最熟悉的习惯里：上下车扣紧安全带、合租房查验产权、大额转账 24 小时冷静。」\n勾选你当前的日常生活状态：',
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
    );
  }

  // --- Step 5: 罗盘校准与阶跃生成 ---
  Widget _buildStep5Synthesis(AppPalettes p) {
    final catalog = catalogOf(context);
    final tempProfile = _buildProfile();

    // 动态基于真实 767 数据计算，拒绝任何 Mock！
    final matchedTotal = catalog.adviceList.where((a) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          const Spacer(),
          // 优雅呼吸罗盘环
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.emerald.withValues(alpha: 0.12),
                border: Border.all(color: p.emerald, width: 2),
              ),
              child: Icon(Icons.explore_outlined, size: 48, color: p.emerald),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '全息画像罗盘校准完成',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已为你从全库 767 条建议中萃取专属行动，\n无缝过滤非适用噪音，筑牢安全防线。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: p.inkSub, height: 1.5),
          ),
          const SizedBox(height: 24),
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
                _statRow(p, '当前画像适用建议', '$matchedTotal 条', Icons.auto_awesome_outlined, p.action),
                const Divider(height: 20),
                _statRow(p, '高后果安全红线防范', '$redlinesCount 项', Icons.gpp_maybe_outlined, p.rose),
                const Divider(height: 20),
                _statRow(p, '每日关键节律微习惯', '$dailyCount 项', Icons.today_outlined, p.emerald),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _statRow(AppPalettes p, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12.5, color: p.inkSub)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
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
            fontWeight: FontWeight.w800,
            color: p.ink,
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? p.action.withValues(alpha: 0.08) : p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? p.action : p.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentPage == 5 ? p.emerald : p.action,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          onPressed: _currentPage == 5 ? _finish : _nextPage,
          child: Text(
            _currentPage == 0
                ? '定制专属罗盘 ›'
                : (_currentPage == 5
                    ? (widget.isReconfiguring ? '保存画像并生效' : '步入数字阶跃 ›')
                    : '继续下一步 ›'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
