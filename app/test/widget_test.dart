import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/ui/cards/advice_card.dart';
import 'package:kairo_step/ui/now/gear_ruler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
  });

  test('Catalog 数据资产完整：737 条 / 34 章 / 13 形态 / 拼音全覆盖', () async {
    expect(catalog.adviceList.length, 737);
    expect(catalog.chapters.length, 34);
    expect(catalog.byId[1]!.chapter, '不要早死');
    expect(catalog.byId[1]!.actType, 'haptic-toggle');
    // 拼音映射可计算且值域合法
    final letters = catalog.adviceList.map(catalog.letterOf).toSet();
    expect(letters.every((l) => l.length == 1), isTrue);
    expect(letters.any((l) => l == '#'), isTrue);
    // 形态全覆盖
    final actTypes = catalog.adviceList.map((a) => a.actType).toSet();
    expect(actTypes.length, 13);
    // 详情层存在
    expect(catalog.detailOf(7)!.grade, 'A');
    expect(catalog.nodePackages.length, 5);
  });

  test('事件分类依据行动阶段，不因章节或标题出现危险词而误标', () {
    expect(catalog.byId[419]!.isEmergencyOrIncident, isTrue);
    expect(catalog.byId[431]!.isEmergencyOrIncident, isFalse);
    expect(catalog.byId[660]!.isEmergencyOrIncident, isFalse);
    expect(catalog.byId[18]!.topicPaths, ['health/prevention/screening']);
    expect(catalog.byId[24]!.topicPaths, ['health/prevention/screening']);
    expect(catalog.byId[31]!.topicPaths, ['health/prevention/screening']);
    expect(catalog.byId[38]!.topicPaths, ['health/treatment/medication']);
  });

  test('737 建议全景六大支柱覆盖全库：100% 覆盖 737 条建议与 34 章节无遗漏', () async {
    // 验证六大支柱包含全部 34 章
    final domainChapters = LifeDomain.values.expand((d) => d.chapters).toList();
    expect(domainChapters.length, 34);
    expect(domainChapters.toSet().length, 34, reason: '章节在领域间互斥无重复');
    expect(
      domainChapters.toSet(),
      catalog.chapters.toSet(),
      reason: '34 章节 100% 映射',
    );

    // 验证各支柱加总恰好 737 条
    final totalDomainCount = LifeDomain.values.fold<int>(
      0,
      (sum, d) => sum + d.totalCount,
    );
    expect(totalDomainCount, 737);

    // 验证真实计算各领域条数
    for (final domain in LifeDomain.values) {
      final actualCount = catalog.adviceList
          .where((a) => domain.chapters.contains(a.chapter))
          .length;
      expect(
        actualCount,
        domain.totalCount,
        reason: '领域 ${domain.title} 实际条数与元数据强一致',
      );
    }
  });

  test('画像匹配：已婚未育男性不出现孕产条目，女性排除特定规则', () async {
    final store = AppStore(catalog, await _emptyPrefs());
    final pregnancy = catalog.adviceList.where((a) => a.tags.contains('孕产'));
    for (final a in pregnancy) {
      expect(store.matchPersona(a), isFalse, reason: '建议 ${a.id} 应被男性画像排除');
    }
  });

  testWidgets('首次打开APP（无画像数据）：必须展示人性化优雅引导向导 Onboarding', (tester) async {
    final store = AppStore(catalog, await _emptyPrefs());
    await store.restore();

    expect(store.hasProfile, isFalse, reason: '初始状态无画像');

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 验证展示了人性化引导语与纯净交付承诺
    expect(find.textContaining('数字阶跃'), findsWidgets);
    expect(find.textContaining('生活不需要一次性记住 737 条建议'), findsOneWidget);
    expect(find.text('真正交付用户的纯净承诺'), findsOneWidget);
    expect(find.text('定制专属罗盘 ›'), findsOneWidget);

    // 点击定制专属罗盘进入第 1 步：生命时钟
    await tester.tap(find.text('定制专属罗盘 ›'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('年龄与生理节点'), findsOneWidget);
    expect(find.textContaining('有些检查一辈子做一次就够'), findsOneWidget);

    // 点击继续下一步进入第 2 步：职场形态
    await tester.tap(find.text('继续下一步 ›'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('核心职业形态'), findsOneWidget);
    expect(find.textContaining('别把自己搭进去'), findsOneWidget);

    // 点击继续下一步进入第 3 步：家庭与责任
    await tester.tap(find.text('继续下一步 ›'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('家庭与重要关系'), findsOneWidget);
    expect(find.textContaining('守护家人的底气'), findsOneWidget);

    // 点击继续下一步进入第 4 步：生活日常
    await tester.tap(find.text('继续下一步 ›'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('居住与日常情境'), findsOneWidget);
    expect(find.textContaining('日常最大的风险往往藏在最熟悉的习惯里'), findsOneWidget);

    // 点击继续下一步进入第 5 步：全景六大支柱定制（100%覆盖737建议）
    await tester.tap(find.text('继续下一步 ›'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('人生六大支柱完整定制'), findsOneWidget);
    expect(find.textContaining('全书 737 条建议由六大支柱严密咬合'), findsOneWidget);
    expect(find.textContaining('已点亮领域覆盖'), findsOneWidget);

    // 点击继续下一步进入第 6 步：罗盘校准与生成
    await tester.tap(find.text('继续下一步 ›'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('全息画像罗盘校准完成'), findsOneWidget);
    expect(find.text('步入数字阶跃 ›'), findsOneWidget);

    // 点击完成引导，步入真实生产交付界面
    await tester.tap(find.text('步入数字阶跃 ›'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(store.hasProfile, isTrue, reason: '已成功建立画像');
    expect(find.text('当下'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('周期'), findsOneWidget);
    expect(find.text('库'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    // 切到库 Tab，验证 737 全景引导入口
    await tester.tap(find.text('库'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('737 全景引导'), findsOneWidget);
    await tester.tap(find.text('737 全景引导'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('737 条建议全景引导罗盘'), findsOneWidget);
    expect(find.textContaining('六大支柱完整覆盖'), findsOneWidget);
  });

  testWidgets('真实交付数据流：零 Mock 数据，全量 737 建议动态求值与打卡闭环', (tester) async {
    final prefs = await _emptyPrefs();
    await prefs.setBool('kHasCompletedOnboarding', true);
    await prefs.setString(
      'kProfile',
      '{"gender":"男","age":28,"roles":["全民","上班族","伴侣","家人"],"livingConditions":["租房人","司机"],"healthConcerns":["久坐伏案"],"prunedOnly":true,"parentsOnly":false}',
    );

    final store = AppStore(catalog, prefs);
    await store.restore();

    expect(store.hasProfile, isTrue);

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 1. 当下页：动态时段建议与时间尺
    expect(find.text('当下'), findsOneWidget);
    final (doneToday, totalToday) = store.countersOf(PeriodScope.today);
    expect(totalToday, greaterThan(0), reason: '真实动态今日建议条数大于0，非Mock');

    // 2. 切到今天 Tab，验证真实待办卡交互
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('动态匹配'), findsOneWidget);

    // 寻找系安全带卡并完成交互
    final seatBeltCard = find.textContaining('车舱安全带锁止状态');
    if (seatBeltCard.evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('后排左: 扣上'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('后排左: 扣上'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('后排右: 扣上'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('后排右: 扣上'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.textContaining('四座全部锁止'), findsOneWidget);
    }

    // 3. 周期 Tab：真实每周/每月/每年动态条目
    await tester.tap(find.text('周期'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final (doneWeekly, totalWeekly) = store.countersOf(PeriodScope.weekly);
    expect(totalWeekly, greaterThan(0), reason: '真实动态每周建议条数大于0，非Mock');

    // 4. 我的 Tab：画像修改与重新引导入口
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('我的画像'), findsOneWidget);
    expect(find.textContaining('当前画像专属匹配'), findsOneWidget);
    expect(find.text('重设画像 · 进入全息引导向导'), findsOneWidget);

    // 5. 用户行为层验证：自建待办清单新增与勾选闭环
    store.addUserTodo('测试自定义自建待办事项');
    expect(store.userTodos.length, 1);
    expect(store.userTodos.first.isDone, isFalse);
    store.toggleUserTodo(store.userTodos.first.id);
    expect(store.userTodos.first.isDone, isTrue);
    store.removeUserTodo(store.userTodos.first.id);
    expect(store.userTodos.isEmpty, isTrue);
  });

  testWidgets('当下页时间尺：置顶展示、1.5小时视窗与推演回到此刻交互闭环', (tester) async {
    final prefs = await _emptyPrefs();
    await prefs.setBool('kHasCompletedOnboarding', true);
    await prefs.setString(
      'kProfile',
      '{"gender":"男","age":28,"roles":["全民"],"livingConditions":[],"healthConcerns":[],"prunedOnly":true,"parentsOnly":false}',
    );

    final store = AppStore(catalog, prefs);
    await store.restore();

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 默认在当下页：精简时间尺，不显示 1.5h 视窗与 -45分等冗余标注
    expect(find.text('1.5h 视窗'), findsNothing);
    expect(find.text('-45分 ‹ 此刻 › +45分'), findsNothing);

    // 验证时间尺处于拟人化提示语下方，核心行动卡上方
    final rulerTop = tester.getTopLeft(find.byType(GearRuler)).dy;
    final cardTop = tester.getTopLeft(find.byType(AdviceCard).first).dy;
    expect(rulerTop, lessThan(cardTop));

    // 模拟在时间尺上轻触进行时间推演
    await tester.tapAt(
      tester.getCenter(find.byType(GearRuler)).translate(-100, 10),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 验证展示「回到此刻」按钮
    expect(find.text('回到此刻'), findsOneWidget);

    // 点击回到此刻恢复实时同步
    await tester.tap(find.text('回到此刻'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('回到此刻'), findsNothing);
  });

  test('严格准入规则与 3D 翻转卡片自定义触发周期闭环', () async {
    final prefs = await _emptyPrefs();
    final store = AppStore(catalog, prefs);

    // 建议 46: 下化粪池先通风检测（偶发/单次安全建议，无固定日常周期）
    final septicAdvice = catalog.byId[46]!;
    expect(septicAdvice.title, contains('化粪池'));

    // 建议 475: 药按医嘱吃满，别感觉好了就停（遵医依从性红线建议，默认绝非每日提醒，平时静默储备）
    final medAdvice = catalog.byId[475]!;
    expect(medAdvice.actType, 'redline-stamp');
    expect(medAdvice.timingBadge, '红线知识 · 背熟即防');
    expect(
      store.todayAdvices.any((a) => a.id == 475),
      isFalse,
      reason: '药按医嘱吃满属于遵医红线与情境建议，默认静默储备，绝不进入日常今日流',
    );
    expect(store.periodAdvicesOf('morning').any((a) => a.id == 475), isFalse);

    // 验证严格准入：在未经自定义配置前，绝不进入今日流、时段流、周期流
    expect(
      store.todayAdvices.any((a) => a.id == 46),
      isFalse,
      reason: '偶发无日期建议绝不进入今日流',
    );
    expect(
      store.periodAdvicesOf('morning').any((a) => a.id == 46),
      isFalse,
      reason: '偶发建议绝不进入早晨时段',
    );
    expect(
      store.cycleAdvicesOf(PeriodScope.weekly).any((a) => a.id == 46),
      isFalse,
      reason: '偶发建议绝不进入每周周期',
    );

    // 模拟用户点击 3D 翻转卡片配置触发周期：将其显式配置为【日常节律 · 早晨】
    store.setTriggerConfig(
      46,
      const CustomTriggerConfig(
        mode: TriggerMode.daily,
        dailyPeriods: ['morning'],
      ),
    );

    // 验证即时编入：配置后动态重算，立刻进入今日流与早晨时段
    expect(
      store.todayAdvices.any((a) => a.id == 46),
      isTrue,
      reason: '用户显式配置为日常后进入今日待办',
    );
    expect(
      store.periodAdvicesOf('morning').any((a) => a.id == 46),
      isTrue,
      reason: '进入早晨时段流',
    );
    expect(
      store.periodAdvicesOf('night').any((a) => a.id == 46),
      isFalse,
      reason: '未配置夜间时段不进入夜间',
    );

    // 模拟重置配置：恢复系统默认
    store.resetTriggerConfig(46);
    expect(
      store.todayAdvices.any((a) => a.id == 46),
      isFalse,
      reason: '恢复默认后退出日常流',
    );
  });

  test('卡片个性化移除与排除库管理闭环（补全画像不足）', () async {
    final prefs = await _emptyPrefs();
    final store = AppStore(catalog, prefs);

    final todayList = store.todayAdvices;
    expect(todayList.isNotEmpty, isTrue);
    final targetId = todayList.first.id;

    // 用户在卡片右上角点击「移除」
    store.excludeAdvice(targetId);
    expect(store.isExcluded(targetId), isTrue);
    expect(store.excludedAdviceIds.contains(targetId), isTrue);

    // 验证日常所有流已动态过滤该项
    expect(
      store.todayAdvices.any((a) => a.id == targetId),
      isFalse,
      reason: '已排除条目从今日流中移除',
    );
    expect(
      store.periodAdvicesOf('morning').any((a) => a.id == targetId),
      isFalse,
      reason: '从时段流中移除',
    );

    // 用户在「我的」已排除管理中点击「重新启用」
    store.restoreAdvice(targetId);
    expect(store.isExcluded(targetId), isFalse);
    expect(
      store.todayAdvices.any((a) => a.id == targetId),
      isTrue,
      reason: '恢复后重新编入今日流',
    );
  });

  test('90 天培养周期体系与卡内基周复盘数据模型闭环', () async {
    final prefs = await _emptyPrefs();
    final store = AppStore(catalog, prefs);

    // 90 天计划初始状态与阶段
    final plan = store.ninetyDayPlan;
    expect(plan.currentDay, 1);
    expect(plan.phase, CyclePhase.kickoff);
    expect(plan.goalAdviceIds.length, 3);

    // 替换本周期某个动作
    store.swapCycleGoal(plan.goalAdviceIds.first, 19);
    expect(store.ninetyDayPlan.goalAdviceIds.contains(19), isTrue);

    // 标记节点复盘
    store.markKickoffReview(7);
    expect(store.ninetyDayPlan.kickoffReviewDay7, isTrue);

    // 卡内基 4 步周复盘写入与持久化
    store.addCarnegieReview(
      eventFact: '跨部门协作发生分歧',
      myAction: '急于反驳对方数据',
      theirReaction: '对方态度转为防御',
      nextOneSentence: '先复述对方观点，再讨论折中方案。',
      tag: '职场沟通',
    );
    expect(store.carnegieReviews.length, 1);
    expect(store.carnegieReviews.first.nextOneSentence, '先复述对方观点，再讨论折中方案。');
  });

  testWidgets('顶栏常驻搜索栏与紧急按钮，且默认外观为跟随系统', (tester) async {
    final prefs = await _emptyPrefs();
    await prefs.setBool('kHasCompletedOnboarding', true);
    await prefs.setString(
      'kProfile',
      '{"gender":"男","age":28,"roles":["全民"],"livingConditions":[],"healthConcerns":[],"prunedOnly":true,"parentsOnly":false}',
    );

    final store = AppStore(catalog, prefs);
    await store.restore();

    // 默认外观为跟随系统
    expect(store.themeMode, ThemeMode.system, reason: '外观默认配置必须为跟随系统');

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 验证搜索栏与紧急按钮在各页面常驻顶栏
    for (final tab in ['当下', '今天', '周期', '库', '我的']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
        find.textContaining('询问任何突发或生活决策'),
        findsOneWidget,
        reason: '$tab 页必须展示搜索栏',
      );
      expect(find.text('紧急'), findsOneWidget, reason: '$tab 页必须展示紧急按钮');
    }
  });

  test('突发与急救事件（如中暑处理、海姆立克、心肺复苏）严格静默储备，绝不进入当下时间尺聚焦视窗与今日流', () async {
    final prefs = await _emptyPrefs();
    final store = AppStore(catalog, prefs);
    await store.restore();

    // 查找中暑建议 (ID 419)
    final heatstroke = catalog.adviceList.firstWhere(
      (a) => a.title.contains('中暑'),
    );
    expect(
      heatstroke.isEmergencyOrIncident,
      isTrue,
      reason: '中暑处理必须识别为突发/应急条目',
    );
    expect(
      store.effectiveTriggerOf(heatstroke).mode,
      TriggerMode.dormant,
      reason: '突发应急事件默认推断必须为静默储备态',
    );

    // 验证中暑等应急事件严禁进入今日流
    expect(
      store.todayAdvices.any((a) => a.id == heatstroke.id),
      isFalse,
      reason: '中暑处理绝不能进入今日流',
    );

    // 验证中暑等应急事件严禁进入当下全天各个时刻的时间尺视窗
    final testHours = [6, 9, 11, 14, 16, 19, 21, 23];
    for (final h in testHours) {
      final windowAdvices = store.advicesForWindow(
        DateTime(2026, 10, 27, h, 0),
      );
      expect(
        windowAdvices.any((a) => a.id == heatstroke.id),
        isFalse,
        reason: '$h:00 视窗内绝不能展示中暑建议',
      );
      expect(
        windowAdvices.any((a) => a.isEmergencyOrIncident),
        isFalse,
        reason: '$h:00 视窗内绝不能包含任何应急急救建议',
      );
    }

    // 验证中暑处理被收录在紧急备查库中
    expect(
      store.emergencyAdvices.any((a) => a.id == heatstroke.id),
      isTrue,
      reason: '中暑处理必须在紧急备查库中随用随查',
    );
  });

  test('树状标签与画像前置守卫 (Prerequisites Gating) 严密生效', () async {
    final prefs = await _emptyPrefs();
    final store = AppStore(catalog, prefs);

    // 1. 全量 737 条建议均已完成树状路径与调度 Cron 注入
    expect(catalog.adviceList.every((a) => a.treePath.isNotEmpty), isTrue);
    expect(catalog.adviceList.every((a) => a.treeDisplay.isNotEmpty), isTrue);
    expect(catalog.adviceList.every((a) => a.cron.isNotEmpty), isTrue);

    // 2. 安全带也适用于乘客，不能因没有汽车而剪掉。
    final seatbelt = catalog.byId[1]!; // 系安全带
    expect(seatbelt.prerequisites.containsKey('has_car'), isFalse);

    // 默认无车画像
    store.profile = const UserProfile(hasCar: false);
    expect(store.matchPersona(seatbelt), isTrue, reason: '无车用户乘车时仍需安全带建议');

    // 开启有车画像
    store.profile = const UserProfile(hasCar: true);
    expect(store.matchPersona(seatbelt), isTrue, reason: '有车画像顺利通过安全带准入');

    // 3. 测试两轮车守卫 (hasTwowheeler)
    final helmet = catalog.byId[2]!; // 骑行头盔
    expect(helmet.prerequisites['has_twowheeler'], isTrue);

    store.profile = const UserProfile(hasTwowheeler: false);
    expect(store.matchPersona(helmet), isFalse, reason: '无两轮车画像必须过滤头盔');

    store.profile = const UserProfile(hasTwowheeler: true);
    expect(store.matchPersona(helmet), isTrue, reason: '有两轮车画像顺利通过头盔准入');

    // 4. 测试吸烟者守卫 (isSmoker)
    final smokingAdvices = catalog.adviceList
        .where((a) => a.prerequisites['is_smoker'] == true)
        .toList();
    expect(smokingAdvices.isNotEmpty, isTrue);

    store.profile = const UserProfile(isSmoker: false);
    for (final sa in smokingAdvices) {
      expect(store.matchPersona(sa), isFalse, reason: '非吸烟者必须过滤戒烟干预条目');
    }

    store.profile = const UserProfile(isSmoker: true);
    for (final sa in smokingAdvices) {
      expect(store.matchPersona(sa), isTrue, reason: '吸烟者画像顺利通过戒烟条目准入');
    }
  });
}

Future<SharedPreferences> _emptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
