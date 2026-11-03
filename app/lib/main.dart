import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/catalog.dart';
import 'ui/boot.dart';

/// 数字阶跃 KairosStep —— 本地优先的建议行动系统。
///
/// 启动流程：加载内置建议目录（纯本地资产）→ 恢复本地打卡状态 → 进入五 Tab 壳。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 崩溃取证：Dart/框架异常统一写入 logcat（adb logcat | grep KairosCrash）。
  // 原生崩溃仍需系统 tombstone；这里保证能区分「框架异常」与「原生崩溃」。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[KairosCrash] ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[KairosCrash][async] $error\n$stack');
    return true;
  };

  final catalog = await Catalog.load();
  final store = await Boot.restore(catalog);
  runApp(KairosApp(catalog: catalog, store: store));
}
