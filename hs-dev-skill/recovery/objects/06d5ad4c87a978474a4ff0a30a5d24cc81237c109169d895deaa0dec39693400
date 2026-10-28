import 'package:flutter/material.dart';

import 'app.dart';
import 'data/catalog.dart';
import 'ui/boot.dart';

/// 数字阶跃 KairosStep —— 本地优先的建议行动系统。
///
/// 启动流程：加载内置建议目录（纯本地资产）→ 恢复本地打卡状态 → 进入五 Tab 壳。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await Catalog.load();
  final store = await Boot.restore(catalog);
  runApp(KairosApp(catalog: catalog, store: store));
}
