import 'package:flutter/services.dart';

import '../models/advice.dart';
import 'assets.dart' show decodeJson;
import 'engine_config.dart';

/// 读取画像引导配置原文(decode 即回,分层组装交给调用方)。
Future<Map<String, dynamic>> readOnboardingDoc() async =>
    decodeJson(
      await rootBundle.loadString('assets/data/config/onboarding.json'),
      'config/onboarding',
    );

/// 数据层：L7 配置加载（engines/gates/probes/onboarding/models/gate_traits/pinyin）。
/// 只做 decode → 强类型配置记录；跨文件关联在视图层完成。

EngineConfig loadEngineConfig(Map<String, dynamic> json) =>
    EngineConfig.fromJson(json);

GateConfig loadGateConfig(Map<String, dynamic> json) =>
    GateConfig.fromJson(json);

ProbeContent loadProbeContent(Map<String, dynamic> json) =>
    ProbeContent.fromJson(json);

Map<String, dynamic> loadEmbeddingManifest(Map<String, dynamic> json) =>
    (json['providers'] as Map<String, dynamic>)['embedding'] as Map<String, dynamic>;

Map<String, dynamic>? loadGateTraits(String raw) =>
    raw.isEmpty ? null : (decodeJson(raw, 'config/gate_traits', requireSchemaV1: false));

List<NodePackage> loadNodePackages(Map<String, dynamic> json) =>
    (json['list'] as List).map((e) => NodePackage.fromJson(e as Map<String, dynamic>)).toList();

Map<String, String> loadPinyin(Map<String, dynamic> json) =>
    {for (final e in json.entries) e.key: e.value as String};
