/// 数据层：建议出处表（entity/detail_source.json）——文献名与链接。
class SourceRow {
  const SourceRow({required this.adviceId, required this.name, this.url});

  final int adviceId;
  final String name;
  final String? url;
}

List<SourceRow> loadDetailSources(Map<String, dynamic> json) {
  final out = <SourceRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      SourceRow(
        adviceId: row['adviceId'] as int,
        name: row['name'] as String,
        url: row['url'] as String?,
      ),
    );
  }
  return out;
}
