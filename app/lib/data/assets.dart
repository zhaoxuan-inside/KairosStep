import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 数据层：资产字符串读取与 JSON 解码（仅 IO + decode，不做任何跨文件关联）。
class RawAssets {
  const RawAssets({
    required this.adviceBase,
    required this.action,
    required this.tagRows,
    required this.detail,
    required this.source,
    required this.relation,
    required this.node,
    required this.taxonomy,
    required this.engines,
    required this.gates,
    required this.probes,
    required this.actStyles,
    required this.displayBindings,
    required this.models,
    required this.onboarding,
    required this.gateTraits,
    required this.nodePkg,
    required this.pinyin,
    this.classification = '',
  });

  final String adviceBase;
  final String action;
  final String tagRows;
  final String detail;
  final String source;
  final String relation;
  final String node;
  final String taxonomy;
  final String engines;
  final String gates;
  final String probes;
  final String actStyles;
  final String displayBindings;
  final String models;
  final String onboarding;

  /// gate_traits 缺失时为空串（装配端转 null 走运行时兜底编译）。
  final String gateTraits;
  final String nodePkg;
  final String pinyin;
  final String classification;
}

/// 主 isolate 读取资产字符串（平台通道）；解码交给调用方（可入后台 isolate）。
Future<RawAssets> readRawAssets() async {
  Future<String> raw(String name) =>
      rootBundle.loadString('assets/data/$name.json');

  return RawAssets(
    adviceBase: await raw('entity/advice'),
    action: await raw('entity/advice_action'),
    tagRows: await raw('facets/advice_tag'),
    detail: await raw('entity/advice_detail'),
    source: await raw('entity/detail_source'),
    relation: await raw('entity/advice_relation'),
    node: await raw('entity/advice_node'),
    taxonomy: await raw('dimensions/taxonomy'),
    engines: await raw('config/engines'),
    gates: await raw('config/gates'),
    probes: await raw('config/probes'),
    actStyles: await raw('styles/act_styles'),
    displayBindings: await raw('styles/display_bindings'),
    models: await raw('config/models'),
    onboarding: await raw('config/onboarding'),
    // L8 门禁谓词预编译资产（离线生成，见 test/build_gate_traits_test.dart）：
    // 缺失/损坏不阻断启动——GatekeeperEngine 按指纹校验失败自动兜底编译。
    gateTraits: await raw('config/gate_traits').catchError((_) => ''),
    nodePkg: await raw('node_packages'),
    pinyin: await raw('pinyin'),
    classification: await raw('views/advice_classification'),
  );
}

/// 解码单个资产文件并校验 schemaVersion。
Map<String, dynamic> decodeJson(
  String raw,
  String name, {
  bool requireSchemaV1 = true,
}) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  if (requireSchemaV1 && json['schemaVersion'] != 1) {
    throw FormatException('$name schemaVersion 异常：${json['schemaVersion']}');
  }
  return json;
}

/// FLUTTER_TEST 由 flutter test 注入（dart:io 仅限非 Web 路径可达）。
bool get isFlutterTest {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}
