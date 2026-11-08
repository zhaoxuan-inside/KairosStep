/// 数据层：建议动作分解表（entity/advice_action.json）——core/caveat 原子动作。
class ActionRow {
  const ActionRow({required this.id, required this.text});

  final int id;
  final String text;
}

List<ActionRow> loadAdviceActions(Map<String, dynamic> json) {
  final out = <ActionRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(ActionRow(id: row['id'] as int, text: row['text'] as String));
  }
  return out;
}
