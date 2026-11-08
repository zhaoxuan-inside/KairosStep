/// 数据层：原始建议表（entity/advice.json）——标题/章节/样式/前置/时刻。
class AdviceEntityRow {
  const AdviceEntityRow({
    required this.id,
    required this.chapterCode,
    required this.title,
    required this.badgeKey,
    required this.style,
    required this.prerequisites,
    required this.cron,
  });

  final int id;
  final String chapterCode;
  final String title;
  final String badgeKey;
  final String style;
  final Map<String, dynamic> prerequisites;
  final String cron;
}

List<AdviceEntityRow> loadAdviceEntities(Map<String, dynamic> json) {
  final out = <AdviceEntityRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      AdviceEntityRow(
        id: row['id'] as int,
        chapterCode: row['chapterCode'] as String,
        title: row['title'] as String,
        badgeKey: row['badgeKey'] as String,
        style: row['style'] as String,
        prerequisites:
            (row['prerequisites'] as Map<String, dynamic>?) ?? const {},
        cron: row['cron'] as String,
      ),
    );
  }
  return out;
}
