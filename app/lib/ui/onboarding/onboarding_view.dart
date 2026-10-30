import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';

/// 10 阶全息画像与生活防线引导向导：
///
/// 特性：
/// 1. 100% 覆盖 737 条建议与 34 个章节、6 大支柱；
/// 2. 深度定制与无死角剪枝：根据用户画像逐阶级联激活或拦截专属防线；
/// 3. 全天候随时跳过：顶部与底部均常驻“跳过/以此配置直接开启”，既给想精细化配置的用户充分的机会，又随时保障用户快速进入；
/// 4. 实时反馈量化：每一步实时动态演算“已激活专属条目数”与“已剪枝降噪数”。
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
  static const int _totalSteps = 11; // 0 (序幕) + 9 (维度定制) + 1 (综合防线生成)

  // 用户全息画像核心状态
  late String _gender;
  late int _age;
  late String _careerType; // 'employed', 'programmer', 'entrepreneur', 'student', 'freelance'
  late bool _isProgrammer;
  late bool _isEntrepreneur;
  late bool _hasDigitalAssetsConcern;
  late bool _hasCar;
  late bool _hasTwowheeler;
  late String _livingStatus; // 'tenant', 'owner_loan', 'owner_free'
  late bool _hasPipedGas;
  late bool _hasPets;
  late String _relationshipStatus; // 'single', 'partner'
  late bool _isPregnantOrPlanning;
  late bool _hasChildren;
  late String _childAgeStage; // 'none', 'infant', 'school'
  late bool _hasAgingParents;
  late bool _hasDisabilityCare;
  late bool _hasAbroadTravelOrStudy;
  late bool _hasDebtPressure;
  late bool _isSmoker;
  late bool _hasDeskJob;
  late bool _hasHypertension;
  late bool _hasDiabetes;
  late bool _hasKidneyStones;
  late bool _hasGout;
  late bool _hasCrisisOrMentalStress;
  late double _heightCm;
  late double _weightKg;
  late bool _hasWeightLossGoal;
  late bool _hasGastroAcidOrStomach;
  late bool _hasFrequentPainOrAnalgesic;
  late Set<String> _selectedDomains;
  late bool _prunedOnly;

  // 动效控制器
  late AnimationController _compassSpinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _pageAnimController;
  late Animation<double> _pageFadeAnim;
  late Animation<Offset> _pageSlideAnim;

  @override
  void initState() {
    super.initState();
    // 默认基础画像
    _gender = '男';
    _age = 28;
    _careerType = 'employed';
    _isProgrammer = false;
    _isEntrepreneur = false;
    _hasDigitalAssetsConcern = false;
    _hasCar = false;
    _hasTwowheeler = true;
    _livingStatus = 'tenant';
    _hasPipedGas = true;
    _hasPets = false;
    _relationshipStatus = 'single';
    _isPregnantOrPlanning = false;
    _hasChildren = false;
    _childAgeStage = 'none';
    _hasAgingParents = false;
    _hasDisabilityCare = false;
    _hasAbroadTravelOrStudy = false;
    _hasDebtPressure = false;
    _isSmoker = false;
    _hasDeskJob = true;
    _hasHypertension = false;
    _hasDiabetes = false;
    _hasKidneyStones = false;
    _hasGout = false;
    _hasCrisisOrMentalStress = false;
    _heightCm = 170.0;
    _weightKg = 65.0;
    _hasWeightLossGoal = false;
    _hasGastroAcidOrStomach = false;
    _hasFrequentPainOrAnalgesic = false;
    _selectedDomains = {
      'health',
      'career',
      'family',
      'finance',
      'safety',
      'resilience',
    };
    _prunedOnly = true;

    // 动画
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
      duration: const Duration(milliseconds: 320),
    );
    _pageFadeAnim = CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    );
    _pageSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _pageAnimController,
            curve: Curves.easeOutCubic,
          ),
        );

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
      _livingStatus = cur.hasMortgage
          ? 'owner_loan'
          : (cur.isTenant ? 'tenant' : 'owner_free');
      _hasPipedGas = cur.hasPipedGas;
      _hasPets = cur.hasPets;
      _relationshipStatus = cur.roles.contains('伴侣') ? 'partner' : 'single';
      _hasChildren = cur.hasChildren || cur.roles.contains('家长');
      _childAgeStage = cur.childAgeStage;
      _hasAgingParents =
          cur.hasAgingParents || cur.livingConditions.contains('家有老人');
      _isProgrammer = cur.isProgrammer || cur.roles.contains('程序员');
      _isEntrepreneur = cur.isEntrepreneur || cur.roles.contains('创业者');
      _hasDigitalAssetsConcern =
          cur.hasDigitalAssetsConcern || cur.roles.contains('平台运营');
      _isPregnantOrPlanning =
          cur.isPregnantOrPlanning ||
          cur.roles.contains('孕产') ||
          cur.roles.contains('准父母');
      _hasAbroadTravelOrStudy =
          cur.hasAbroadTravelOrStudy ||
          cur.roles.contains('出境者') ||
          cur.roles.contains('留学生');
      _hasDebtPressure =
          cur.hasDebtPressure || cur.livingConditions.contains('负债人群');
      _hasDisabilityCare = cur.hasDisabilityCare || cur.roles.contains('残障人士');
      _hasCrisisOrMentalStress =
          cur.hasCrisisOrMentalStress || cur.healthConcerns.contains('心理减压');

      if (_isProgrammer) {
        _careerType = 'programmer';
      } else if (_isEntrepreneur) {
        _careerType = 'entrepreneur';
      } else if (cur.roles.contains('学生')) {
        _careerType = 'student';
      } else if (cur.roles.contains('灵活就业者')) {
        _careerType = 'freelance';
      } else {
        _careerType = 'employed';
      }

      _isSmoker = cur.isSmoker;
      _hasHypertension =
          cur.hasHypertension || cur.healthConcerns.contains('血压关注');
      _hasDiabetes = cur.hasDiabetes || cur.healthConcerns.contains('血糖关注');
      _hasKidneyStones =
          cur.hasKidneyStones || cur.healthConcerns.contains('肾结石');
      _hasGout = cur.hasGout || cur.healthConcerns.contains('痛风');
      _hasDeskJob = cur.healthConcerns.contains('久坐伏案');
      _heightCm = cur.heightCm ?? 170.0;
      _weightKg = cur.weightKg ?? 65.0;
      _hasWeightLossGoal =
          cur.hasWeightLossGoal || cur.healthConcerns.contains('减重管理');
      _hasGastroAcidOrStomach =
          cur.hasGastroAcidOrStomach || cur.healthConcerns.contains('反酸胃炎');
      _hasFrequentPainOrAnalgesic =
          cur.hasFrequentPainOrAnalgesic || cur.healthConcerns.contains('止痛用药');
      _prunedOnly = cur.prunedOnly;
      if (cur.focusDomains.isNotEmpty) {
        _selectedDomains = Set<String>.from(cur.focusDomains);
      }
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

  /// 构建当前全息画像
  UserProfile _buildCurrentProfile() {
    final roles = <String>['全民'];
    if (_careerType == 'employed') roles.add('上班族');
    if (_careerType == 'programmer' || _isProgrammer)
      roles.addAll(['上班族', '程序员']);
    if (_careerType == 'entrepreneur' || _isEntrepreneur)
      roles.addAll(['创业者', '合伙人']);
    if (_careerType == 'student') roles.add('学生');
    if (_careerType == 'freelance') roles.add('灵活就业者');

    if (_hasCar) roles.add('司机');
    if (_hasChildren || _childAgeStage != 'none') roles.add('家长');
    if (_relationshipStatus == 'partner') roles.add('伴侣');
    if (_isPregnantOrPlanning) roles.addAll(['准父母', '孕产']);
    if (_hasAbroadTravelOrStudy) roles.addAll(['出境者', '留学生']);
    if (_hasDigitalAssetsConcern) roles.add('平台运营');
    if (_hasDisabilityCare) roles.add('残障人士');

    final living = <String>[];
    if (_livingStatus == 'tenant') living.add('租房人');
    if (_livingStatus == 'owner_loan') living.add('购房人');
    if (_hasAgingParents) living.add('家有老人');
    if (_hasPets) living.add('养犬人');
    if (_hasDebtPressure) living.add('负债人群');

    final health = <String>[];
    if (_hasDeskJob) health.add('久坐伏案');
    if (_isSmoker) health.add('吸烟者');
    if (_hasHypertension) health.add('血压关注');
    if (_hasDiabetes) health.add('血糖关注');
    if (_hasKidneyStones) health.add('肾结石');
    if (_hasGout) health.add('痛风');
    if (_hasCrisisOrMentalStress) health.add('心理减压');
    if (_hasGastroAcidOrStomach) health.add('反酸胃炎');
    if (_hasFrequentPainOrAnalgesic) health.add('止痛用药');
    if (_hasWeightLossGoal) health.add('减重管理');

    return UserProfile(
      gender: _gender,
      age: _age,
      roles: roles,
      livingConditions: living,
      healthConcerns: health,
      focusDomains: _selectedDomains.toList(),
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
      isEntrepreneur: _careerType == 'entrepreneur' || _isEntrepreneur,
      hasHypertension: _hasHypertension,
      hasDiabetes: _hasDiabetes,
      hasKidneyStones: _hasKidneyStones,
      hasGout: _hasGout,
      isProgrammer: _careerType == 'programmer' || _isProgrammer,
      isPregnantOrPlanning: _isPregnantOrPlanning,
      hasAbroadTravelOrStudy: _hasAbroadTravelOrStudy,
      hasDebtPressure: _hasDebtPressure,
      hasDigitalAssetsConcern: _hasDigitalAssetsConcern,
      hasDisabilityCare: _hasDisabilityCare,
      hasCrisisOrMentalStress: _hasCrisisOrMentalStress,
      heightCm: _heightCm,
      weightKg: _weightKg,
      hasWeightLossGoal: _hasWeightLossGoal,
      hasGastroAcidOrStomach: _hasGastroAcidOrStomach,
      hasFrequentPainOrAnalgesic: _hasFrequentPainOrAnalgesic,
      childAgeStage: _hasChildren ? _childAgeStage : 'none',
      relationshipStatus: _relationshipStatus,
    ).normalized();
  }

  /// 模拟实时剪枝评估
  bool _evalAdviceMatch(Advice a, UserProfile p) {
    if (p.focusDomains.isNotEmpty && p.focusDomains.length < 6) {
      final domain = LifeDomain.ofChapter(a.chapter);
      if (!p.focusDomains.contains(domain.id)) return false;
    }
    final pr = a.prerequisites;
    if (pr.isNotEmpty) {
      if (pr['has_car'] == true && !p.hasCar) return false;
      if (pr['has_twowheeler'] == true && !p.hasTwowheeler) return false;
      if (pr['is_smoker'] == true && !p.isSmoker) return false;
      if (pr['has_children'] == true &&
          !p.hasChildren &&
          !p.roles.contains('家长') &&
          !p.roles.contains('准父母'))
        return false;
      if (pr['is_pregnant_or_parent'] == true &&
          !p.hasChildren &&
          !p.roles.contains('孕产') &&
          !p.roles.contains('准父母') &&
          !p.roles.contains('家长'))
        return false;
      if (pr['has_aging_parents'] == true &&
          !p.hasAgingParents &&
          !p.livingConditions.contains('家有老人') &&
          !p.roles.contains('照护者'))
        return false;
      if (pr['is_tenant'] == true &&
          !p.isTenant &&
          !p.livingConditions.contains('租房人'))
        return false;
      if (pr['has_mortgage'] == true &&
          !p.hasMortgage &&
          !p.livingConditions.contains('购房人'))
        return false;
      if (pr['has_pets'] == true &&
          !p.hasPets &&
          !p.livingConditions.contains('养犬人'))
        return false;
      if (pr['has_piped_gas'] == true && !p.hasPipedGas) return false;
      if (pr['is_entrepreneur'] == true &&
          !p.isEntrepreneur &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('合伙人'))
        return false;
      if (pr['gender_female'] == true && p.gender != '女') return false;
      if (pr['gender_male'] == true && p.gender != '男') return false;
      if (pr['min_age'] is int && p.age < (pr['min_age'] as int)) return false;
    }

    final text = '${a.title} ${a.tags.join(" ")} ${a.chapter}';
    final hasChronic =
        a.tags.contains('确诊慢病') ||
        a.tags.contains('慢性病') ||
        a.chapter == '得了慢性病之后怎么活' ||
        a.chapter == '残疾之后怎么活';

    if (hasChronic ||
        text.contains('肾结石') ||
        text.contains('痛风') ||
        text.contains('高尿酸')) {
      if (text.contains('肾结石')) {
        if (!p.hasKidneyStones && !p.healthConcerns.contains('肾结石'))
          return false;
      }
      if (text.contains('痛风') || text.contains('高尿酸')) {
        if (!p.hasGout && !p.healthConcerns.contains('痛风')) return false;
      }
      if (text.contains('高血压') || (text.contains('血压') && hasChronic)) {
        if (!p.hasHypertension && !p.healthConcerns.contains('血压关注'))
          return false;
      }
      if (text.contains('糖尿病') || text.contains('血糖') || text.contains('胰岛素')) {
        if (!p.hasDiabetes && !p.healthConcerns.contains('血糖关注')) return false;
      }
      if (a.chapter == '残疾之后怎么活' ||
          a.tags.contains('残疾') ||
          a.tags.contains('残障人士')) {
        if (!p.roles.contains('残障人士') && !p.healthConcerns.contains('残疾照护'))
          return false;
      }
      if (a.chapter == '得了慢性病之后怎么活' &&
          !p.hasHypertension &&
          !p.hasDiabetes &&
          !p.hasKidneyStones &&
          !p.hasGout &&
          !p.healthConcerns.contains('确诊慢病')) {
        return false;
      }
    }

    // 减重药物与手环运动量化 (ID 663, 665, 199)
    if (a.id == 663 ||
        a.id == 665 ||
        a.id == 199 ||
        text.contains('司美格鲁肽') ||
        text.contains('减肥针') ||
        text.contains('减肥药') ||
        text.contains('手环/手表的运动量化')) {
      if (!p.hasWeightLossGoal && !p.isOverweightOrObese) return false;
    }

    // 肠胃反酸与奥美拉唑 (ID 760)
    if (a.id == 760 ||
        text.contains('奥美拉唑') ||
        (text.contains('反酸') && text.contains('胃'))) {
      if (!p.hasGastroAcidOrStomach) return false;
    }

    // 止痛药限制 (ID 763)
    if (a.id == 763 ||
        (text.contains('止疼药') && text.contains('15天')) ||
        (text.contains('止痛药') && text.contains('15天'))) {
      if (!p.hasFrequentPainOrAnalgesic) return false;
    }

    // 独居与安全兜底 (ID 675)
    if (a.id == 675 ||
        text.contains('盯着你的那个人') ||
        text.contains('散养东西') ||
        text.contains('三道安全兜底网')) {
      if (p.relationshipStatus != 'single' &&
          !p.livingConditions.contains('独居'))
        return false;
    }

    // 抑郁危机与自杀干预 (ID 25, 264, 568)
    if (a.id == 568 ||
        a.id == 25 ||
        a.id == 264 ||
        text.contains('有自杀念头时打 12356') ||
        text.contains('带着孩子一起走')) {
      return false;
    }

    // 孕产专科急重症与子痫用药强门禁 (ID 644, 646, 647)
    if (a.id == 644 ||
        a.id == 646 ||
        a.id == 647 ||
        text.contains('破水了就地平躺') ||
        text.contains('子痫前期')) {
      if (p.gender != '女' ||
          (!p.isPregnantOrPlanning &&
              !p.roles.contains('孕产') &&
              !p.roles.contains('准父母'))) {
        return false;
      }
    }

    // 婴幼儿与学龄儿童突发及欺凌门禁 (ID 545, 686, 704)
    if (a.id == 545 ||
        a.id == 686 ||
        a.id == 704 ||
        text.contains('新生儿黄疸') ||
        text.contains('孩子被欺凌') ||
        text.contains('撞了头、之后头痛')) {
      if (!p.hasChildren &&
          !p.roles.contains('家长') &&
          !p.roles.contains('准父母')) {
        return false;
      }
    }

    // 专病与特殊高危用药强门禁 (ID 44 房颤, ID 121 失眠安眠药, ID 757 60岁布洛芬)
    if (a.id == 44 || text.contains('查出房颤请医生评估吃抗凝药')) {
      if (!p.hasHypertension && !p.healthConcerns.contains('血压关注'))
        return false;
    }
    if (a.id == 121 || text.contains('别一上来就长期吃安眠药')) {
      if (!p.healthConcerns.contains('心理减压') && !p.hasCrisisOrMentalStress)
        return false;
    }
    if (a.id == 757 || text.contains('60 岁以上、胃出过血、在吃抗凝药')) {
      if (p.age < 60 && !p.hasGastroAcidOrStomach) return false;
    }

    final chap = a.chapter;
    if (chap == '程序员和技术人容易踩的红线') {
      if (!p.isProgrammer && !p.roles.contains('程序员')) return false;
    }
    if (chap == '做一个网站或平台：资质、备案和服务器') {
      if (!p.isProgrammer &&
          !p.isEntrepreneur &&
          !p.hasDigitalAssetsConcern &&
          !p.roles.contains('程序员') &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('平台运营')) {
        return false;
      }
    }
    if (chap == '创业与做生意：别把家底赔进去') {
      if (!p.isEntrepreneur &&
          !p.roles.contains('创业者') &&
          !p.roles.contains('合伙人'))
        return false;
    }
    if (chap == '出国、旅行与境外安全' || chap == '出国留学：身份、打工、保险和回国认证') {
      if (!p.hasAbroadTravelOrStudy &&
          !p.roles.contains('出境者') &&
          !p.roles.contains('留学生'))
        return false;
    }
    if (chap == '怀孕和生产：从发现怀孕到出院办证') {
      if (p.gender == '男' &&
          !p.isPregnantOrPlanning &&
          !p.roles.contains('准父母') &&
          !p.roles.contains('孕产') &&
          !p.roles.contains('家长')) {
        return false;
      }
    }
    if (chap == '刚出生的孩子怎么带') {
      if (p.childAgeStage != 'infant' &&
          !p.hasChildren &&
          !p.roles.contains('家长'))
        return false;
    }
    if (chap == '上学以后的孩子') {
      if (p.childAgeStage != 'school' &&
          !p.hasChildren &&
          !p.roles.contains('家长'))
        return false;
    }

    if (a.tags.any(p.exclude.contains)) return false;
    if (p.gender != '女' && a.tags.contains('女性健康')) return false;

    final stageTags = const ['少年', '青年', '中年', '老年'];
    final adviceStages = a.tags.where(stageTags.contains).toList();
    if (adviceStages.isNotEmpty && !adviceStages.any(p.stages.contains))
      return false;

    return true;
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _totalSteps - 1) {
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
      backgroundColor: p.canvas,
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
                  if (idx == _totalSteps - 1) {
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
                  _buildStep2CareerAndTech(p),
                  _buildStep3Mobility(p),
                  _buildStep4Housing(p),
                  _buildStep5FamilyAndChildren(p),
                  _buildStep6AgingAndCare(p),
                  _buildStep7FinanceAndDebt(p),
                  _buildStep8HealthAndChronic(p),
                  _buildStep9MindAndPillars(p),
                  _buildStep10Synthesis(p),
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
    final activeCount = catalog.adviceList
        .where((a) => _evalAdviceMatch(a, tempProfile))
        .length;
    final prunedCount = catalog.adviceList.length - activeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
              if (_currentPage > 0 && _currentPage < _totalSteps - 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.action.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: p.action.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_outlined,
                        size: 12,
                        color: p.action,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '专属激活 $activeCount · 剪枝过滤 $prunedCount',
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
              // 顶部始终提供快速跳过入口
              TextButton(
                onPressed: _complete,
                child: Text(
                  widget.isReconfiguring ? '保存退出' : '跳过配置',
                  style: TextStyle(
                    color: p.inkSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 步进指示条
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _totalSteps,
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
    return _buildPageWrapper(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.action.withValues(alpha: 0.1),
              border: Border.all(
                color: p.action.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(Icons.shield_outlined, size: 40, color: p.action),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '每个人都需要一套生活防线',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: p.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'KairosStep 汇聚了 737 条涵盖生存防线、人身安全、医疗急救、合规法律、亲情教育与危机韧性的实操智慧。\n\n我们不推崇无意义的信息轰炸——通过构建您的专属全息画像，应用将智能剪枝与您无关的冗余规则（如未患肾结石绝不推肾结石喝水提示），将日常待办化繁为简。',
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 14, height: 1.6, color: p.inkSub),
        ),
        const SizedBox(height: 20),
        _buildInfoBox(
          p,
          icon: Icons.tune,
          title: '随心掌握：深度定制或秒速开启',
          desc: '您可以跟随向导逐步确认 9 大生活维度的防线开关；您也可以在任何时候点击“跳过配置”或“以此配置直接开启”，在日常使用中随时去“我的”页面微调。',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================================================
  // Step 1: 年龄与性别基础
  // ==========================================================================
  Widget _buildStep1AgeGender(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '生理特征与人生阶段',
          desc: '精确对应女性健康、孕产期排查、法定退休及青年/中年/老年多发防线规则，自动过滤不符年龄与性别的内容。',
        ),
        const SizedBox(height: 20),
        Text('您的生理性别', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSelectCard(
                p,
                title: '男性',
                subtitle: '自动剪枝孕产及专属妇科防线',
                icon: Icons.male,
                selected: _gender == '男',
                onTap: () => setState(() => _gender = '男'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectCard(
                p,
                title: '女性',
                subtitle: '激活宫颈筛查、乳腺与经期防线',
                icon: Icons.female,
                selected: _gender == '女',
                onTap: () => setState(() => _gender = '女'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('当前年龄', style: _groupLabelStyle(p)),
            Text(
              '$_age 岁 (${_getStageLabel(_age)})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: p.action,
              ),
            ),
          ],
        ),
        Slider(
          value: _age.toDouble(),
          min: 14,
          max: 85,
          divisions: 71,
          activeColor: p.action,
          label: '$_age 岁',
          onChanged: (val) => setState(() => _age = val.round()),
        ),
        _buildPruneHint(
          p,
          _age < 35
              ? '当前年龄：激活职场劳动合同排雷、租房甲醛自测；剪枝白内障/养老金规划'
              : '当前年龄：激活心脑血管体检、结直肠癌筛查、养老账户筹划',
        ),
      ],
    );
  }

  String _getStageLabel(int age) {
    if (age <= 22) return '青年 · 求学探索';
    if (age <= 35) return '青年 · 事业攀登';
    if (age <= 55) return '中年 · 稳健砥柱';
    return '银发 · 康养无忧';
  }

  // ==========================================================================
  // Step 2: 职业、技术与资产运营
  // ==========================================================================
  Widget _buildStep2CareerAndTech(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '职业形态、技术研发与商业资产',
          desc: '《程序员与技术人容易踩的红线》(41条)、《创业做生意》(41条) 与《网站备案及服务器资质》条目极其专业，非相关人群将被完全剪枝以防信息过载。',
        ),
        const SizedBox(height: 16),
        Text('主要职业形态', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip(p, '上班族/受雇职员', _careerType == 'employed', () {
              setState(() => _careerType = 'employed');
            }),
            _buildChoiceChip(p, '程序员/技术研发', _careerType == 'programmer', () {
              setState(() {
                _careerType = 'programmer';
                _isProgrammer = true;
              });
            }),
            _buildChoiceChip(p, '创业者/小微个体', _careerType == 'entrepreneur', () {
              setState(() {
                _careerType = 'entrepreneur';
                _isEntrepreneur = true;
              });
            }),
            _buildChoiceChip(p, '在校学生', _careerType == 'student', () {
              setState(() => _careerType = 'student');
            }),
            _buildChoiceChip(p, '自由职业/灵活就业', _careerType == 'freelance', () {
              setState(() => _careerType = 'freelance');
            }),
          ],
        ),
        const SizedBox(height: 18),
        Text('专业技术与资产防线开关', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        _buildSwitchTile(
          p,
          title: '从事编程开发/爬虫/系统运维',
          subtitle: '激活代码开源合规、爬虫红线、跳槽竞业与离职数据移交规范 (41条)',
          value: _isProgrammer || _careerType == 'programmer',
          onChanged: (v) => setState(() => _isProgrammer = v),
        ),
        _buildSwitchTile(
          p,
          title: '独立建站、平台运营或小程序开发',
          subtitle: '激活 ICP/EDI 资质合规、公安备案、域名持有人防抢注与服务器安全 (21条)',
          value: _hasDigitalAssetsConcern,
          onChanged: (v) => setState(() => _hasDigitalAssetsConcern = v),
        ),
        _buildSwitchTile(
          p,
          title: '有开店、合伙经商或企业经营需求',
          subtitle: '激活有限责任隔离、公私账户分流、防挂名法定代表人与连带担保 (41条)',
          value: _isEntrepreneur || _careerType == 'entrepreneur',
          onChanged: (v) => setState(() => _isEntrepreneur = v),
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 3: 出行方式与交通安全
  // ==========================================================================
  Widget _buildStep3Mobility(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '出行方式与通勤防线',
          desc: '机动车与电动两轮车具有完全不同的法律责任与物理风险，未勾选的出行方式将自动隐匿，免除日常提示干扰。',
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          p,
          icon: Icons.directions_car_outlined,
          title: '常开汽车 / 私家车出行',
          subtitle: '激活盲区防范、高速爆胎处置、三者险额度底线、酒驾次日宿醉防范 (28条)',
          value: _hasCar,
          onChanged: (v) => setState(() => _hasCar = v),
        ),
        _buildSwitchTile(
          p,
          icon: Icons.electric_moped_outlined,
          title: '骑行电动两轮车 / 摩托车',
          subtitle: '激活 3C 头盔佩戴、进楼入户充电火灾禁令、雨天铁板刹车防侧滑 (15条)',
          value: _hasTwowheeler,
          onChanged: (v) => setState(() => _hasTwowheeler = v),
        ),
        _buildSwitchTile(
          p,
          icon: Icons.flight_takeoff_outlined,
          title: '近半年有出国、境外出差、海岛旅游或留学计划',
          subtitle: '激活使领馆领事保护热线、境外救援险、登机处方药申报与签证防拒签 (25条)',
          value: _hasAbroadTravelOrStudy,
          onChanged: (v) => setState(() => _hasAbroadTravelOrStudy = v),
        ),
        _buildPruneHint(
          p,
          !_hasCar && !_hasAbroadTravelOrStudy
              ? '已剪枝：自驾高速紧急停车带规则、境外租车与领事保护等约 53 条无关建议'
              : '专属防线已激活对应交通与出境安保指引',
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 4: 居住环境与不动产防护
  // ==========================================================================
  Widget _buildStep4Housing(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '居住状态与居所安全',
          desc: '租房、背负房贷或全款购房者面临截然不同的财务与物权风险。管道燃气与宠物家庭亦需特殊应急预案。',
        ),
        const SizedBox(height: 16),
        Text('居住不动产状态', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        _buildRadioOption<String>(
          p,
          title: '租房居住 (租客)',
          desc: '激活押金收据留存、甲醛自测通风、二房东转租权查验与防突击驱逐 (22条)',
          value: 'tenant',
          groupValue: _livingStatus,
          onChanged: (v) => setState(() => _livingStatus = v),
        ),
        _buildRadioOption<String>(
          p,
          title: '已购房并正在偿还房贷',
          desc: '激活提前还款违约金计算、断供法律后果评估与房屋财产险配置',
          value: 'owner_loan',
          groupValue: _livingStatus,
          onChanged: (v) => setState(() => _livingStatus = v),
        ),
        _buildRadioOption<String>(
          p,
          title: '自有住房且无房贷',
          desc: '专注于家庭消防逃生路线、水暖阀门年检与高空抛物物权防范',
          value: 'owner_free',
          groupValue: _livingStatus,
          onChanged: (v) => setState(() => _livingStatus = v),
        ),
        const SizedBox(height: 12),
        Text('居家特质防护', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        _buildSwitchTile(
          p,
          title: '使用管道天然气 / 燃气热水器',
          subtitle: '激活燃气报警器联动、金属波纹软管更换周期与一氧化碳防中毒 (12条)',
          value: _hasPipedGas,
          onChanged: (v) => setState(() => _hasPipedGas = v),
        ),
        _buildSwitchTile(
          p,
          title: '家有宠物 (犬猫)',
          subtitle: '激活狂犬疫苗年检、牵引绳法律责任防伤人纠纷与高空纱窗防护 (10条)',
          value: _hasPets,
          onChanged: (v) => setState(() => _hasPets = v),
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 5: 亲密关系与育儿周期
  // ==========================================================================
  Widget _buildStep5FamilyAndChildren(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '亲密关系、孕产与育儿阶段',
          desc: '《怀孕和生产》(28条)、《刚出生的孩子怎么带》(18条) 与《上学以后的孩子》(22条) 是重型章节。未育或单身用户若不剪枝，将被大量无用建议淹没。',
        ),
        const SizedBox(height: 16),
        Text('婚恋与亲密关系', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSelectCard(
                p,
                title: '单身独居',
                subtitle: '单人应急联系人、防反锁安全',
                icon: Icons.person_outline,
                selected: _relationshipStatus == 'single',
                onTap: () => setState(() => _relationshipStatus = 'single'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectCard(
                p,
                title: '有伴侣/已婚',
                subtitle: '婚前财产公证、家庭财务透明',
                icon: Icons.favorite_border,
                selected: _relationshipStatus == 'partner',
                onTap: () => setState(() => _relationshipStatus = 'partner'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          p,
          title: '正在备孕、孕期或刚迎来新生命',
          subtitle: '激活孕期建档、NT/四维大排畸排期、叶酸补充、生育津贴申领 (28条)',
          value: _isPregnantOrPlanning,
          onChanged: (v) => setState(() => _isPregnantOrPlanning = v),
        ),
        _buildSwitchTile(
          p,
          title: '家有子女抚育中',
          subtitle: '开启儿童意外烫伤坠床急救、预防接种本管理及青少年心理关照',
          value: _hasChildren,
          onChanged: (v) => setState(() {
            _hasChildren = v;
            if (!v) {
              _childAgeStage = 'none';
            } else if (_childAgeStage == 'none') {
              _childAgeStage = 'school';
            }
          }),
        ),
        if (_hasChildren) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  p,
                  '婴幼儿期 (0~3岁)',
                  _childAgeStage == 'infant',
                  () {
                    setState(() => _childAgeStage = 'infant');
                  },
                ),
                _buildChoiceChip(
                  p,
                  '学龄期 (幼小初高)',
                  _childAgeStage == 'school',
                  () {
                    setState(() => _childAgeStage = 'school');
                  },
                ),
              ],
            ),
          ),
        ],
        _buildPruneHint(
          p,
          !_isPregnantOrPlanning && !_hasChildren
              ? '已为您一键过滤孕产建卡、婴儿趴睡窒息防范等 68 条专属育儿建议'
              : '已精准匹配对应母婴安全与成长防护规范',
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 6: 养老照护与特殊守护
  // ==========================================================================
  Widget _buildStep6AgingAndCare(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '父母养老照护与特殊陪护',
          desc: '《给父母养老》(25条) 与《残疾之后怎么活》(21条) 关乎特殊弱势群体的尊严与生存底线。未涉及者将自动剪枝降噪。',
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          p,
          icon: Icons.elderly_outlined,
          title: '家中需照料高龄父母或老人',
          subtitle: '激活父母浴室防跌倒扶手、养老金资格认证、慢病异地就医备案与阿尔茨海默防走失 (25条)',
          value: _hasAgingParents,
          onChanged: (v) => setState(() => _hasAgingParents = v),
        ),
        _buildSwitchTile(
          p,
          icon: Icons.accessible_outlined,
          title: '本人或家人存在残障需要无障碍照护',
          subtitle: '激活残疾人证评定办理、辅助器具无偿适配、无障碍通道维权与双项生活补贴 (21条)',
          value: _hasDisabilityCare,
          onChanged: (v) => setState(() => _hasDisabilityCare = v),
        ),
        _buildPruneHint(
          p,
          !_hasAgingParents && !_hasDisabilityCare
              ? '已剪枝养老护理津贴申领、假肢维护等 46 条专业陪护建议'
              : '专属适老化防跌倒与残障帮扶通道已激活',
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 7: 财务抗风险与债务应急
  // ==========================================================================
  Widget _buildStep7FinanceAndDebt(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '财务安全、债务抗压与应急备用金',
          desc: '《如何活得极其省钱》(32条) 与《陷入债务危机怎么活》(42条) 提供破产边缘生存法宝。未背负债务者可精简为稳健理财。',
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          p,
          icon: Icons.money_off_outlined,
          title: '正面临债务偿还压力或需要极度节约支出',
          subtitle: '激活停息挂账协商、合法催收边界自卫、恩格尔系数极限制控、防套现连环贷陷阱 (74条)',
          value: _hasDebtPressure,
          onChanged: (v) => setState(() => _hasDebtPressure = v),
        ),
        const SizedBox(height: 16),
        _buildInfoBox(
          p,
          icon: Icons.savings_outlined,
          title: '底线防御思维',
          desc: 'KairosStep 始终坚持“先守好 6 个月家庭应急备用金，再谈高风险投资”。无论您是否处于债务困境，基础社保断缴自费救助建议始终为您保底。',
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 8: 慢性病病史与生活习惯
  // ==========================================================================
  Widget _buildStep8HealthAndChronic(AppPalettes p) {
    final heightM = _heightCm / 100.0;
    final bmi = (heightM > 0) ? (_weightKg / (heightM * heightM)) : 22.0;
    final bmiStr = bmi.toStringAsFixed(1);
    final bmiCategory = bmi < 18.5
        ? '偏瘦'
        : (bmi < 24.0 ? '正常' : (bmi < 28.0 ? '超重' : '肥胖'));
    final bmiColor = (bmi >= 18.5 && bmi < 24.0) ? p.emerald : p.amber;

    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '健康防线、慢病确诊与生活习性',
          desc: '【强门禁机制】未确诊或未关注肾结石、痛风、胃酸用药、止痛药依赖或减重的用户，严禁推送对应用药与干预建议，坚决捍卫清爽视野。',
        ),
        const SizedBox(height: 16),
        Text('身体体征与体重管理', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '身高: ${_heightCm.round()} cm',
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '体重: ${_weightKg.toStringAsFixed(1)} kg',
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: bmiColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BMI $bmiStr · $bmiCategory',
                      style: TextStyle(
                        color: bmiColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('身高', style: TextStyle(color: p.inkSub, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _heightCm.clamp(120.0, 220.0),
                      min: 120.0,
                      max: 220.0,
                      divisions: 100,
                      activeColor: p.action,
                      onChanged: (v) => setState(() => _heightCm = v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('体重', style: TextStyle(color: p.inkSub, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _weightKg.clamp(35.0, 150.0),
                      min: 35.0,
                      max: 150.0,
                      divisions: 115,
                      activeColor: p.emerald,
                      onChanged: (v) => setState(() => _weightKg = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchTile(
          p,
          icon: Icons.fitness_center_outlined,
          title: '关注减重塑形 / 减重管理目标',
          subtitle: '若未开启或 BMI 正常，绝不推送司美格鲁肽、减肥药以及手环运动量化等减重提醒',
          value: _hasWeightLossGoal,
          onChanged: (v) => setState(() => _hasWeightLossGoal = v),
        ),
        const SizedBox(height: 14),
        Text('慢病确诊与病史排查 (一票否决门禁)', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        _buildCheckboxTile(
          p,
          title: '曾患肾结石 / 泌尿系结石病史',
          desc: '激活每日 2500ml 强力饮水提醒、草酸盐摄入控制、跳跃促排防复发 (7条)',
          value: _hasKidneyStones,
          onChanged: (v) => setState(() => _hasKidneyStones = v ?? false),
        ),
        _buildCheckboxTile(
          p,
          title: '痛风发作史 / 长期高尿酸血症',
          desc: '激活啤酒浓汤急剧限制、秋水仙碱备用、碳酸氢钠碱化尿液排查 (6条)',
          value: _hasGout,
          onChanged: (v) => setState(() => _hasGout = v ?? false),
        ),
        _buildCheckboxTile(
          p,
          title: '高血压关注 / 正在服用降压药',
          desc: '激活晨起第一杯水测压、低钠低盐饮食、阶梯式停药大忌警示 (8条)',
          value: _hasHypertension,
          onChanged: (v) => setState(() => _hasHypertension = v ?? false),
        ),
        _buildCheckboxTile(
          p,
          title: '高血糖 / 糖尿病监测',
          desc: '激活空腹与餐后血糖记录、低血糖随身硬糖急救、糖尿病足温水检查 (6条)',
          value: _hasDiabetes,
          onChanged: (v) => setState(() => _hasDiabetes = v ?? false),
        ),
        _buildCheckboxTile(
          p,
          title: '反酸烧心 / 慢性胃炎 / 胃食管反流',
          desc: '未勾选绝不推荐奥美拉唑等强效抑酸药；提醒饭后勿躺及抑酸疗程严控 (ID 760)',
          value: _hasGastroAcidOrStomach,
          onChanged: (v) =>
              setState(() => _hasGastroAcidOrStomach = v ?? false),
        ),
        _buildCheckboxTile(
          p,
          title: '常备止痛药 / 偏头痛或关节慢性疼痛',
          desc: '未勾选绝不打扰；开启后提醒一个月吃止痛药严禁超过15天防药物过度性头痛 (ID 763)',
          value: _hasFrequentPainOrAnalgesic,
          onChanged: (v) =>
              setState(() => _hasFrequentPainOrAnalgesic = v ?? false),
        ),
        const SizedBox(height: 14),
        Text('日常身体习性', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        _buildSwitchTile(
          p,
          title: '久坐伏案工作 (每天超 6 小时)',
          subtitle: '激活 45 分钟起立走动拉伸、骨盆中立坐姿防腰突与干眼症 20-20-20 法则',
          value: _hasDeskJob,
          onChanged: (v) => setState(() => _hasDeskJob = v),
        ),
        _buildSwitchTile(
          p,
          title: '吸烟人群 (戒烟守护)',
          subtitle: '激活阶梯式尼古丁替代、戒断反应心理对抗、每年低剂量螺旋 CT 肺癌筛查',
          value: _isSmoker,
          onChanged: (v) => setState(() => _isSmoker = v),
        ),
        _buildPruneHint(
          p,
          !_hasKidneyStones &&
                  !_hasGout &&
                  !_hasHypertension &&
                  !_hasDiabetes &&
                  !_hasGastroAcidOrStomach &&
                  !_hasFrequentPainOrAnalgesic &&
                  !_hasWeightLossGoal
              ? '已拦截全部慢病、特殊抑酸药与减重干预条目，确保日常清单绝对纯净！'
              : '已按您勾选的体征与病史开放对应的精准康复及安全用药日程',
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 9: 心理韧性与重大变故防线
  // ==========================================================================
  Widget _buildStep9MindAndPillars(AppPalettes p) {
    return _buildPageWrapper(
      children: [
        _buildHeader(
          title: '心理减压与六大支柱覆盖',
          desc: '当经历失业、家庭变故或极端高压时，《极端变故之后怎么活》与《心理减压》将成为您的避难所。您还可微调优先关注的人生支柱。',
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          p,
          icon: Icons.self_improvement_outlined,
          title: '近期面临高压心理危机或经历重大变故',
          subtitle: '激活心理热线 12356 紧急干预、悲伤五阶段认知接纳与反刍思维阻断 (26条)',
          value: _hasCrisisOrMentalStress,
          onChanged: (v) => setState(() => _hasCrisisOrMentalStress = v),
        ),
        const SizedBox(height: 18),
        Text('六大生活支柱覆盖 (点击自选关注)', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LifeDomain.values.map((domain) {
            final isSel = _selectedDomains.contains(domain.id);
            return FilterChip(
              avatar: Icon(
                domain.icon,
                size: 16,
                color: isSel ? Colors.white : domain.accentColor,
              ),
              label: Text(domain.shortTitle),
              selected: isSel,
              selectedColor: domain.accentColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : p.ink,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedDomains.add(domain.id);
                  } else if (_selectedDomains.length > 1) {
                    _selectedDomains.remove(domain.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================================================
  // Step 10: 全息画像生成与防线总览
  // ==========================================================================
  Widget _buildStep10Synthesis(AppPalettes p) {
    final tempProfile = _buildCurrentProfile();
    final catalog = catalogOf(context);
    final activeAdvice = catalog.adviceList
        .where((a) => _evalAdviceMatch(a, tempProfile))
        .toList();
    final prunedCount = catalog.adviceList.length - activeAdvice.length;

    return _buildPageWrapper(
      children: [
        const SizedBox(height: 12),
        Center(
          child: ScaleTransition(
            scale: _pulseAnim,
            child: RotationTransition(
              turns: _compassSpinController,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [p.action, Colors.cyan, Colors.indigo, p.action],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                    ),
                    child: Icon(
                      Icons.verified_outlined,
                      size: 36,
                      color: p.action,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '全息画像定制完成',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '已从 737 条建议中为您量身剪裁',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: p.inkSub),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                p,
                label: '专属激活防线',
                count: '${activeAdvice.length}',
                unit: '条',
                color: p.action,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                p,
                label: '剪枝排除噪音',
                count: '$prunedCount',
                unit: '条',
                color: Colors.green.shade600,
                icon: Icons.content_cut_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('已为您配置的核心防线摘要', style: _groupLabelStyle(p)),
        const SizedBox(height: 8),
        _buildProfileSummaryCard(p, tempProfile),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================================================
  // 底部控制条
  // ==========================================================================
  Widget _buildBottomBar(AppPalettes p) {
    if (_currentPage == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          children: [
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
                onPressed: _nextPage,
                child: const Text(
                  '开始定制全息防线 (推荐)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _complete,
              child: Text(
                '使用默认标准画像快速进入',
                style: TextStyle(color: p.inkSub, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentPage == _totalSteps - 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.action,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _complete,
            child: Text(
              widget.isReconfiguring ? '保存并生效画像' : '启动我的生活防线',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(color: p.hairline.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: p.hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _complete,
              child: Text(
                '以此配置直接开启',
                style: TextStyle(
                  color: p.inkSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.action,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _nextPage,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    '下一步',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 通用布局与小组件
  // ==========================================================================
  Widget _buildPageWrapper({required List<Widget> children}) {
    return FadeTransition(
      opacity: _pageFadeAnim,
      child: SlideTransition(
        position: _pageSlideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required String title, required String desc}) {
    final p = AppPalettes.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: p.ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: TextStyle(fontSize: 13, height: 1.5, color: p.inkSub),
        ),
      ],
    );
  }

  TextStyle _groupLabelStyle(AppPalettes p) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink);

  Widget _buildInfoBox(
    AppPalettes p, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.action.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.action.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.action),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.action,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, height: 1.45, color: p.inkSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPruneHint(AppPalettes p, String text) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.inkMute.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high, size: 14, color: p.action),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectCard(
    AppPalettes p, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? p.action.withValues(alpha: 0.08) : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? p.action : p.hairline,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: selected ? p.action : p.inkSub),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle, size: 16, color: p.action),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? p.action : p.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: p.inkSub)),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
    AppPalettes p,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: p.action,
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? Colors.white : p.ink,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildSwitchTile(
    AppPalettes p, {
    IconData? icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.hairline.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: value ? p.action : p.inkSub),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: p.action,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption<T>(
    AppPalettes p, {
    required String title,
    required String desc,
    required T value,
    required T groupValue,
    required ValueChanged<T> onChanged,
  }) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? p.action.withValues(alpha: 0.05) : p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.action : p.hairline,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? p.action : p.inkMute,
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? p.action : p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 11, color: p.inkSub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxTile(
    AppPalettes p, {
    required String title,
    required String desc,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? p.action.withValues(alpha: 0.5) : p.hairline,
        ),
      ),
      child: Row(
        children: [
          Checkbox(value: value, activeColor: p.action, onChanged: onChanged),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    AppPalettes p, {
    required String label,
    required String count,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummaryCard(AppPalettes p, UserProfile prof) {
    final tags = <String>[];
    tags.add('${prof.gender} · ${prof.age}岁');
    if (prof.isProgrammer) tags.add('程序员/技术研发');
    if (prof.isEntrepreneur) tags.add('创业商贸');
    if (prof.hasCar) tags.add('机动车驾乘');
    if (prof.hasTwowheeler) tags.add('电动两轮车');
    if (prof.isTenant) tags.add('租客');
    if (prof.hasMortgage) tags.add('房贷按揭');
    if (prof.hasChildren) tags.add('子女抚育');
    if (prof.isPregnantOrPlanning) tags.add('备孕/孕产');
    if (prof.hasAgingParents) tags.add('家有老人');
    if (prof.hasAbroadTravelOrStudy) tags.add('出境/留学');
    if (prof.hasDebtPressure) tags.add('债务防御');
    if (prof.hasKidneyStones) tags.add('肾结石关注');
    if (prof.hasGout) tags.add('痛风防范');
    if (prof.hasHypertension) tags.add('血压监测');
    if (prof.hasDiabetes) tags.add('血糖防线');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.action.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: p.action,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            '注：您可以随时在应用“我的”页面修改任何标签与偏好，生活防线将保持实时动态演化。',
            style: TextStyle(fontSize: 11, color: p.inkSub, height: 1.4),
          ),
        ],
      ),
    );
  }
}
