// L8 语义向量层（REFACTOR_DESIGN §11.5）：库向量加载 + modelVersion 绑定校验 + 暴力余弦。
// 737 条规模无需 ANN 索引；FP16 存储（half-float 编解码内置），模型不可用即整层降级。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

class VectorStore {
  VectorStore._(this.modelId, this.modelVersion, this.dimensions, this._vectors);

  final String modelId;
  final String modelVersion;
  final int dimensions;
  final Map<int, Float32List> _vectors;

  bool get isEmpty => _vectors.isEmpty;

  /// 加载 L8；[expectVersion] 不匹配（模型-向量错位）→ 返回空层（调用方降级词法）。
  static Future<VectorStore> load(String expectVersion) async {
    try {
      final raw = await rootBundle.loadString('assets/data/semantic/doc_vectors.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // ignore: unnecessary_this
      if (json['schemaVersion'] != 1) return _empty();
      final version = json['modelVersion'] as String;
      if (expectVersion.isNotEmpty && version != expectVersion) return _empty();
      final dims = (json['dimensions'] as num).toInt();
      final vectors = <int, Float32List>{};
      for (final e in (json['list'] as List).cast<Map<String, dynamic>>()) {
        vectors[(e['id'] as num).toInt()] = _fromHalfBase64(
          e['vector'] as String,
          dims,
        );
      }
      return VectorStore._(
        json['modelId'] as String,
        version,
        dims,
        vectors,
      );
    } catch (_) {
      return _empty();
    }
  }

  static VectorStore _empty() => VectorStore._('none', 'none', 0, {});

  /// 暴力余弦检索（向量已归一化 → 点积即余弦）；floor 以下丢弃。
  List<(int, double)> search(Float32List query, {int topK = 20, double floor = 0.35}) {
    if (query.isEmpty || _vectors.isEmpty) return const [];
    final hits = <(int, double)>[];
    _vectors.forEach((id, v) {
      var dot = 0.0;
      for (var i = 0; i < v.length; i++) {
        dot += query[i] * v[i];
      }
      if (dot >= floor) hits.add((id, dot));
    });
    hits.sort((a, b) => b.$2.compareTo(a.$2));
    return hits.take(topK).toList();
  }

  /// 测试/流水线用：内存构造。
  static VectorStore loadForTest(String version, int dims, List<Map<String, dynamic>> rows) =>
      VectorStore._('bge-small-zh-v1.5-int8', version, dims, {
        for (final r in rows)
          (r['id'] as num).toInt(): _fromHalfBase64(r['vector'] as String, dims),
      });

  // ── FP16 ↔ base64 ──

  static String _toHalfBase64(Float32List v) {
    final half = Uint16List(v.length);
    final bits = v.buffer.asUint32List();
    for (var i = 0; i < v.length; i++) {
      half[i] = _f32ToF16(bits[i]);
    }
    return base64.encode(half.buffer.asUint8List());
  }

  static Float32List _fromHalfBase64(String b64, int len) {
    final bytes = base64.decode(b64);
    final half = Uint16List.view(bytes.buffer, bytes.offsetInBytes, len);
    final out = Float32List(len);
    for (var i = 0; i < len; i++) {
      out[i] = _f16ToF32(half[i]);
    }
    return out;
  }

  static int _f32ToF16(int f32bits) {
    final sign = (f32bits >> 16) & 0x8000;
    var exp = ((f32bits >> 23) & 0xFF) - 127 + 15;
    var mant = f32bits & 0x007FFFFF;
    if (exp <= 0) return sign;
    if (exp >= 31) return sign | 0x7C00;
    return sign | (exp << 10) | (mant >> 13);
  }

  static double _f16ToF32(int h) {
    final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
    final exp = (h >> 10) & 0x1F;
    final mant = h & 0x3FF;
    if (exp == 0) return sign * mant * _pow2(-24);
    if (exp == 31) return sign * double.infinity;
    return sign * (1 + mant / 1024) * _pow2(exp - 15);
  }

  static double _pow2(int e) {
    var r = 1.0;
    for (var i = 0; i < e.abs(); i++) {
      r *= 2;
    }
    return e < 0 ? 1 / r : r;
  }

  /// 供流水线写入用：向量 → FP16 base64。
  static String encodeVector(Float32List v) => _toHalfBase64(v);
}
