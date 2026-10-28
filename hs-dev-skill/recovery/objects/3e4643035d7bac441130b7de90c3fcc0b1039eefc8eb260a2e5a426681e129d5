import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/catalog.dart';
import 'state/app_store.dart';
import 'ui/onboarding/onboarding_view.dart';
import 'ui/shell.dart';

/// 应用根组件：持目录与全局状态，响应主题切换。
class KairosApp extends StatelessWidget {
  const KairosApp({super.key, required this.catalog, required this.store});

  final Catalog catalog;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        title: '数字阶跃',
        debugShowCheckedModeBanner: false,
        themeMode: store.themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => _CatalogScope(
          catalog: catalog,
          store: store,
          child: child ?? const SizedBox.shrink(),
        ),
        home: store.hasProfile ? const AppShell() : const OnboardingView(),
      ),
    );
  }
}

/// 目录与状态的 InheritedWidget，供任意子树无 context 传递地读取。
class _CatalogScope extends InheritedWidget {
  const _CatalogScope({
    required this.catalog,
    required this.store,
    required super.child,
  });

  final Catalog catalog;
  final AppStore store;

  @override
  bool updateShouldNotify(_CatalogScope oldWidget) =>
      catalog != oldWidget.catalog || store != oldWidget.store;
}

/// 读取目录。
Catalog catalogOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_CatalogScope>()!.catalog;

/// 读取全局状态。
AppStore storeOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_CatalogScope>()!.store;
