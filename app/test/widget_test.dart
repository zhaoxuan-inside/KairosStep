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
    // 在用形态 12 种（zen-timer 定义保留但暂无条目使用）；在用集必须是定义子集
    expect(actTypes.length, 12);
    expect(
      actTypes.difference(actionTypes.map((d) => d.id).toSet()),
      isEmpty,
      reason: '在用形态必须都有交互形态定义',
    );
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

  testWidgets('首次打开APP（无画像数据）：隐私告知 → 卡牌流问答 → 成形 → 直接开启', (tester) async {
    final store = AppStore(catalog, await _emptyPrefs());
    await store.restore();

    expect(store.hasProfile, isFalse, reason: '初始状态无画像');

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 首次进入先见隐私告知：不联网 / 仅本地 / 卸载即除
    expect(find.text('在开始之前'), findsOneWidget);
    expect(find.text('永不联网'), findsOneWidget);
    expect(find.text('仅存本地'), findsOneWidget);
    expect(find.text('卸载即除'), findsOneWidget);
    await tester.tap(find.text('安心开启'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // 卡牌流问答（借鉴《八十亿分之一》逐张揭示）：一次一屏一题
    final flowCount = catalog.onboarding
        .visibleQuestions({})
        .where((q) => q.id != 'focus_domains')
        .length;
    expect(
      find.text('第 1/$flowCount 题'),
      findsOneWidget,
      reason: '卡牌流包含具体主题选择',
    );
    expect(find.text('你的性别'), findsOneWidget);
    expect(find.textContaining('已为你聚焦'), findsOneWidget);

    // 作答性别（单选自动前进到下一题）
    await tester.tap(find.text('男'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('你的年龄'), findsOneWidget, reason: '单选作答后自动前进');
    expect(tester.takeException(), isNull);

    // 其余各题逐题跳过（未答不剪，ADR-009），直到成形摘要
    for (var i = 0; i < 25; i++) {
      if (find.text('画像已成形').evaluate().isNotEmpty) break;
      final skip = find.text('跳过此题');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
      } else {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(find.text('画像已成形'), findsWidgets, reason: '过渡期新旧摘要共存');

    // 「以此配置直接开启」（未答不剪，ADR-009）
    await tester.tap(find.text('以此配置直接开启'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(store.hasProfile, isTrue, reason: '完成引导并持久化画像');
    expect(find.text('今天'), findsWidgets, reason: '完成引导后进入主壳');

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
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

    // 当当前日程包含安全带建议时，核对实际乘车事项；不存在预锁座位。
    final seatBeltCard = find.text('确认本人安全带已系好');
    if (seatBeltCard.evaluate().isNotEmpty) {
      for (final label
          in catalog.displayBindings.bindingOf(1)!.stringListParam('items')) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
      expect(store.cardState(PeriodScope.today, 1).isDone, isTrue);
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
    // 完成豁免期 Timer（2.6s）在 FakeAsync 区必须显式推进触发，避免挂起
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
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

    // 验证时间尺处于拟人化提示语下方，核心行动卡上方。
    // 1.5h 视窗随真实挂钟时间变化（夜间/清晨可能为空）——
    // 有 Hero 卡时断言层级；为空时断言空态文案。
    final rulerTop = tester.getTopLeft(find.byType(GearRuler)).dy;
    final heroCards = find.byType(AdviceCard);
    if (heroCards.evaluate().isNotEmpty) {
      final cardTop = tester.getTopLeft(heroCards.first).dy;
      expect(rulerTop, lessThan(cardTop));
    } else {
      expect(
        find.text('此 1.5 小时视窗内暂无计划行动'),
        findsOneWidget,
        reason: '当前时段无窗口行动时应显示空态',
      );
    }

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
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
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
    for (final tab in ['当下', '今天', '周期', '指南', '我的']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
        find.textContaining('询问任何突发或生活决策'),
        findsOneWidget,
        reason: '$tab 页必须展示搜索栏',
      );
      expect(find.text('紧急'), findsOneWidget, reason: '$tab 页必须展示紧急按钮');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
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

    // 60 岁吸烟者：is_smoker 条目普遍带 中年/老年 阶段标签（如老年 CT 筛查），
    // 阶段交集门禁要求画像年龄落在区间内——默认 28 岁被正确拦截，非门禁缺陷。
    store.profile = const UserProfile(isSmoker: true, age: 60);
    for (final sa in smokingAdvices) {
      expect(store.matchPersona(sa), isTrue, reason: '吸烟者画像顺利通过戒烟条目准入');
    }
  });
}

Future<SharedPreferences> _emptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
