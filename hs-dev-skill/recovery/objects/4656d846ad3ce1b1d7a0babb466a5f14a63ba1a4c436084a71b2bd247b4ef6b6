import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog.dart';
import '../state/app_store.dart';

/// 启动引导：恢复本地状态。目录加载失败时给出兜底空目录（资产随包内置，正常不会发生）。
class Boot {
  static Future<AppStore> restore(Catalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(catalog, prefs);
    await store.restore();
    return store;
  }
}
