import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/advice_pipeline/common.dart';
import '../tool/advice_pipeline/steps/facets.dart';
import '../tool/advice_pipeline/steps/normalize.dart' show Report;

void main() {
  test('依赖与时效标签归入正确维度，同时保留原始标签顺序', () {
    final source = loadSource('advice');
    final rows = (source['list'] as List).cast<Map<String, dynamic>>();
    final tagsById = {
      for (final row in rows)
        row['id'] as int: (row['tags'] as List).cast<String>(),
    };
    final facets = buildFacets(
      adviceRows: rows,
      rawTagsByAdvice: tagsById,
      report: Report(),
    );
    final dimensionByTag = {
      for (final row in facets.tagRows)
        row['tag'] as String: row['dimensionKey'] as String,
    };
    for (final tag in ['可独立完成', '需医生介入', '需专业人士', '需机构窗口', '需家人配合', '需单位配合']) {
      expect(dimensionByTag[tag], 'reliance', reason: tag);
    }
    for (final tag in ['长期有效', '窗口期', '政策敏感']) {
      expect(dimensionByTag[tag], 'validity', reason: tag);
    }
    for (final row in rows) {
      final id = row['id'] as int;
      final links = facets.adviceTagRows.where((r) => r['id'] == id);
      expect(links.map((r) => r['tag']).toList(), tagsById[id]);
      for (final dimension in ['reliance', 'validity']) {
        expect(
          links.where((r) => dimensionByTag[r['tag']] == dimension).length,
          1,
          reason: '建议 $id 应有一个 $dimension 标注',
        );
      }
    }
    // 验证已发布字典与生成器一致，避免只改词表而忘记重建资产。
    final published = jsonDecode(
      File('assets/data/facets/tag.json').readAsStringSync(),
    );
    expect(published['list'], facets.tagRows);
  });
}
