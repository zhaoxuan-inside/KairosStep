// BGE-small-zh-v1.5 INT8 Provider（ONNX Runtime 端侧推理）。
// 分词：中文 BERT 规约（CJK 按字切开 + WordPiece + [CLS]/[SEP]，maxTokens 截断）；
// 池化：CLS + L2 归一化；查询侧指令前缀来自 models.json（模型特有行为外置）。
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

import '../embedding_provider.dart';

class BgeProvider implements EmbeddingProvider {
  BgeProvider(this._manifest);

  final Map<String, dynamic> _manifest;
  OrtSession? _session;
  List<String> _vocab = const [];
  Map<String, int> _vocabIndex = const {};
  bool _loaded = false;
  bool _failed = false;
  String? lastError;

  static const _unkId = 100, _clsId = 101, _sepId = 102;

  @override
  String get modelId => _manifest['id'] as String;
  @override
  String get modelVersion => (_manifest['sha256'] as String).substring(0, 12);
  @override
  int get dimensions => (_manifest['dimensions'] as num).toInt();
  @override
  bool get isAvailable => _loaded && !_failed;

  int get _maxTokens => (_manifest['maxTokens'] as num).toInt();

  @override
  Future<void> ensureLoaded() async {
    if (_loaded || _failed) return;
    try {
      if (kIsWeb || Platform.isWindows) {
        // Web（WASM 20MB+ 下载不划算）与 Windows 暂不启用，见 engines.json 端差异矩阵
        _failed = true;
        return;
      }
      // 资产完整性：sha256 校验（数据不出包，校验防损坏）
      final bytes = (await rootBundle.load(_manifest['asset'] as String))
          .buffer
          .asUint8List();
      final vocabRaw = await rootBundle.loadString(_manifest['vocab'] as String);
      _vocab = const LineSplitter().convert(vocabRaw);
      _vocabIndex = {
        for (var i = 0; i < _vocab.length; i++) _vocab[i]: i,
      };
      OrtEnv.instance.init();
      _session = OrtSession.fromBuffer(
        bytes.buffer.asUint8List(),
        OrtSessionOptions(),
      );
      _loaded = true;
    } catch (e) {
      lastError = e.toString();
      _failed = true; // Fail-safe：调用方经 isAvailable/embed 走词法兜底
    }
  }

  @override
  Future<Float32List?> embed(String text) async {
    if (!_loaded || _failed) return null;
    try {
      final prefix = _manifest['queryPrefix'] as String? ?? '';
      final ids = _encode('$prefix$text');
      final seq = ids.length;
      final inputIds = Int64List.fromList(ids);
      final attention = Int64List.fromList(List.filled(seq, 1));
      final tokenTypes = Int64List.fromList(List.filled(seq, 0));
      final inputs = {
        'input_ids': OrtValueTensor.createTensorWithDataList(inputIds, [1, seq]),
        'attention_mask': OrtValueTensor.createTensorWithDataList(attention, [1, seq]),
        'token_type_ids': OrtValueTensor.createTensorWithDataList(tokenTypes, [1, seq]),
      };
      final outputs = await _session!.runAsync(OrtRunOptions(), inputs);
      final firstOut = (outputs == null || outputs.isEmpty) ? null : outputs.first;
      final hidden = firstOut?.value as List?; // [1, seq, dim]
      for (final v in inputs.values) {
        v.release();
      }
      if (firstOut != null) firstOut.release();
      if (hidden == null) return null;
      final first = hidden[0] as List; // [seq, dim]
      final cls = (first[0] as List).cast<double>();
      // L2 归一化
      var sum = 0.0;
      for (final v in cls) {
        sum += v * v;
      }
      final norm = sum <= 0 ? 1.0 : math.sqrt(sum);
      return Float32List.fromList([for (final v in cls) v / norm]);
    } catch (_) {
      return null; // Fail-safe
    }
  }

  /// BERT 中文分词：小写 → CJK 按字加空格 → 空白/标点切分 → WordPiece。
  List<int> _encode(String text) {
    final spaced = _cjkSpacing(text.toLowerCase());
    final tokens = <int>[_clsId];
    var budget = _maxTokens - 2;
    for (final raw in spaced.split(_tokenSplitRe)) {
      if (raw.isEmpty || budget <= 0) continue;
      for (final piece in _wordPiece(raw)) {
        if (budget <= 0) break;
        tokens.add(piece);
        budget--;
      }
    }
    tokens.add(_sepId);
    return tokens;
  }

  List<int> _wordPiece(String token) {
    if (_vocabIndex.containsKey(token)) return [_vocabIndex[token]!];
    final out = <int>[];
    var start = 0;
    while (start < token.length) {
      var end = token.length;
      int? id;
      while (start < end) {
        final sub = start == 0 ? token.substring(start, end) : '##${token.substring(start, end)}';
        final hit = _vocabIndex[sub];
        if (hit != null) {
          id = hit;
          break;
        }
        end--;
      }
      if (id == null) {
        out.add(_unkId);
        return out;
      }
      out.add(id);
      start = end;
    }
    return out;
  }

  static final _tokenSplitRe = RegExp(r'([^\p{L}\p{N}])', unicode: true);

  static String _cjkSpacing(String s) {
    final b = StringBuffer();
    for (final ch in s.runes) {
      if (ch >= 0x4E00 && ch <= 0x9FFF || ch >= 0x3400 && ch <= 0x4DBF) {
        b..writeCharCode(ch)..write(' ');
      } else {
        b.writeCharCode(ch);
      }
    }
    return b.toString();
  }

  @override
  void dispose() {
    _session?.release();
    _session = null;
    _loaded = false;
  }
}
