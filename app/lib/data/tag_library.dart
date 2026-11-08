/// 数据层：标签库（facets/ 三表）——维度定义、标签字典、建议↔标签绑定。
class TagDimensionRow {
  const TagDimensionRow({
    required this.key,
    required this.name,
    required this.multi,
  });

  final String key;
  final String name;
  final bool multi;
}

class TagRow {
  const TagRow({
    required this.tag,
    required this.dimensionKey,
    this.selectable = true,
  });

  final String tag;
  final String dimensionKey;
  final bool selectable;
}

class TagLinkRow {
  const TagLinkRow({required this.id, required this.tag});

  final int id;
  final String tag;
}

List<TagDimensionRow> loadTagDimensions(Map<String, dynamic> json) {
  final out = <TagDimensionRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      TagDimensionRow(
        key: row['key'] as String,
        name: row['name'] as String,
        multi: row['multi'] as bool? ?? true,
      ),
    );
  }
  return out;
}

List<TagRow> loadTags(Map<String, dynamic> json) {
  final out = <TagRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      TagRow(
        tag: row['tag'] as String,
        dimensionKey: row['dimensionKey'] as String,
        selectable: row['selectable'] as bool? ?? true,
      ),
    );
  }
  return out;
}

List<TagLinkRow> loadAdviceTagLinks(Map<String, dynamic> json) {
  final out = <TagLinkRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(TagLinkRow(id: row['id'] as int, tag: row['tag'] as String));
  }
  return out;
}
