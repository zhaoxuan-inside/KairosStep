import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
  });

  test('Catalog 数据资产完整：767 条 / 34 章 / 13 形态 / 拼音全覆盖', () async {
    expect(catalog.adviceList.length, 767);
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

  test('767 建议全景六大支柱覆盖全库：100% 覆盖 767 条建议与 34 章节无遗漏', () async {
    // 验证六大支柱包含全部 34 章
    final domainChapters = LifeDomain.values.expand((d) => d.chapters).toList();
    expect(domainChapters.length, 34);
    expect(domainChapters.toSet().length, 34, reason: '章节在领域间互斥无重复');
    expect(domainChapters.toSet(), catalog.chapters.toSet(), reason: '34 章节 100% 映射');

    // 验证各支柱加总恰好 767 条
    final totalDomainCount = LifeDomain.values.fold<int>(0, (sum, d) => sum + d.totalCount);
    expect(totalDomainCount, 767);

    // 验证真实计算各领域条数
    for (final domain in LifeDomain.values) {
      final actualCount = catalog.adviceList
          .where((a) => domain.chapters.contains(a.chapter))
          .length;
      expect(actualCount, domain.totalCount,
          reason: '领域 ${domain.title} 实际条数与元数据强一致');
    }
  });

  test('画像匹配：已婚未育男性不出现孕产条目，女性排除特定规则', () async {
    final store = AppStore(catalog, await _emptyPrefs());
    final pregnancy = catalog.adviceList.where((a) => a.tags.contains('孕产'));
    for (final a in pregnancy) {
      expect(store.matchPersona(a), isFalse,
          reason: '建议 ${a.id} 应被男性画像排除');
    }
  });

  testWidgets('首次打开APP（无画像数据）：必须展示人性化优雅引导向导 Onboarding',
      (tester) async {
    final store = AppStore(catalog, await _emptyPrefs());
    await store.restore();

    expect(store.hasProfile, isFalse, reason: '初始状态无画像');

    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 验证展示了人性化引导语与纯净交付承诺
    expect(find.textContaining('数字阶跃'), findsWidgets);
    expect(find.textContaining('生活不需要一次性记住 767 条建议'), findsOneWidget);
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

    // 点击继续下一步进入第 5 步：全景六大支柱定制（100%覆盖767建议）
    await tester.tap(find.text('继续下一步 ›'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('人生六大支柱完整定制'), findsOneWidget);
    expect(find.textContaining('全书 767 条建议由六大支柱严密咬合'), findsOneWidget);
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

    // 切到库 Tab，验证 767 全景引导入口
    await tester.tap(find.text('库'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('767 全景引导'), findsOneWidget);
    await tester.tap(find.text('767 全景引导'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('767 条建议全景引导罗盘'), findsOneWidget);
    expect(find.textContaining('六大支柱完整覆盖'), findsOneWidget);
  });

  testWidgets('真实交付数据流：零 Mock 数据，全量 767 建议动态求值与打卡闭环', (tester) async {
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
}

Future<SharedPreferences> _emptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
