/// 数据层：建议内容表（entity/advice_detail.json）——人话版/原文/收益/口径。
class AdviceDetailRow {
  const AdviceDetailRow({
    required this.adviceId,
    required this.humanized,
    required this.cost,
    required this.plain,
    required this.benefit,
    required this.grade,
    required this.notes,
  });

  final int adviceId;
  final String humanized;
  final String? cost;
  final String? plain;
  final String? benefit;
  final String? grade;
  final String? notes;
}

List<AdviceDetailRow> loadAdviceDetails(Map<String, dynamic> json) {
  final out = <AdviceDetailRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      AdviceDetailRow(
        adviceId: row['adviceId'] as int,
        humanized: row['humanized'] as String,
        cost: row['cost'] as String?,
        plain: row['plain'] as String?,
        benefit: row['benefit'] as String?,
        grade: row['grade'] as String?,
        notes: row['notes'] as String?,
      ),
    );
  }
  return out;
}
