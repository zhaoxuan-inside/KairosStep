import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';

/// 全新全息画像引导向导：实现动态级联展开与实时标签剪枝。
///
/// 核心突破：
/// 1. 100% 覆盖 767 条建议与六大支柱，消灭死角；
/// 2. 动态级联剪枝：根据已选标签（如性别、有无车、有无小孩、是否租房、是否吸烟）智能剪掉无关分支；
/// 3. 即时反馈量化：每一步实时计算“已激活专属建议数”与“已剪枝过滤建议数”。
class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    this.isReconfiguring = false,
    this.onComplete,
  });

  final bool isReconfiguring;
  final VoidCallback? onComplete;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 用户正在配置的全息画像状态
  late String _gender;
  late int _age;
  late bool _hasCar;
  late bool _hasTwowheeler;
  late String _livingStatus; // 'tenant', 'owner_loan', 'owner_free'
  late bool _hasPipedGas;
  late bool _hasPets;
  late String _relationshipStatus; // 'single', 'partner'
  late bool _hasChildren;
  late String _childAgeStage; // 'none', 'infant', 'school'
  late bool _hasAgingParents;
  late String _careerType; // 'employed', 'programmer', 'entrepreneur', 'student', 'freelance'
  late bool _isSmoker;
  late bool _hasHypertension;
  late bool _hasDiabetes;
  late bool _hasKidneyStones;
  late bool _hasGout;
  late bool _hasDeskJob;
  late bool _prunedOnly;

  // 罗盘与呼吸动效
  late AnimationController _compassSpinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // 分页入场动效
  late AnimationController _pageAnimController;
  late Animation<double> _pageFadeAnim;
  late Animation<Offset> _pageSlideAnim;

  @override
  void initState() {
    super.initState();
    // 默认初始画像
    _gender = '男';
    _age = 28;
    _hasCar = false;
    _hasTwowheeler = true;
    _livingStatus = 'tenant';
    _hasPipedGas = true;
    _hasPets = false;
    _relationshipStatus = 'single';
    _hasChildren = false;
    _childAgeStage = 'none';
    _hasAgingParents = false;
    _careerType = 'employed';
    _isSmoker = false;
    _hasHypertension = false;
    _hasDiabetes = false;
    _hasKidneyStones = false;
    _hasGout = false;
    _hasDeskJob = true;
    _prunedOnly = true;

    // 动画控制器
    _compassSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pageFadeAnim = CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    );
    _pageSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.03),
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
      _hasCar = cur.hasCar;
      _hasTwowheeler = cur.hasTwowheeler;
      _livingStatus = cur.hasMortgage ? 'owner_loan' : (cur.isTenant ? 'tenant' : 'owner_free');
      _hasPipedGas = cur.hasPipedGas;
      _hasPets = cur.hasPets;
      _relationshipStatus = cur.roles.contains('伴侣') ? 'partner' : 'single';
      _hasChildren = cur.hasChildren || cur.roles.contains('家长');
      _childAgeStage = cur.childAgeStage;
      _hasAgingParents = cur.hasAgingParents || cur.livingConditions.contains('家有老人');
      if (cur.roles.contains('程序员')) {
        _careerType = 'programmer';
      } else if (cur.isEntrepreneur || cur.roles.contains('创业者')) {
        _careerType = 'entrepreneur';
      } else if (cur.roles.contains('学生')) {
        _careerType = 'student';
      } else if (cur.roles.contains('灵活就业者')) {
        _careerType = 'freelance';
      } else {
        _careerType = 'employed';
      }
      _isSmoker = cur.isSmoker;
      _hasHypertension = cur.hasHypertension || cur.healthConcerns.contains('血压关注');
      _hasDiabetes = cur.hasDiabetes || cur.healthConcerns.contains('血糖关注');
      _hasKidneyStones = cur.hasKidneyStones || cur.healthConcerns.contains('肾结石');
      _hasGout = cur.hasGout || cur.healthConcerns.contains('痛风');
      _hasDeskJob = cur.healthConcerns.contains('久坐伏案');
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

  /// 基于当前界面临时配置构建出的 UserProfile
  UserProfile _buildCurrentProfile() {
    final roles = <String>['全民'];
    if (_careerType == 'employed') roles.add('上班族');
    if (_careerType == 'programmer') roles.addAll(['上班族', '程序员']);
    if (_careerType == 'entrepreneur') roles.addAll(['创业者', '合伙人']);
    if (_careerType == 'student') roles.add('学生');
    if (_careerType == 'freelance') roles.add('灵活就业者');

    if (_hasCar) roles.add('司机');
    if (_hasChildren || _childAgeStage != 'none') roles.add('家长');
    if (_relationshipStatus == 'partner') roles.add('伴侣');

    final living = <String>[];
    if (_livingStatus == 'tenant') living.add('租房人');
    if (_livingStatus == 'owner_loan') living.add('购房人');
    if (_hasAgingParents) living.add('家有老人');
    if (_hasPets) living.add('养犬人');

    final health = <String>[];
    if (_hasDeskJob) health.add('久坐伏案');
    if (_isSmoker) health.add('吸烟者');
    if (_hasHypertension) health.add('血压关注');
    if (_hasDiabetes) health.add('血糖关注');
    if (_hasKidneyStones) health.add('肾结石');
    if (_hasGout) health.add('痛风');

    return UserProfile(
      gender: _gender,
      age: _age,
      roles: roles,
      livingConditions: living,
      healthConcerns: health,
      prunedOnly: _prunedOnly,
      hasCar: _hasCar,
      hasTwowheeler: _hasTwowheeler,
      hasChildren: _hasChildren,
      hasAgingParents: _hasAgingParents,
      isSmoker: _isSmoker,
      hasPets: _hasPets,
      hasPipedGas: _hasPipedGas,
      hasMortgage: _livingStatus == 'owner_loan',
      isTenant: _livingStatus == 'tenant',
      isEntrepreneur: _careerType == 'entrepreneur',
      hasHypertension: _hasHypertension,
      hasDiabetes: _hasDiabetes,
      hasKidneyStones: _hasKidneyStones,
      hasGout: _hasGout,
      childAgeStage: _hasChildren ? _childAgeStage : 'none',
      relationshipStatus: _relationshipStatus,
    ).normalized();
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _complete() {
    HapticFeedback.heavyImpact();
    final finalProfile = _buildCurrentProfile();
    final store = storeOf(context);
    store.completeOnboarding(finalProfile);

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(p),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                  _pageAnimController.forward(from: 0.0);
                  if (idx == 7) {
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
                  _buildStep2Mobility(p),
                  _buildStep3Housing(p),
                  _buildStep4Family(p),
                  _buildStep5Career(p),
                  _buildStep6Health(p),
                  _buildStep7Synthesis(p),
                ],
              ),
            ),
            _buildBottomBar(p),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalettes p) {
    final catalog = catalogOf(context);
    final tempProfile = _buildCurrentProfile();
    final activeCount = catalog.adviceList.where((a) {
      // 模拟 matchPersona 逻辑
      if (a.prerequisites.isNotEmpty) {
        final pr = a.prerequisites;
        if (pr['has_car'] == true && !tempProfile.hasCar) return false;
        if (pr['has_twowheeler'] == true && !tempProfile.hasTwowheeler) return false;
        if (pr['is_smoker'] == true && !tempProfile.isSmoker) return false;
        if (pr['has_children'] == true && !tempProfile.hasChildren && !tempProfile.roles.contains('家长')) return false;
        if (pr['has_aging_parents'] == true && !tempProfile.hasAgingParents && !tempProfile.livingConditions.contains('家有老人')) return false;
        if (pr['is_tenant'] == true && !tempProfile.isTenant && !tempProfile.livingConditions.contains('租房人')) return false;
        if (pr['has_mortgage'] == true && !tempProfile.hasMortgage && !tempProfile.livingConditions.contains('购房人')) return false;
        if (pr['has_pets'] == true && !tempProfile.hasPets && !tempProfile.livingConditions.contains('养犬人')) return false;
        if (pr['has_piped_gas'] == true && !tempProfile.hasPipedGas) return false;
        if (pr['is_entrepreneur'] == true && !tempProfile.isEntrepreneur) return false;
        if (pr['gender_female'] == true && tempProfile.gender != '女') return false;
        if (pr['gender_male'] == true && tempProfile.gender != '男') return false;
        if (pr['min_age'] is int && tempProfile.age < (pr['min_age'] as int)) return false;
      }
      return true;
    }).length;

    final prunedCount = 767 - activeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentPage > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: _prevPage,
                  tooltip: '上一步',
                )
              else
                const SizedBox(width: 40),
              const Spacer(),
              // 实时剪枝指标指示器
              if (_currentPage > 0 && _currentPage < 7)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.action.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: p.action.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt_outlined, size: 12, color: p.action),
                      const SizedBox(width: 4),
                      Text(
                        '专属激活 $activeCount · 剪枝降噪 $prunedCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.action,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (_currentPage < 7 && !widget.isReconfiguring)
                TextButton(
                  onPressed: _complete,
                  child: Text('跳过', style: TextStyle(color: p.inkSub, fontSize: 13)),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 8),
          // 步进指示条 (0 ~ 7)
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 8,
              minHeight: 3.5,
              backgroundColor: p.inkMute.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(p.action),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Step 0: 序幕与极简守护哲学
  // ==========================================================================
  Widget _buildStep0Prologue(AppPalettes p, bool isDark) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [p.action, p.action.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.action.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                '拒绝无关噪音\n只留你的专属守护',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: p.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '全书 767 条硬核建议，不是每个人都需要。\n没有私家车，就不推车载安全带；不吸烟，就不推戒烟干预；未为人父母，就不推婴幼儿防窒息。\n\n花 1 分钟点选你的真实生活实体，我们将根据你的选择进行动态剪枝，为你定制专属的生命防御网络。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: p.inkSub,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: p.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: p.emerald),
                    const SizedBox(width: 6),
                    Text(
                      '完全离线运行 · 数据仅存本机',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.emerald),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 1: 生命时钟（年龄与生理性别）
  // ==========================================================================
  Widget _buildStep1AgeGender(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '01 / 07 · 生命时钟',
              title: '生理性别与年龄阶段',
              prompt: '医学筛查与疫苗接种具有强烈的生理窗口期。你的年龄与生理周期，决定了空腹血糖早筛、带状疱疹疫苗与癌症筛查的出现节点。',
            ),
            const SizedBox(height: 20),
            Text('生理性别', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _selectableChip(
                    p,
                    label: '男',
                    icon: Icons.male,
                    selected: _gender == '男',
                    onTap: () => setState(() => _gender = '男'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectableChip(
                    p,
                    label: '女',
                    icon: Icons.female,
                    selected: _gender == '女',
                    onTap: () => setState(() => _gender = '女'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('当前年龄', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
                Text('$_age 岁', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.action)),
              ],
            ),
            Slider(
              value: _age.toDouble(),
              min: 16,
              max: 85,
              divisions: 69,
              activeColor: p.action,
              label: '$_age 岁',
              onChanged: (v) => setState(() => _age = v.round()),
            ),
            const SizedBox(height: 12),
            // 动态级联医学里程碑预览
            _buildAgeMilestoneCard(p),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeMilestoneCard(AppPalettes p) {
    final tips = <String>[];
    if (_gender == '女' && _age >= 30) tips.add('已为你激活：30 岁+ 宫颈癌 HPV 专项筛查防御');
    if (_gender == '女' && _age >= 40) tips.add('已为你激活：40 岁+ 乳腺钼靶早期防癌检查');
    if (_gender == '男') tips.add('已为你激活：男性心血管与代谢连带健康自检');
    if (_age >= 35) tips.add('已为你激活：35 岁超重空腹血糖筛查节点');
    if (_age >= 45) tips.add('已为你激活：45 岁结直肠癌肠镜早筛');
    if (_age >= 50) tips.add('已为你激活：50 岁带状疱疹疫苗接种窗口');
    if (_age >= 65) tips.add('已为你激活：65 岁骨密度检查与肺炎球菌疫苗');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.action.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.action.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: p.action),
              const SizedBox(width: 6),
              Text('当前年龄与性别自动解锁的医学防御：', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.action)),
            ],
          ),
          const SizedBox(height: 6),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('• $t', style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.35)),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Step 2: 交通出行与装备（级联剪枝）
  // ==========================================================================
  Widget _buildStep2Mobility(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '02 / 07 · 交通出行',
              title: '主要通行方式与载具',
              prompt: '「出行安全必须和载具物理绑定。」有车才推车载蓝牙安全带与轮胎保养；有电动车才推头盔与电池不进楼。',
            ),
            const SizedBox(height: 16),
            _toggleCard(
              p,
              title: '🚗 拥有私家车 / 开车出行',
              subtitle: '常驾车或家庭拥有机动车',
              selected: _hasCar,
              onTap: () => setState(() => _hasCar = !_hasCar),
              // 级联展开内容
              cascadeContent: _hasCar
                  ? _cascadeBox(p, [
                      '已激活：车载蓝牙连接 3~5 秒即时提醒扣紧安全带',
                      '已激活：刹车油、轮胎胎压定期自检与雨雪防滑',
                      if (_hasChildren) '已激活：4 岁以下儿童专用安全座椅合规提醒',
                    ])
                  : null,
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '🛵 拥有电动自行车 / 摩托车',
              subtitle: '常骑行两轮电瓶车通勤或代步',
              selected: _hasTwowheeler,
              onTap: () => setState(() => _hasTwowheeler = !_hasTwowheeler),
              cascadeContent: _hasTwowheeler
                  ? _cascadeBox(p, [
                      '已激活：骑行戴好 3C 认证头盔并扣牢搭扣',
                      '已激活：电瓶车电池绝不推进楼道、电梯与家中充电',
                      '已激活：雨雪湿滑路面防侧滑与防风被安全警示',
                    ])
                  : null,
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '🚇 公共交通 / 步行通勤',
              subtitle: '主要依赖地铁、公交或徒步出行',
              selected: !_hasCar && !_hasTwowheeler,
              onTap: () => setState(() {
                _hasCar = false;
                _hasTwowheeler = false;
              }),
              cascadeContent: (!_hasCar && !_hasTwowheeler)
                  ? _cascadeBox(p, [
                      '已智能剪枝：完全屏蔽所有机动车硬件保养与电瓶车电池打卡',
                      '已激活：上下车防挤压踏空、雨雪天鞋底防滑',
                    ])
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 3: 居住环境与房产（级联剪枝）
  // ==========================================================================
  Widget _buildStep3Housing(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '03 / 07 · 居住资产',
              title: '住房状态与家居设施',
              prompt: '租房重点在押金转租维权；有房贷重点在提前还款与物业；厨房燃气关乎生命红线。',
            ),
            const SizedBox(height: 16),
            Text('房产与居住状态 (单选)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            _radioCard(
              p,
              title: '🏠 租房生活',
              subtitle: '租住商品房、公寓或合租',
              selected: _livingStatus == 'tenant',
              onTap: () => setState(() => _livingStatus = 'tenant'),
              cascadeContent: _livingStatus == 'tenant'
                  ? _cascadeBox(p, [
                      '已激活：租房查验房产证与二房东转租原件',
                      '已激活：押金退还与设施交接留痕维权',
                      '已激活：公租房排号与免税租房公积金提取',
                      '已剪枝：自动屏蔽房贷还款测算与业主维修基金纠纷',
                    ])
                  : null,
            ),
            const SizedBox(height: 8),
            _radioCard(
              p,
              title: '📑 自有住房 (有房贷)',
              subtitle: '已购房且按月偿还商业/公积金房贷',
              selected: _livingStatus == 'owner_loan',
              onTap: () => setState(() => _livingStatus = 'owner_loan'),
              cascadeContent: _livingStatus == 'owner_loan'
                  ? _cascadeBox(p, [
                      '已激活：房贷利率调整与提前还贷理性测算',
                      '已激活：物业费纠纷与业委会维修基金监督',
                      '已剪枝：自动屏蔽租房合同与二房东套路',
                    ])
                  : null,
            ),
            const SizedBox(height: 8),
            _radioCard(
              p,
              title: '🏡 自有住房 (无贷款)',
              subtitle: '全款购房或房贷已结清',
              selected: _livingStatus == 'owner_free',
              onTap: () => setState(() => _livingStatus = 'owner_free'),
            ),
            const SizedBox(height: 16),
            Text('家庭关键设施与伴侣宠物', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            _toggleCard(
              p,
              title: '🔥 厨房使用管道燃气 / 烧煤',
              subtitle: '家中使用燃气灶、燃气热水器或煤炉',
              selected: _hasPipedGas,
              onTap: () => setState(() => _hasPipedGas = !_hasPipedGas),
              cascadeContent: _hasPipedGas
                  ? _cascadeBox(p, [
                      '已激活：燃气橡胶管到期更换金属波纹管',
                      '已激活：室内取暖一氧化碳报警器年度检查',
                    ])
                  : null,
            ),
            const SizedBox(height: 8),
            _toggleCard(
              p,
              title: '🐾 养犬 / 养猫等伴侣宠物',
              subtitle: '家中饲养犬猫等小动物',
              selected: _hasPets,
              onTap: () => setState(() => _hasPets = !_hasPets),
              cascadeContent: _hasPets
                  ? _cascadeBox(p, [
                      '已激活：狂犬疫苗定期接种与外出牵引安全',
                      '已激活：宠物定期体内外驱虫健康提醒',
                    ])
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 4: 家庭责任与亲密关系（级联剪枝）
  // ==========================================================================
  Widget _buildStep4Family(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '04 / 07 · 家庭羁绊',
              title: '情感状态与扶养照护',
              prompt: '未育家庭自动剪掉全部育儿细节；无长辈同住自动剪掉适老化扶手；只留真实家庭防线。',
            ),
            const SizedBox(height: 16),
            Text('情感与婚姻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _selectableChip(
                    p,
                    label: '单身独居',
                    icon: Icons.person_outline,
                    selected: _relationshipStatus == 'single',
                    onTap: () => setState(() => _relationshipStatus = 'single'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectableChip(
                    p,
                    label: '恋爱 / 已婚伴侣',
                    icon: Icons.favorite_border,
                    selected: _relationshipStatus == 'partner',
                    onTap: () => setState(() => _relationshipStatus = 'partner'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('抚育子女 (深度级联剪枝)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            _toggleCard(
              p,
              title: '👶 家有小孩 / 抚育子女',
              subtitle: '承担未成年子女抚养与监护职责',
              selected: _hasChildren,
              onTap: () => setState(() {
                _hasChildren = !_hasChildren;
                if (!_hasChildren) _childAgeStage = 'none';
                if (_hasChildren && _childAgeStage == 'none') _childAgeStage = 'infant';
              }),
              cascadeContent: _hasChildren
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('请选择孩子当前阶段 (精准激活阶段建议)：', style: TextStyle(fontSize: 11, color: p.inkSub)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _selectableChip(
                                p,
                                label: '🍼 婴幼儿 (0~3岁)',
                                selected: _childAgeStage == 'infant',
                                onTap: () => setState(() => _childAgeStage = 'infant'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _selectableChip(
                                p,
                                label: '🎒 少儿与学龄 (3~18岁)',
                                selected: _childAgeStage == 'school',
                                onTap: () => setState(() => _childAgeStage = 'school'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_childAgeStage == 'infant')
                          _cascadeBox(p, [
                            '已激活：新生儿软床窒息防范与母乳科学喂养',
                            '已激活：儿童发热禁用含安乃近/尼美舒利复方感冒药',
                            if (_hasCar) '已激活：机动车 4 岁以下后排反向安全座椅',
                          ])
                        else
                          _cascadeBox(p, [
                            '已激活：阳台与开合窗户安装防坠限位器 (纱窗不顶用)',
                            '已激活：儿童近水不离视线与野泳救生衣防溺水',
                            '已激活：近视防控与上学心理适应',
                          ]),
                      ],
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text('长辈孝亲', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            _toggleCard(
              p,
              title: '🧓 家有老人 / 需照护父母',
              subtitle: '家中父母年过六旬，或需日常照护',
              selected: _hasAgingParents,
              onTap: () => setState(() => _hasAgingParents = !_hasAgingParents),
              cascadeContent: _hasAgingParents
                  ? _cascadeBox(p, [
                      '已激活：浴室与楼梯适老化改造 (防滑扶手/防跌摔)',
                      '已激活：长辈骨质疏松筛查、流感与带状疱疹疫苗补种',
                      '已激活：老年人保健品与电信诈骗专属心理关怀',
                    ])
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 5: 职业生态与工作场景（级联剪枝）
  // ==========================================================================
  Widget _buildStep5Career(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '05 / 07 · 职场生态',
              title: '核心职业形态',
              prompt: '「上班维权留痕，做生意隔离家底。」根据身份精准过滤对应的劳动法红线与合伙契约。',
            ),
            const SizedBox(height: 16),
            _radioCard(
              p,
              title: '💼 企业在职员工 / 打工人',
              subtitle: '与用人单位签署全职或兼职劳动合同',
              selected: _careerType == 'employed',
              onTap: () => setState(() => _careerType = 'employed'),
              cascadeContent: _careerType == 'employed'
                  ? _cascadeBox(p, [
                      '已激活：每月发薪日核查工资条与五险一金基数',
                      '已激活：离职、裁员、调岗补偿法定标准留痕',
                      '已激活：工伤认定时限与劳动仲裁证据保全',
                    ])
                  : null,
            ),
            const SizedBox(height: 8),
            _radioCard(
              p,
              title: '💻 程序员 / 技术从业者',
              subtitle: '从事软件开发、运维、数据与技术岗',
              selected: _careerType == 'programmer',
              onTap: () => setState(() => _careerType = 'programmer'),
              cascadeContent: _careerType == 'programmer'
                  ? _cascadeBox(p, [
                      '已激活：网络爬虫合规边界与开源协议反向侵权',
                      '已激活：数据跨境传输红线与私活外包免责条款',
                      '已激活：在职打工人五险一金全套防御体系',
                    ])
                  : null,
            ),
            const SizedBox(height: 8),
            _radioCard(
              p,
              title: '🚀 创业者 / 公司法定代表人 / 合伙人',
              subtitle: '开办企业、店铺或组建合伙团队',
              selected: _careerType == 'entrepreneur',
              onTap: () => setState(() => _careerType = 'entrepreneur'),
              cascadeContent: _careerType == 'entrepreneur'
                  ? _cascadeBox(p, [
                      '已激活：公司有限责任债务隔离 (绝不轻易连带个人担保)',
                      '已激活：合伙人退出机制、股权架构与资质审批备案',
                      '已剪枝：自动屏蔽普通打工人劳动仲裁条目',
                    ])
                  : null,
            ),
            const SizedBox(height: 8),
            _radioCard(
              p,
              title: '🎓 学生 / 备考求职者',
              subtitle: '高校在读、研究生或应届求职中',
              selected: _careerType == 'student',
              onTap: () => setState(() => _careerType = 'student'),
              cascadeContent: _careerType == 'student'
                  ? _cascadeBox(p, [
                      '已激活：高性价比技能树投资与实习合规',
                      '已激活：防兼职套路贷与培训贷诈骗',
                    ])
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 6: 生活习惯与健康关注（级联剪枝）
  // ==========================================================================
  Widget _buildStep6Health(AppPalettes p) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          children: [
            _stepHeader(
              p,
              badge: '06 / 07 · 身体自检',
              title: '健康关注与生活习性',
              prompt: '非吸烟者绝不推戒烟干预；健康无慢病者不打扰早晚测压；精准匹配真实身体防线。',
            ),
            const SizedBox(height: 16),
            _toggleCard(
              p,
              title: '🚭 我有吸烟习惯 (需戒烟守护)',
              subtitle: '目前吸烟或正处于戒烟过渡期',
              selected: _isSmoker,
              onTap: () => setState(() => _isSmoker = !_isSmoker),
              cascadeContent: _isSmoker
                  ? _cascadeBox(p, [
                      '已激活：戒烟日一次性停掉、伐尼克兰戒烟门诊辅助',
                      '已激活：重度吸烟者低剂量胸部 CT 年度筛查',
                    ])
                  : _cascadeBox(p, [
                      '已智能剪枝：完全屏蔽所有戒烟药与吸烟干预噪音',
                    ], isMuted: true),
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '🩺 关注 / 确诊高血压',
              subtitle: '血压偏高、已有高血压或长期服药中',
              selected: _hasHypertension,
              onTap: () => setState(() => _hasHypertension = !_hasHypertension),
              cascadeContent: _hasHypertension
                  ? _cascadeBox(p, [
                      '已激活：每日早晚定时量血压并吃药降到达标',
                      '已激活：食盐更换为低钠钾盐方案',
                    ])
                  : null,
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '🩸 关注高血糖 / 糖尿病',
              subtitle: '体检空腹血糖偏高或已有糖尿病指标',
              selected: _hasDiabetes,
              onTap: () => setState(() => _hasDiabetes = !_hasDiabetes),
              cascadeContent: _hasDiabetes
                  ? _cascadeBox(p, [
                      '已激活：35 岁以上空腹血糖常规复查',
                      '已激活：科学饮食与慢病随访管理',
                    ])
                  : null,
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '🥩 关注高尿酸 / 痛风病史',
              subtitle: '尿酸偏高、发作过痛风或常需低嘌呤控制',
              selected: _hasGout,
              onTap: () => setState(() => _hasGout = !_hasGout),
              cascadeContent: _hasGout
                  ? _cascadeBox(p, [
                      '已激活：聚餐与烧烤低嘌呤低醇饮食防御',
                      '已激活：痛风发作期科学应对与降尿酸防线',
                    ])
                  : null,
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '💧 关注肾结石 / 泌尿系结石病史',
              subtitle: '曾得过肾结石或有多发结石体质',
              selected: _hasKidneyStones,
              onTap: () => setState(() => _hasKidneyStones = !_hasKidneyStones),
              cascadeContent: _hasKidneyStones
                  ? _cascadeBox(p, [
                      '已激活：每日 2.5~3 升充足饮水与低盐防复发防线',
                    ])
                  : null,
            ),
            const SizedBox(height: 10),
            _toggleCard(
              p,
              title: '🪑 工位伏案久坐 > 4 小时',
              subtitle: '工作日长时间静坐屏幕前',
              selected: _hasDeskJob,
              onTap: () => setState(() => _hasDeskJob = !_hasDeskJob),
              cascadeContent: _hasDeskJob
                  ? _cascadeBox(p, [
                      '已激活：工作日 10:00 与 15:00 远眺深蹲拉伸时段',
                      '已激活：工位视力保护与颈椎人体工学调节',
                    ])
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 7: 全息画像合成看板（Synthesis）
  // ==========================================================================
  Widget _buildStep7Synthesis(AppPalettes p) {
    final catalog = catalogOf(context);
    final tempProfile = _buildCurrentProfile();

    final activeAdvices = catalog.adviceList.where((a) {
      if (a.prerequisites.isNotEmpty) {
        final pr = a.prerequisites;
        if (pr['has_car'] == true && !tempProfile.hasCar) return false;
        if (pr['has_twowheeler'] == true && !tempProfile.hasTwowheeler) return false;
        if (pr['is_smoker'] == true && !tempProfile.isSmoker) return false;
        if (pr['has_children'] == true && !tempProfile.hasChildren && !tempProfile.roles.contains('家长')) return false;
        if (pr['has_aging_parents'] == true && !tempProfile.hasAgingParents && !tempProfile.livingConditions.contains('家有老人')) return false;
        if (pr['is_tenant'] == true && !tempProfile.isTenant && !tempProfile.livingConditions.contains('租房人')) return false;
        if (pr['has_mortgage'] == true && !tempProfile.hasMortgage && !tempProfile.livingConditions.contains('购房人')) return false;
        if (pr['has_pets'] == true && !tempProfile.hasPets && !tempProfile.livingConditions.contains('养犬人')) return false;
        if (pr['has_piped_gas'] == true && !tempProfile.hasPipedGas) return false;
        if (pr['is_entrepreneur'] == true && !tempProfile.isEntrepreneur) return false;
        if (pr['gender_female'] == true && tempProfile.gender != '女') return false;
        if (pr['gender_male'] == true && tempProfile.gender != '男') return false;
        if (pr['min_age'] is int && tempProfile.age < (pr['min_age'] as int)) return false;
      }
      return true;
    }).toList();

    final total = catalog.adviceList.length;
    final activeCount = activeAdvices.length;
    final prunedCount = total - activeCount;

    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            _stepHeader(
              p,
              badge: '07 / 07 · 全息防御网络',
              title: '量身定制画像已生成',
              prompt: '已完成全量建议的多维级联剪枝。只留与你物理世界相符的关键防线，为你屏蔽全部无关打扰。',
            ),
            const SizedBox(height: 20),
            // 罗盘与数据成果卡
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.surfaceGlass, p.surface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.action.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: p.action.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.emerald.withValues(alpha: 0.12),
                        border: Border.all(color: p.emerald.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.check_circle_outline, size: 38, color: p.emerald),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '已激活 $activeCount 条关键建议',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: p.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '成功剪枝消除 $prunedCount 条非当前场景噪音',
                    style: TextStyle(fontSize: 12.5, color: p.emerald, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('六大支柱激活全景', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.inkSub)),
            const SizedBox(height: 8),
            _pillarCard(p, '身体健康与防病', Icons.health_and_safety_outlined, activeAdvices.where((a) => a.treePath.startsWith('health')).length, p.emerald),
            _pillarCard(p, '日常起居与交通', Icons.access_time_outlined, activeAdvices.where((a) => a.treePath.startsWith('daily')).length, p.action),
            _pillarCard(p, '家庭守护与人际', Icons.family_restroom_outlined, activeAdvices.where((a) => a.treePath.startsWith('relationships')).length, Colors.purple),
            _pillarCard(p, '财产安全与资产', Icons.shield_outlined, activeAdvices.where((a) => a.treePath.startsWith('finance')).length, Colors.amber.shade800),
            _pillarCard(p, '职场事业与学业', Icons.business_center_outlined, activeAdvices.where((a) => a.treePath.startsWith('career')).length, Colors.blue),
            _pillarCard(p, '安全红线与合规', Icons.gpp_maybe_outlined, activeAdvices.where((a) => a.treePath.startsWith('safety')).length, Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _pillarCard(AppPalettes p, String title, IconData icon, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceGlass,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.inkMute.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.ink)),
          const Spacer(),
          Text('$count 条已激活', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ==========================================================================
  // 通用 UI 部件
  // ==========================================================================
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
            color: p.action.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: p.action,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: p.ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          prompt,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: p.inkSub,
          ),
        ),
      ],
    );
  }

  Widget _selectableChip(
    AppPalettes p, {
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? p.action.withValues(alpha: 0.1) : p.surfaceGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.action : p.inkMute.withValues(alpha: 0.18),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? p.action : p.inkSub),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? p.action : p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleCard(
    AppPalettes p, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? cascadeContent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? p.action.withValues(alpha: 0.05) : p.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? p.action : p.inkMute.withValues(alpha: 0.18),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: selected ? p.action : p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(subtitle, style: TextStyle(fontSize: 11.5, color: p.inkSub)),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: selected,
                    activeColor: p.action,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => onTap(),
                  ),
                ],
              ),
              if (cascadeContent != null) ...[
                const SizedBox(height: 8),
                cascadeContent,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioCard(
    AppPalettes p, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? cascadeContent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? p.action.withValues(alpha: 0.05) : p.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? p.action : p.inkMute.withValues(alpha: 0.18),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: selected ? p.action : p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(subtitle, style: TextStyle(fontSize: 11.5, color: p.inkSub)),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: selected ? p.action : p.inkMute,
                  ),
                ],
              ),
              if (cascadeContent != null) ...[
                const SizedBox(height: 8),
                cascadeContent,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cascadeBox(AppPalettes p, List<String> lines, {bool isMuted = false}) {
    final color = isMuted ? p.inkSub : p.action;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $l',
                style: TextStyle(fontSize: 11.5, color: color, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppPalettes p) {
    final isLast = _currentPage == 7;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLast ? _complete : _nextPage,
          child: Text(
            isLast ? '进入 KairosStep 守护网络' : '下一步',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
