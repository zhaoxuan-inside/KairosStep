import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../../core/icons.dart';
import '../core/theme.dart';
import '../state/app_store.dart';
import 'cycle/cycle_view.dart';
import 'emergency/emergency_sheet.dart';
import 'library/library_view.dart';
import 'me/me_view.dart';
import 'now/now_view.dart';
import 'search/search_delegate.dart';
import 'today/today_view.dart';

/// 五 Tab 壳：当下 / 今天 / 周期 / 库 / 我的。
///
/// 顶栏常驻紧急模式通道与全局搜索。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _views = [
    NowView(),
    TodayView(),
    CycleView(),
    LibraryView(),
    MeView(),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final (doneToday, _) = store.countersOf(PeriodScope.today);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶栏常驻：搜索栏与紧急按钮占据完整一行，全页面通用
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  // 全局自然语言搜索栏
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        showGlobalSearch(context);
                      },
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 16, color: p.inkSub),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '询问任何突发或生活决策（如：欠薪、胸痛）',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.inkSub.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右侧紧急模式直达按钮
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      EmergencySheet.show(context);
                    },
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: p.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.error.withValues(alpha: 0.45), width: 1.1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppHairlineIcons.emergencyBell(color: p.error, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '紧急',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: p.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 各页面视图流
            Expanded(
              child: _views[_index],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time),
            label: '当下',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: doneToday > 0,
              label: Text('$doneToday'),
              backgroundColor: p.emerald,
              child: const Icon(Icons.today_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: doneToday > 0,
              label: Text('$doneToday'),
              backgroundColor: p.emerald,
              child: const Icon(Icons.today),
            ),
            label: '今天',
          ),
          const NavigationDestination(
            icon: Icon(Icons.all_inclusive_outlined),
            selectedIcon: Icon(Icons.all_inclusive),
            label: '周期',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: '库',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
