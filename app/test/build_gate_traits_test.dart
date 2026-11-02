// 门禁谓词预编译资产的生成与校验（用法同 golden 先例）：
//   GATE_TRAITS_UPDATE=1 flutter test test/build_gate_traits_test.dart
//     → 经真实 Catalog.load() 提取全量 traits，重建 assets/data/config/gate_traits.json
//   flutter test test/build_gate_traits_test.dart
//     → 校验入库资产：指纹与随包数据一致 + 与现算结果逐条全等
// 数据（advice.json / gates.json）变更后必须重建，否则运行时指纹校验
// 失败会自动退回运行时编译（行为仍正确，但失去离线预编译收益）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/gate_traits.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gate traits asset: rebuild (GATE_TRAITS_UPDATE=1) or verify', () async {
    final catalog = await Catalog.load();
    final expected = GateTraitsBundle.buildManifest(
      catalog.adviceList,
      catalog.gates.ruleIdSets,
    );

    final file = File(GateTraitsBundle.assetPath);
    final update = Platform.environment['GATE_TRAITS_UPDATE'] == '1';
    if (update) {
      file.writeAsStringSync(jsonEncode(expected));
      // ignore: avoid_print
      print('GATE_TRAITS_UPDATE=1：已重建 gate_traits.json '
          '(${catalog.adviceList.length} 条, sourceHash=${expected['sourceHash']})');
      return;
    }

    expect(
      file.existsSync(),
      isTrue,
      reason: 'assets/data/config/gate_traits.json 不存在——'
          '运行 GATE_TRAITS_UPDATE=1 flutter test test/build_gate_traits_test.dart 生成并入库',
    );
    final stored = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(stored['schemaVersion'], GateTraitsBundle.schemaVersion);
    expect(stored['sourceHash'], expected['sourceHash'],
        reason: '资产与随包数据指纹错位——数据变更后需重建资产');
    expect(stored['adviceCount'], catalog.adviceList.length);
    expect(stored['traits'], expected['traits'],
        reason: '入库 traits 与现算不一致——提取逻辑或数据已漂移');
  });
}
