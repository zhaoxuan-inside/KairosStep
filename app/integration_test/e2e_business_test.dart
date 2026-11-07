// KairosStep E2E 业务测试（Android 模拟器实机运行）。
//
// 用例设计见 docs/test/业务测试用例-E2E.md（模块 A-I）。
// 运行方式：
//   flutter test integration_test/e2e_business_test.dart -d emulator-5554
//
// 每个用例组独立泵起应用；组间通过真实 SharedPreferences 传递状态（本地优先）。
// 「进程内重启」= 卸载组件树 → dispose 旧 AppStore → 以同一 prefs 重建 restore
// → 重新 runApp，验证 kProfile / kScope.today / kUserTodos / kEmergencyContacts
// 等持久化恢复（与冷启动同路径）。
//
// 实机稳定性约定：
// - 页面列表为懒加载 + IndexedStack 全页签常驻 → 一律用「视口中心拖拽」滚动；
// - tap 前把目标滚入屏幕中部安全带（避开顶栏/底部导航/SnackBar 遮挡）；
// - Tab 定位限定 NavigationBar（页面标题与 Tab 同名）；
// - 弹层字段限定弹层作用域（弹层背后页面的同名控件会被 finder 命中）；
// - 业务断言以 store 状态为权威，UI 文本为辅助。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/ui/cards/interactors.dart';
import 'package:kairo_step/ui/now/gear_ruler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late Catalog catalog;
  late AppStore store;
  late SharedPreferences prefs;
  bool storeAlive = false;

  setUpAll(() async {
    catalog = await Catalog.load();
  });

  /// 全新安装：清空本地状态后冷启动（用例 A1 前置）。
  Future<void> pumpFreshApp(WidgetTester tester) async {
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    store = AppStore(catalog, prefs);
    storeAlive = true;
    await store.restore();
    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// 以现有本地状态冷启动（引导已完成 / 已有打卡与待办）。
  Future<void> pumpApp(WidgetTester tester) async {
    store = AppStore(catalog, prefs);
    storeAlive = true;
    await store.restore();
    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// 进程内重启：卸载组件树 → 重建 store.restore → 再泵起（用例 B3/C5/G4/I1）。
  Future<void> restartApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    if (storeAlive) store.dispose();
    storeAlive = false;
    await pumpApp(tester);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    if (storeAlive) store.dispose();
    storeAlive = false;
  }

  /// 确保可见后点击（实机上视口外 tap 会落空）。
  Future<void> tapVisible(
    WidgetTester tester,
    Finder finder, {
    Duration settle = const Duration(milliseconds: 600),
    String? reason,
  }) async {
    expect(finder, findsWidgets, reason: reason);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first, warnIfMissed: false);
    await tester.pumpAndSettle(settle);
  }

  /// 包含 [inner] 的滚动视口（Scrollable 元素不随子项虚拟化，取其视口中心
  /// 作为拖拽起点——该点在滚动过程中恒定有效）。
  Finder scrollViewportOf(WidgetTester tester, Finder inner) {
    final element = tester.element(
      find.ancestor(of: inner, matching: find.byType(Scrollable)).first,
    );
    return find.byElementPredicate((e) => identical(e, element));
  }

  /// 在 [inner] 所在列表里向上滚动，直到 [text] 被懒加载构建。
  Future<void> scrollListToText(
    WidgetTester tester,
    Finder inner,
    String text, {
    int max = 14,
  }) async {
    final viewport = scrollViewportOf(tester, inner);
    for (var i = 0; i < max && find.text(text).evaluate().isEmpty; i++) {
      await tester.dragFrom(tester.getCenter(viewport), const Offset(0, -380));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
    }
  }

  /// 把目标滚动到屏幕中部安全带（避开顶栏/底部导航遮挡导致的 tap 落空）。
  Future<void> scrollFinderToBand(WidgetTester tester, Finder finder) async {
    final viewport = scrollViewportOf(tester, finder);
    final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (var i = 0; i < 10; i++) {
      if (finder.evaluate().isEmpty) return;
      final y = tester.getCenter(finder).dy;
      if (y > 200 && y < h - 280) return;
      await tester.dragFrom(tester.getCenter(viewport), Offset(0, y < 200 ? 380 : -380));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
    }
  }

  /// 长标题按前缀定位（卡片文本可能截断）。
  Finder byTitlePrefix(String title, {int chars = 8}) => find.textContaining(
      title.substring(0, title.length < chars ? title.length : chars));

  /// 底部导航 Tab（页面标题与 Tab 同名，必须限定在 NavigationBar 内）。
  Finder navTab(String label) => find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label));

  // ══════════════════ 模块 A · 启动与画像引导 ══════════════════

  testWidgets('A1-A3 全新安装 → 画像引导作答必答题 → 完成进入主壳', (tester) async {
    await pumpFreshApp(tester);

    // A1：无画像 → 引导页（基本盘 1/7，必答标记与聚焦反馈可见）
    expect(find.textContaining('画像引导 · '), findsOneWidget);
    expect(find.text('画像引导 · 基本盘'), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('必答'), findsWidgets);
    expect(find.textContaining('已为你聚焦'), findsOneWidget);

    // A2：性别（单选）
    await tapVisible(tester, find.text('男'), reason: '性别选项可见');
    // 年龄/身高/体重三个滑块（必答）：各拖动一次即作答
    final sliders = find.byType(Slider);
    expect(sliders.evaluate().length, 3, reason: '基本盘层有 年龄/身高/体重 三个滑块');
    for (var i = 0; i < 3; i++) {
      final delta = i == 2 ? const Offset(-40, 0) : const Offset(40, 0);
      await tester.ensureVisible(sliders.at(i));
      await tester.drag(sliders.at(i), delta);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('已为你聚焦'), findsOneWidget,
        reason: '作答后聚焦反馈仍实时可见');

    // 推进到健康基线（第 4 层）作答吸烟与慢病
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.text('下一步'), reason: '引导推进');
    }
    expect(find.text('画像引导 · 健康基线'), findsOneWidget);
    await tapVisible(tester, find.text('不吸烟'), reason: '吸烟题选项');
    await tapVisible(tester, find.text('高血压'), reason: '慢病多选选一项即视为已答');

    // A3：推进至末页 → 完成并开启 → 进入主壳
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.text('下一步'), reason: '引导推进');
    }
    await tapVisible(tester, find.text('完成并开启'), reason: '必答齐后主按钮可用');
    expect(store.hasProfile, isTrue);
    expect(prefs.getBool('kHasCompletedOnboarding'), isTrue);
    expect(prefs.getString('kProfile'), isNotNull);

    // 五 Tab 主壳齐备
    for (final tab in ['当下', '今天', '周期', '指南', '我的']) {
      expect(navTab(tab), findsWidgets, reason: 'Tab $tab');
    }
    await teardown(tester);
  });

  testWidgets('A4+B1-B3 已完成引导冷启动直达主壳；建议打卡与打卡持久化', (tester) async {
    await pumpApp(tester);

    // A4：不再出现画像引导
    expect(find.textContaining('画像引导 · '), findsNothing);

    // B1：今天页结构
    await tapVisible(tester, navTab('今天'), reason: 'Tab 今天');
    expect(find.textContaining('按画像动态匹配'), findsWidgets);
    expect(find.text('我的自建待办'), findsOneWidget);

    // B2：打卡第一张 quick-checkin 卡（无则退回第一张可交互卡）
    final today = List<Advice>.of(store.todayAdvices);
    expect(today, isNotEmpty, reason: '全民画像今日流应有节律条目');
    Advice target = today.firstWhere(
      (a) => a.actType == 'quick-checkin',
      orElse: () => today.first,
    );
    // 列表懒加载：以视口中心拖拽滚动直到目标卡标题被构建
    final titleFinder = byTitlePrefix(target.title);
    await scrollListToText(tester, find.text('我的自建待办'), target.title);
    expect(titleFinder, findsWidgets, reason: '目标卡 #${target.id} 滚动后可见');

    final before = store.countersOf(PeriodScope.today).$1;
    if (target.actType == 'quick-checkin') {
      // 打卡按钮限定在目标卡面板内，且以「完成」为前缀（避免命中他卡控件）；
      // 以 store 真值为准，tap 落空时重试（最多 3 次）
      for (var attempt = 0; attempt < 3; attempt++) {
        if (store.cardState(PeriodScope.today, target.id).isDone) break;
        final cardScope = find.ancestor(
          of: titleFinder.first,
          matching: find.byType(AnimatedContainer),
        ).first;
        Text? btnText;
        for (final e in find
            .descendant(of: cardScope, matching: find.textContaining('完成'))
            .evaluate()) {
          final t = e.widget as Text;
          if ((t.data ?? '').startsWith('完成')) {
            btnText = t;
            break;
          }
        }
        expect(btnText, isNotNull, reason: 'quick-checkin 卡内有「完成：…」按钮');
        final btnFinder = find.byWidget(btnText!);
        await scrollFinderToBand(tester, btnFinder);
        await tester.tap(btnFinder, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
      // 以 store 真值为权威断言；卡片完成后可能在流内重排并被懒加载回收，
      // UI 文本断言仅在卡片仍被构建时执行
      expect(store.cardState(PeriodScope.today, target.id).isDone, isTrue,
          reason: 'quick-checkin 点击后卡片打卡完成');
      if (titleFinder.evaluate().isNotEmpty) {
        expect(find.textContaining('已完成 · 点击撤销'), findsWidgets,
            reason: 'quick-checkin 点击后应显示已完成');
      }
    } else {
      // 通用兜底：屏内交互器逐个点直至完成数增加
      for (var i = 0; i < 6 && store.countersOf(PeriodScope.today).$1 == before; i++) {
        final tapTargets = find.descendant(
          of: find.byType(AdviceInteractor),
          matching: find.byType(InkWell),
        );
        if (tapTargets.evaluate().length <= i) break;
        await tester.ensureVisible(tapTargets.at(i));
        await tester.tap(tapTargets.at(i), warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }
    }
    final after = store.countersOf(PeriodScope.today).$1;
    expect(after, greaterThan(before), reason: '打卡后今日完成数增加');
    if (byTitlePrefix(target.title).evaluate().isNotEmpty) {
      expect(find.byKey(const ValueKey('ok')), findsWidgets,
          reason: '完成条出现已闭环标记');
    }

    // B3：进程内重启后打卡态保持
    final doneBeforeRestart = store.countersOf(PeriodScope.today).$1;
    expect(prefs.getString('kScope.today'), isNotNull, reason: '打卡写入 kScope.today');
    await restartApp(tester);
    expect(find.textContaining('画像引导 · '), findsNothing, reason: '重启不回引导');
    expect(store.countersOf(PeriodScope.today).$1, doneBeforeRestart,
        reason: '重启后打卡计数保持');
    await teardown(tester);
  });

  // ══════════════════ 模块 C · 自建待办 ══════════════════

  testWidgets('C1-C4 新建待办：空标题拦截 → 保存注入 → 勾选完成 → 删除', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, navTab('今天'), reason: 'Tab 今天');

    // C1：今天页「新建待办」入口 → 空标题提交被拦截
    await tapVisible(tester, find.text('新建待办'), reason: '待办区新建入口');
    expect(find.text('新建自建待办 · 生活防线'), findsOneWidget);
    final saveBtn = find.text('保存并注入生活防线');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('请输入待办标题'), findsOneWidget, reason: '空标题应有 SnackBar 拦截');
    // 等真实 SnackBar 消失，避免浮层挡住保存按钮
    await Future<void>.delayed(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // C2：填写标题并保存（以 store 状态为权威断言，SnackBar 为辅助）
    await tester.enterText(find.byType(TextField).first, '睡前测血压');
    await tester.pumpAndSettle();
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(store.userTodos.any((t) => t.title == '睡前测血压'), isTrue,
        reason: '待办写入 kUserTodos');
    expect(find.textContaining('已添加待办「睡前测血压」'), findsOneWidget);

    // C3：勾选完成
    final todo = store.userTodos.firstWhere((t) => t.title == '睡前测血压');
    final toggle = find.byKey(ValueKey('todo-toggle-${todo.id}'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(store.userTodos.firstWhere((t) => t.id == todo.id).isDone, isTrue);

    // C4：再建一个「仅一次」待办并删除（先等上一条 SnackBar 消失）
    await Future<void>.delayed(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('新建待办'), reason: '再次新建');
    await tester.enterText(find.byType(TextField).first, '复核劳动合同');
    await tester.pumpAndSettle();
    final freqDropdown = find.byType(DropdownButton<String>).first;
    await tester.ensureVisible(freqDropdown);
    await tester.tap(freqDropdown, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tapVisible(tester, find.text('仅一次').last, reason: '频次菜单项');
    final saveBtn2 = find.text('保存并注入生活防线');
    await tester.ensureVisible(saveBtn2);
    await tester.tap(saveBtn2, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final todo2 = store.userTodos.firstWhere((t) => t.title == '复核劳动合同');
    expect(todo2.frequency, 'once');
    final remove = find.byKey(ValueKey('todo-remove-${todo2.id}'));
    await tester.ensureVisible(remove);
    await tester.tap(remove, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(store.userTodos.any((t) => t.id == todo2.id), isFalse, reason: '删除后行消失');

    // C5（持久化）：重启后「睡前测血压」仍存在且完成态保持
    await restartApp(tester);
    expect(store.userTodos.any((t) => t.title == '睡前测血压' && t.isDone), isTrue,
        reason: '重启后自建待办与完成态保持');
    await teardown(tester);
  });

  // ══════════════════ 模块 D · 当下页与时间尺 ══════════════════

  testWidgets('D1-D3 当下页：时段徽标、1.5 小时窗口、时间尺预演与回到此刻', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, navTab('当下'), reason: 'Tab 当下');

    // D1：时段徽标（5 时段之一）+ 呼吸练习
    const badges = [
      '早晨 · 05:00-09:30',
      '上午 · 09:30-12:00',
      '午后 · 12:00-18:00',
      '傍晚 · 18:00-22:00',
      '夜深 · 22:00-05:00',
    ];
    final badgeHit = badges.any((b) => find.text(b).evaluate().isNotEmpty);
    expect(badgeHit, isTrue, reason: '应出现 5 时段徽标之一');
    expect(find.text('一分钟呼吸'), findsOneWidget, reason: '呼吸练习组件在当下页');

    // D2：1.5 小时窗口（有 Hero 卡标题或空态）
    final hasWindow = find.textContaining('1.5小时核心行动').evaluate().isNotEmpty;
    final empty = find.text('此 1.5 小时视窗内暂无计划行动').evaluate().isNotEmpty;
    expect(hasWindow || empty, isTrue, reason: '窗口区必有 Hero 标题或空态');

    // D3：拖动时间尺进入预演 → 回到此此刻
    if (hasWindow) {
      final ruler = find.byType(GearRuler);
      expect(ruler, findsOneWidget);
      await tester.drag(ruler, const Offset(-240, 0));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
      expect(find.text('回到此刻'), findsOneWidget, reason: '拖动后进入预演模式');
      await tapVisible(tester, find.text('回到此刻'), reason: '回到此刻胶囊');
      expect(find.text('回到此刻'), findsNothing, reason: '点击后回到实时模式');
    }
    await teardown(tester);
  });

  // ══════════════════ 模块 E · 周期页 ══════════════════

  testWidgets('E1-E2 周期页：90 天看板与每周/每月/每年切换', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, navTab('周期'), reason: 'Tab 周期');

    expect(find.textContaining('/ 90 天'), findsOneWidget);
    expect(find.text('本周期聚焦 3 个核心动作'), findsOneWidget);
    expect(find.text('每周'), findsOneWidget);
    expect(find.text('每月'), findsOneWidget);
    expect(find.text('每年'), findsOneWidget);

    await tapVisible(tester, find.text('每月'), reason: '月 tab');
    await tapVisible(tester, find.text('每年'), reason: '年 tab');
    await tapVisible(tester, find.text('每周'), reason: '周 tab');
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  // ══════════════════ 模块 F · 指南页与搜索 ══════════════════

  testWidgets('F1-F2 指南库渲染与全局搜索（词法+语义兜底）', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, navTab('指南'), reason: 'Tab 指南');

    expect(find.text('生活指南'), findsOneWidget);
    expect(find.textContaining('737'), findsWidgets, reason: '全量 737 计数可见');
    expect(find.text('34 章节'), findsOneWidget);

    // F2：全局搜索「欠薪」
    await tapVisible(tester, find.textContaining('询问任何突发或生活决策'),
        reason: '顶栏搜索栏');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField).first, '欠薪');
    // 语义检索为异步（模型加载秒级）；词法结果即刻出现，语义完成后融合替换
    var hit = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.textContaining(RegExp(r'命中 \d+ 条')).evaluate().isNotEmpty) {
        hit = true;
        break;
      }
      if (find.text('无匹配建议').evaluate().isNotEmpty) break;
    }
    expect(hit, isTrue, reason: '搜索「欠薪」应有命中计数');
    expect(find.textContaining(RegExp(r'命中 [1-9]')), findsWidgets,
        reason: '命中数应大于 0');
    // 关闭搜索回到主壳（搜索页用「取消」退出，无系统返回按钮）
    final cancel = find.text('取消');
    if (cancel.evaluate().isNotEmpty) {
      await tester.tap(cancel.first, warnIfMissed: false);
    } else {
      await tester.pageBack();
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  // ══════════════════ 模块 G · 紧急模式与紧急联系人 ══════════════════

  testWidgets('G1-G4 紧急模式：直拨确认、添加联系人、持久化', (tester) async {
    await pumpApp(tester);

    // G1：紧急入口
    await tapVisible(tester, find.text('紧急'), reason: '顶栏紧急入口');
    expect(find.text('紧急模式 · 离线全速就绪'), findsOneWidget);
    expect(find.textContaining('120'), findsWidgets);
    expect(find.textContaining('110'), findsWidgets);
    expect(find.textContaining('12356'), findsWidgets);
    expect(find.text('预设紧急联系人'), findsOneWidget);

    // G2：120 → 确认弹窗 → 取消（不依赖模拟器拨号器）
    await tapVisible(tester, find.text('120'), reason: '极速直拨 120 卡');
    expect(find.textContaining('拨打 120'), findsWidgets);
    await tapVisible(tester, find.text('取消'), reason: '呼叫确认弹窗取消');

    // G3：添加紧急联系人（字段限定在弹层内——弹层背后页面的搜索框会被 finder 命中）
    await tapVisible(tester, find.text('添加联系人'), reason: '联系人入口');
    final sheetScope = find.ancestor(
      of: find.text('添加本地紧急联系人'),
      matching: find.byType(Column),
    ).first;
    final fields = find.descendant(of: sheetScope, matching: find.byType(TextField));
    expect(fields.evaluate().length, 3, reason: '姓名/关系/电话三个输入框');
    await tester.enterText(fields.at(0), '张三');
    await tester.enterText(fields.at(1), '父亲');
    await tester.enterText(fields.at(2), '13800000000');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('保存到本机'), reason: '联系人保存');
    expect(
        store.emergencyContacts
            .any((c) => c.name == '张三' && c.phone == '13800000000'),
        isTrue,
        reason: '写入 kEmergencyContacts');
    expect(find.textContaining('张三'), findsWidgets, reason: '联系人卡出现在列表');

    // G4：重启后联系人保持
    await restartApp(tester);
    expect(store.emergencyContacts.any((c) => c.name == '张三'), isTrue,
        reason: '重启后紧急联系人保持');
    await teardown(tester);
  });

  // ══════════════════ 模块 H · 我的页与小工具 ══════════════════

  testWidgets('H1-H3 我的页：画像匹配数、主题切换、年龄滑块', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, navTab('我的'), reason: 'Tab 我的');

    expect(find.text('我的画像'), findsOneWidget);
    expect(find.textContaining('当前画像专属匹配'), findsOneWidget);

    // 外观/生活防线区在首屏下方（懒加载未构建）：以视口中心拖拽滚动
    final profileAnchor = find.textContaining('当前画像专属匹配');
    await scrollListToText(tester, profileAnchor, '深邃曜石黑');
    expect(find.text('深邃曜石黑'), findsOneWidget);
    expect(find.text('极简暖纸白'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);

    // H3：主题切换（写 kThemeMode；每次切换列表重建，需重新滚入安全带）
    await scrollFinderToBand(tester, find.text('极简暖纸白'));
    await tester.tap(find.text('极简暖纸白'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(prefs.getString('kThemeMode'), 'light');
    await scrollFinderToBand(tester, find.text('深邃曜石黑'));
    await tester.tap(find.text('深邃曜石黑'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(prefs.getString('kThemeMode'), 'dark');

    // H2：年龄滑块调整 → 画像更新（滑块在画像卡内，先滚回顶部区域）
    final ageSlider = find.byType(Slider).first;
    if (ageSlider.evaluate().isNotEmpty) {
      await scrollFinderToBand(tester, ageSlider);
      final beforeAge = store.profile.age;
      await tester.drag(ageSlider, const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(store.profile.age, isNot(equals(beforeAge)), reason: '拖动滑块更新画像年龄');
    }

    // 生活防线区
    await scrollListToText(tester, profileAnchor, '我的生活防线');
    expect(find.text('我的生活防线'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('H4-H5 心情晴雨表与卡内基周复盘', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, navTab('今天'), reason: 'Tab 今天');

    // H4：心情晴雨表三步（压力路径）
    await tapVisible(tester, find.textContaining('心情晴雨表'), reason: '快捷入口');
    expect(find.text('你今天的心情怎么样？'), findsOneWidget);
    await tapVisible(tester, find.textContaining('压力山大'), reason: '低落心情选项');
    // 角色化两问：两题的 chips 依次排列，选首枚（题一）与末枚（题二）
    final chips = find.byType(ChoiceChip);
    expect(chips.evaluate().length, greaterThanOrEqualTo(2), reason: '两道角色化问题');
    await tapVisible(tester, chips.first, reason: '题一选项');
    await tapVisible(tester, chips.last, reason: '题二选项');
    final adviceBtn = find.widgetWithText(FilledButton, '查看今日心理韧性建议');
    expect(adviceBtn, findsOneWidget);
    expect(tester.widget<FilledButton>(adviceBtn.first).onPressed, isNotNull,
        reason: '两题作答后建议按钮可用');
    await tapVisible(tester, find.text('查看今日心理韧性建议'), reason: '进入建议页');
    expect(find.textContaining('察觉到了你的紧绷'), findsWidgets,
        reason: '压力路径给出减压建议');
    final finish = find.text('完成今日状态记录');
    await tapVisible(tester, finish, reason: '完成心情记录');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('你今天的心情怎么样？'), findsNothing,
        reason: '心情弹窗应已关闭，避免遮挡后续交互');

    // H5：卡内基四步复盘（默认文案可越过）。
    // 快捷入口「周复盘」直接打开复盘页；今日页复盘卡的「开始复盘」在列表下部，
    // 懒加载可能未构建——两种入口择一可用即可。
    final reviewEntry = find.textContaining('周复盘');
    expect(reviewEntry, findsWidgets, reason: '周复盘入口存在');
    final startBtn = find.text('开始复盘');
    if (startBtn.evaluate().isNotEmpty) {
      await tester.tap(startBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } else {
      await tapVisible(tester, reviewEntry.first, reason: '快捷入口打开复盘页');
    }
    expect(find.textContaining('卡内基'), findsWidgets);
    for (var i = 0; i < 3; i++) {
      final step = find.text('下一步');
      if (step.evaluate().isEmpty) break;
      await tester.ensureVisible(step.first);
      await tester.tap(step.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }
    final seal = find.text('落印完成复盘');
    if (seal.evaluate().isNotEmpty) {
      await tester.ensureVisible(seal.first);
      await tester.tap(seal.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    expect(store.carnegieReviews, isNotEmpty, reason: '复盘落印写入 kCarnegieReviews');
    await teardown(tester);
  });

  // ══════════════════ 模块 I · 汇总持久化 ══════════════════

  testWidgets('I1 全量持久化恢复：画像/打卡/待办/联系人在重启后齐备', (tester) async {
    await restartApp(tester);
    expect(store.hasProfile, isTrue, reason: '画像保持');
    expect(find.textContaining('画像引导 · '), findsNothing, reason: '不回引导');
    expect(prefs.getString('kScope.today'), isNotNull, reason: '打卡保持');
    expect(store.userTodos.map((t) => t.title), contains('睡前测血压'),
        reason: '待办保持');
    expect(store.emergencyContacts.map((c) => c.name), contains('张三'),
        reason: '联系人保持');

    // 主壳完整可用
    for (final tab in ['当下', '今天', '周期', '指南', '我的']) {
      expect(navTab(tab), findsWidgets);
    }
    await teardown(tester);
  });

  tearDownAll(() {
    // 实机结果由 flutter test 汇总；此处仅标记用例组执行完毕
    // ignore: avoid_print
    print('E2E 全部用例执行完毕');
  });
}
