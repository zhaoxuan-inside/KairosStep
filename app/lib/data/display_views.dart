/// 数据层：建议总结/展示视图（views/display_info.json）——
/// 核心动作、附带提醒、面包屑与一句导语。
class DisplayViewRow {
  const DisplayViewRow({
    required this.id,
    required this.coreAction,
    required this.caveats,
    required this.badgeModel,
    required this.badgeText,
    required this.breadcrumb,
    required this.humanized,
    required this.leadSentence,
  });

  final int id;
  final String coreAction;
  final List<String> caveats;
  final String badgeModel;
  final String badgeText;
  final String breadcrumb;
  final String humanized;
  final String leadSentence;
}

List<DisplayViewRow> loadDisplayViews(Map<String, dynamic> json) {
  final out = <DisplayViewRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      DisplayViewRow(
        id: row['id'] as int,
        coreAction: row['coreAction'] as String,
        caveats: (row['caveats'] as List?)?.cast<String>() ?? const [],
        badgeModel: row['badgeModel'] as String,
        badgeText: row['badgeText'] as String,
        breadcrumb: row['breadcrumb'] as String,
        humanized: row['humanized'] as String? ?? '',
        leadSentence: row['leadSentence'] as String? ?? '',
      ),
    );
  }
  return out;
}
