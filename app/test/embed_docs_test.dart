// L8 生成工具（Phase 5）：用端侧同款 ONNX 模型离线计算 737 条库向量 →
// assets/data/semantic/doc_vectors.json（FP16 存储）。
// 用法：EMBED_UPDATE=1 flutter test test/embed_docs_test.dart
// 与 SentenceTransformers（Python）产物同空间：同一模型权重 + 同一分词。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/semantic/providers/bge_provider.dart';
import 'package:kairo_step/semantic/vector_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('embed docs → L8 doc_vectors.json', () async {
    final catalog = await Catalog.load();
    final manifest =
        (jsonDecode(await rootBundle.loadString('assets/data/config/models.json'))
                as Map<String, dynamic>)['providers']['embedding']
            as Map<String, dynamic>;
    final provider = BgeProvider(manifest);
    await provider.ensureLoaded();
    expect(provider.isAvailable, isTrue,
        reason: 'BGE ONNX 会话加载失败：${provider.lastError}');

    final update = Platform.environment['EMBED_UPDATE'] == '1';
    final vectors = <Map<String, dynamic>>[];
    for (final a in catalog.adviceList) {
      final text = [
        a.coreAction,
        ...a.caveats,
        if (catalog.details[a.id] case final d?) d.humanized,
      ].where((s) => s.isNotEmpty).join('。');
      final v = await provider.embed(text);
      expect(v, isNotNull, reason: '向量计算失败 @${a.id}');
      vectors.add({'id': a.id, 'vector': VectorStore.encodeVector(v!)});
    }

    final doc = jsonEncode({
      'schemaVersion': 1,
      'modelId': provider.modelId,
      'modelVersion': provider.modelVersion,
      'dimensions': provider.dimensions,
      'pooling': 'cls',
      'list': vectors,
    });

    // 自检：写盘前用向量库做一次语义 sanity check
    final store = VectorStore.loadForTest(provider.modelVersion, provider.dimensions, vectors);
    final q = await provider.embed('${manifest['queryPrefix']}系安全带');
    expect(q, isNotNull);
    final hits = store.search(q!, topK: 3, floor: 0.0);
    expect(hits.first.$1, 1, reason: '「系安全带」的最近邻应为建议 1（语义自检）');

    final f = File('assets/data/semantic/doc_vectors.json');
    if (update) {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(doc);
      // ignore: avoid_print
      print('已生成 L8：${vectors.length} 条 × ${provider.dimensions} 维 → ${f.path}');
    } else {
      expect(f.existsSync(), isTrue, reason: 'L8 尚未生成（EMBED_UPDATE=1 重建）');
      final onDisk = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      expect(onDisk['modelVersion'], provider.modelVersion,
          reason: 'L8 与模型版本错位：需 EMBED_UPDATE=1 重算');
    }
    provider.dispose();
  });
}
