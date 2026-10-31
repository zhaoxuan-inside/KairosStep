// 步骤 ③ build_facets：tags → L3 受控维度词表 + 保序联结表。
// 存储形态：facets/advice_tag.json 以 (id, ordinal, tag) 逐行保序——运行时按 id+ordinal
// 还原出与源数据 byte 级一致的 tags 列表；维度归类是附加视图，不改变原始顺序。
import '../common.dart';
import 'normalize.dart';

class Facets {
  Facets({
    required this.dimensionRows,
    required this.tagRows,
    required this.adviceTagRows,
  });

  final List<Map<String, dynamic>> dimensionRows;
  final List<Map<String, dynamic>> tagRows;
  final List<Map<String, dynamic>> adviceTagRows;
}

Facets buildFacets({
  required List<Map<String, dynamic>> adviceRows,
  required Map<int, List<String>> rawTagsByAdvice,
  required Report report,
}) {
  // 1. 词表文件（受控维度）
  final dimensionRows = <Map<String, dynamic>>[
    for (final (key, name, multi) in tagDimensionDefs)
      {
        'key': key,
        'name': name,
        'multi': multi,
        if (key == 'theme') 'open': true,
      },
  ];

  // 2. 全库去重标签 → 维度归类（未命中受控清单 → theme 开放维度，并上报清单）
  final allTags = <String>{};
  rawTagsByAdvice.forEach((_, tags) => allTags.addAll(tags));

  final tagRows = <Map<String, dynamic>>[];
  final unclassified = <String>[];
  for (final tag in allTags.toList()..sort()) {
    String? dim;
    for (final e in controlledVocabulary.entries) {
      if (e.value.contains(tag)) {
        dim = e.key;
        break;
      }
    }
    if (dim == null) {
      dim = 'theme';
      unclassified.add(tag);
    }
    tagRows.add({'tag': tag, 'dimensionKey': dim});
  }
  if (unclassified.isNotEmpty) {
    report.note(
      '归入 theme（开放维度）的标签 ${unclassified.length} 个：${unclassified.join('、')}',
    );
  }

  // 3. 保序联结表
  final adviceTagRows = <Map<String, dynamic>>[];
  for (final row in adviceRows) {
    final id = row['id'] as int;
    final tags = rawTagsByAdvice[id] ?? const <String>[];
    for (var i = 0; i < tags.length; i++) {
      adviceTagRows.add({'id': id, 'ordinal': i, 'tag': tags[i]});
    }
  }
  adviceTagRows.sort((a, b) {
    final byId = (a['id'] as int).compareTo(b['id'] as int);
    return byId != 0 ? byId : (a['ordinal'] as int).compareTo(b['ordinal'] as int);
  });

  return Facets(
    dimensionRows: dimensionRows,
    tagRows: tagRows,
    adviceTagRows: adviceTagRows,
  );
}

Map<String, String> serializeFacets(Facets f) => {
  'facets/tag_dimension.json': encodeStable({
    'schemaVersion': schemaVersion,
    'list': f.dimensionRows,
  }),
  'facets/tag.json': encodeStable({
    'schemaVersion': schemaVersion,
    'list': f.tagRows,
  }),
  'facets/advice_tag.json': encodeStable({
    'schemaVersion': schemaVersion,
    'list': f.adviceTagRows,
  }),
};
