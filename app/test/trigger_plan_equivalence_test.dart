// L6 触发数据等价性证明（Phase 1 验收，REFACTOR_DESIGN §4.7/§9）：
// 流水线离线复刻的 triggers/advice_trigger.json 必须与运行时
// AppStore.effectiveTriggerOf（旧算法，词表推断）对 737 条建议逐一相等。
// 任一侧词表改动都会在此测试失败——防止数据与代码漂移。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/models/advice.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;
  late AppStore store;
  late List<Map<String, dynamic>> plans;

  setUpAll(() async {
    catalog = await Catalog.load();
    SharedPreferences.setMockInitialValues({});
    store = AppStore(catalog, await SharedPreferences.getInstance());
    plans = ((jsonDecode(File('assets/data/triggers/advice_trigger.json')
                        .readAsStringSync())
                as Map<String, dynamic>)['list'] as List)
        .cast<Map<String, dynamic>>();
  });

  test('L6 数据与运行时 effectiveTriggerOf 逐一等价（737 条）', () {
    expect(plans, hasLength(catalog.adviceList.length));
    final byId = {for (final p in plans) p['id'] as int: p};
    var checked = 0;
    for (final advice in catalog.adviceList) {
      final plan = byId[advice.id];
      expect(plan, isNotNull, reason: 'L6 缺少建议 ${advice.id} 的触发计划');
      final cfg = store.effectiveTriggerOf(advice);
      expect(plan!['mode'], cfg.mode.name,
          reason: 'mode 不一致 @${advice.id}');
      expect(plan['emergency'], advice.isEmergencyOrIncident,
          reason: 'emergency 标记不一致 @${advice.id}');
      if (cfg.mode == TriggerMode.daily) {
        expect(plan['dailyPeriods'], cfg.dailyPeriods,
            reason: 'dailyPeriods 不一致 @${advice.id}');
        expect(plan['reminderTimes'], cfg.reminderTimes,
            reason: 'reminderTimes 不一致 @${advice.id}');
      }
      if (cfg.mode == TriggerMode.cadence) {
        expect(plan['cadenceScopeKey'], cfg.cadenceScopeKey,
            reason: 'cadenceScopeKey 不一致 @${advice.id}');
      }
      checked++;
    }
    // ignore: avoid_print
    print('等价性校验 $checked 条触发计划：L6 数据 == 运行时旧算法');
  });
}
