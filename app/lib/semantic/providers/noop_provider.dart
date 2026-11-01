// 降级空实现（Fail-safe）：模型不可用/平台不支持时的安全兜底。
import 'dart:typed_data';

import '../embedding_provider.dart';

class NoopProvider implements EmbeddingProvider {
  const NoopProvider();

  @override
  String get modelId => 'noop';
  @override
  String get modelVersion => 'none';
  @override
  int get dimensions => 0;
  @override
  bool get isAvailable => false;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<Float32List?> embed(String text) async => null;
  @override
  void dispose() {}
}
