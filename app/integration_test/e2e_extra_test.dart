// 补充 E2E：习惯养成（卡盾牌交互）与「父母适用」长辈相关建议范围。
//
// - 盾牌：建议卡头部 Tooltip「我已养成该习惯（移出日常待办，沉淀入生活防线）」，
//   点击后该建议沉淀入「我的 · 生活防线」并移出今日流；「重新练习」可逆。
//   断言按 formedHabits 差值进行，不依赖特定卡定位（对窄屏/懒加载更稳健）。
// - 父母适用：指南页范围三态 chip（固定头部，无需滚动），写 profile.parentsOnly
//   并持久化到 kProfile；长辈相关建议列表非空。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kairo_step/app.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/user.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:kairo_step/ui/cards/advice_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late Catalog catalog;
  late AppStore store;
  late SharedPreferences prefs;

  setUpAll(() async {
    catalog = await Catalog.load();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    prefs = await SharedPreferences.getInstance();
    store = AppStore(catalog, prefs);
    await store.restore();
    // flutter test 每次运行清空数据：无画像时先落一份默认画像进入主壳
    if (!store.hasProfile) {
      store.completeOnboarding(const UserProfile());
    }
    await tester.pumpWidget(KairosApp(catalog: catalog, store: store));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Finder navTab(String label) => find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label));

  /// 以 [inner] 所在滚动视口的中心向上拖拽（视口中心恒定有效）。
  Future<void> dragViewportUp(WidgetTester tester, Finder inner,
      {int times = 6}) async {
    final element = tester.element(
      find.ancestor(of: inner, matching: find.byType(Scrollable)).first,
    );
    final viewport = find.byElementPredicate((e) => identical(e, element));
    for (var i = 0; i < times; i++) {
      await tester.dragFrom(tester.getCenter(viewport), const Offset(0, -380));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
    }
  }

  testWidgets('H6 盾牌：打卡卡沉淀为生活防线并可重新练习（可逆）', (tester) async {
    await pumpApp(tester);
    await tester.tap(navTab('今天').first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(store.todayAdvices, isNotEmpty, reason: '今日流应有条目');

    final formedBefore = store.formedHabits.length;
    final shield = find.byTooltip('我已养成该习惯（移出日常待办，沉淀入生活防线）');

    // 滚动今日流直到任一未养成卡的盾牌被构建（懒加载）
    for (var i = 0; i < 10 && shield.evaluate().isEmpty; i++) {
      await dragViewportUp(tester, find.text('我的自建待办'), times: 1);
    }
    expect(shield, findsWidgets, reason: '今日流卡片的盾牌按钮可见');

    // 点第一枚盾牌；若 tap 落空则滚动后重试（以 formedHabits 差值为准）
    var tapped = false;
    for (var attempt = 0; attempt < 3 && !tapped; attempt++) {
      final current = find.byTooltip('我已养成该习惯（移出日常待办，沉淀入生活防线）');
      if (current.evaluate().isEmpty) break;
      await tester.ensureVisible(current.first);
      await tester.pumpAndSettle();
      await tester.tap(current.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      tapped = store.formedHabits.length > formedBefore;
    }
    expect(tapped, isTrue, reason: '点击盾牌后应有建议沉淀为生活防线');
    expect(find.textContaining('已形成习惯'), findsWidgets,
        reason: 'SnackBar 确认沉淀');
    final newHabitId = store.formedHabits.last;
    expect(store.isHabitFormed(newHabitId), isTrue, reason: '写入 kFormedHabits');

    // 我的页：生活防线「已筑牢 N 项本能」计数 +1
    await tester.tap(navTab('我的').first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final profileAnchor = find.textContaining('当前画像专属匹配');
    final defense = find.textContaining('已筑牢 ${formedBefore + 1} 项本能');
    for (var i = 0;
        i < 12 &&
            defense.evaluate().isEmpty &&
            profileAnchor.evaluate().isNotEmpty;
        i++) {
      await dragViewportUp(tester, profileAnchor, times: 1);
    }
    expect(defense, findsWidgets, reason: '生活防线计数 +1');

    // 重新练习（可逆）：移回今日待办流（以 store 真值为准，SnackBar 3s 即逝不作为断言）
    final relearn = find.text('重新练习');
    if (relearn.evaluate().isNotEmpty) {
      await tester.ensureVisible(relearn.first);
      await tester.pumpAndSettle();
      await tester.tap(relearn.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(store.isHabitFormed(newHabitId), isFalse, reason: '重新练习可逆');
      expect(store.formedHabits.length, formedBefore, reason: '计数回落');
      expect(store.todayAdvices.any((a) => a.id == newHabitId), isTrue,
          reason: '建议回到今日待办流');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    store.dispose();
  });

  testWidgets('F3 父母适用：长辈相关建议范围切换并持久化', (tester) async {
    await pumpApp(tester);
    await tester.tap(navTab('指南').first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 范围三态 chip 位于页首固定区（无需滚动）
    expect(store.profile.parentsOnly, isFalse, reason: '默认非父母适用范围');
    await tester.tap(find.text('父母适用'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(store.profile.parentsOnly, isTrue, reason: '切到父母适用范围');
    expect(find.byType(AdviceCard), findsWidgets,
        reason: '长辈相关建议列表非空');

    // 切回全量
    final fullChip = find.textContaining('全量');
    expect(fullChip, findsWidgets);
    await tester.tap(fullChip.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(store.profile.parentsOnly, isFalse, reason: '切回全量范围');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    store.dispose();
  });
}
