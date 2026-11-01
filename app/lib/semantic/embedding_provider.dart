// 语义能力层 Port（REFACTOR_DESIGN §11）：项目内唯一可见的模型抽象。
// 换模型/换推理后端 = 换 Provider 实现 + config/models.json，业务层零改动。
import 'dart:typed_data';

/// 嵌入向量提供者抽象。
abstract class EmbeddingProvider {
  String get modelId;
  String get modelVersion; // 权重指纹（sha256 前 12 位），与 L8 向量强绑定
  int get dimensions;
  bool get isAvailable; // 平台支持 ∧ 资产完整 ∧ 加载成功

  /// 惰性加载：首次搜索才初始化，不拖慢启动。
  Future<void> ensureLoaded();

  /// 单条文本向量化；null = 不可用，调用方走词法兜底。
  Future<Float32List?> embed(String text);

  void dispose();
}
