import 'package:flutter/material.dart';

/// 主题中枢：色彩口径与 AdviceInteractiveDemo.html 的 CSS 变量一致。
///
/// - 深色「深邃曜石黑」：曜石底 + 玻璃卡片 + 蓝翠琥珀朱四强调色。
/// - 浅色「极简暖纸白」：暖纸底 + 纯白卡片。
/// 强调色：蓝 = 行动、翠绿 = 完成、琥珀 = 进行中、朱红 = 红线/紧急、靛蓝 = 流程/决策。
class AppPalettes {
  const AppPalettes({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceGlass,
    required this.hairline,
    required this.ink,
    required this.inkSub,
    required this.inkMute,
    required this.action,
    required this.emerald,
    required this.amber,
    required this.rose,
    required this.indigo,
    required this.pillBg,
    required this.searchBg,
  });

  final Brightness brightness;
  final Color canvas; // 页面底色
  final Color surface; // 卡片面
  final Color surfaceGlass; // 次级浮层（抽屉/胶囊）
  final Color hairline; // 细边线
  final Color ink; // 主文字
  final Color inkSub; // 次级文字
  final Color inkMute; // 弱文字
  final Color action; // 行动蓝
  final Color emerald; // 完成
  final Color amber; // 进行中 / 窗口期
  final Color rose; // 红线 / 紧急
  final Color indigo; // 流程 / 决策
  final Color pillBg; // 胶囊底
  final Color searchBg; // 搜索框底

  static const dark = AppPalettes(
    brightness: Brightness.dark,
    canvas: Color(0xFF0C0F17),
    surface: Color(0xFF1A1F30),
    surfaceGlass: Color(0xFF131722),
    hairline: Color(0x14FFFFFF),
    ink: Color(0xFFE2E8F0),
    inkSub: Color(0xFF94A3B8),
    inkMute: Color(0xFF64748B),
    action: Color(0xFF3B82F6),
    emerald: Color(0xFF10B981),
    amber: Color(0xFFF59E0B),
    rose: Color(0xFFF43F5E),
    indigo: Color(0xFF6366F1),
    pillBg: Color(0x1FFFFFFF),
    searchBg: Color(0xFF0E121C),
  );

  static const light = AppPalettes(
    brightness: Brightness.light,
    canvas: Color(0xFFF9F8F5),
    surface: Color(0xFFFFFFFF),
    surfaceGlass: Color(0xFFFFFFFF),
    hairline: Color(0x14000000),
    ink: Color(0xFF1E293B),
    inkSub: Color(0xFF475569),
    inkMute: Color(0xFF64748B),
    action: Color(0xFF2563EB),
    emerald: Color(0xFF059669),
    amber: Color(0xFFD97706),
    rose: Color(0xFFE11D48),
    indigo: Color(0xFF4F46E5),
    pillBg: Color(0x0F000000),
    searchBg: Color(0xFFF3F0E8),
  );

  static AppPalettes of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// 构建 MaterialApp 主题。
class AppTheme {
  static ThemeData dark() => _base(AppPalettes.dark);
  static ThemeData light() => _base(AppPalettes.light);

  static ThemeData _base(AppPalettes p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.action,
      onPrimary: Colors.white,
      secondary: p.emerald,
      onSecondary: Colors.white,
      error: p.rose,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerHighest: p.pillBg,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const [
        'PingFang SC',
        'Noto Sans SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
      textTheme: Typography.blackRedwoodCity.copyWith(
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: p.ink,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: p.ink,
          height: 1.4,
        ),
        bodyMedium: TextStyle(fontSize: 13, color: p.ink, height: 1.55),
        bodySmall: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.5),
        labelSmall: TextStyle(
          fontSize: 10.5,
          color: p.inkMute,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceGlass,
        indicatorColor: p.pillBg,
        height: 64,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: active ? p.ink : p.inkMute,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceGlass,
        modalBackgroundColor: p.surfaceGlass,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(color: p.canvas, fontSize: 12.5),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    );
  }
}
