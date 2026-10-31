// 步骤 ④ build_display：归并 L0 实体 + L1 维度 + detail.h → L4 展示信息（物化视图）。
// 视图定义：advice ⋈ action ⋈ breadcrumb(taxonomy) ⋈ detail，并做人性化裁剪
//（leadSentence：首句 ≤180 字，与 ui/detail/advice_detail_sheet._lead 同口径）。
import '../common.dart';
import 'normalize.dart';

class DisplayLayer {
  DisplayLayer({required this.rows});
  final List<Map<String, dynamic>> rows;
}

/// 详情页首句截取（逐字对齐 advice_detail_sheet.dart `_lead`：作用于 plain，
/// 第一处 [。！？] 且 ≤180 字符则截首句，否则全文 ≤180 原样、超长返回空串）。
String leadSentence(String? plain) {
  if (plain == null || plain.isEmpty) return '';
  final sentence = RegExp(r'[。！？]').firstMatch(plain);
  if (sentence != null && sentence.end <= 180) {
    return plain.substring(0, sentence.end);
  }
  return plain.length <= 180 ? plain : '';
}

DisplayLayer buildDisplay({
  required Normalized n,
  required Map<int, List<String>> partsByAdvice,
  required Map<int, Map<String, dynamic>> detailByAdvice,
  required Report report,
}) {
  final rows = <Map<String, dynamic>>[];
  for (final advice in n.adviceRows) {
    final id = advice['id'] as int;
    final parts = partsByAdvice[id] ?? const <String>[];
    final badgeText = advice['badgeKey'] as String;
    final path = n.nodeRows
        .where((r) => r['id'] == id)
        .map((r) => r['path'] as String)
        .toList();
    final primaryPath = path.isNotEmpty ? path.first : '';
    final breadcrumb = primaryPath.isEmpty
        ? null
        : breadcrumbOf(n.taxonomy, primaryPath);
    if (breadcrumb == null) {
      report.error('维度路径不存在于 taxonomy：id=$id path=$primaryPath');
    }
    final detail = detailByAdvice[id];
    final humanized = detail?['humanized'] as String? ?? '';

    rows.add({
      'id': id,
      'coreAction': parts.isNotEmpty ? parts.first : '',
      'caveats': parts.length > 1 ? parts.sublist(1) : const <String>[],
      'badgeModel': timingModelKeyOf(badgeText),
      'badgeText': badgeText,
      'breadcrumb': breadcrumb ?? '',
      'humanized': humanized,
      'leadSentence': leadSentence(detail?['plain'] as String?),
    });
  }
  rows.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
  return DisplayLayer(rows: rows);
}

Map<String, String> serializeDisplay(DisplayLayer d) => {
  'views/display_info.json': encodeStable({
    'schemaVersion': schemaVersion,
    'list': d.rows,
  }),
};
