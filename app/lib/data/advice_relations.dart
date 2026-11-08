/// 数据层：建议关联表（entity/advice_relation.json）——related 互链与
/// merge_candidate 归并候选（weight 双向）。
class RelationRow {
  const RelationRow({
    required this.fromId,
    required this.toId,
    required this.kind,
    this.weight,
  });

  final int fromId;
  final int toId;
  final String kind;
  final num? weight;
}

List<RelationRow> loadAdviceRelations(Map<String, dynamic> json) {
  final out = <RelationRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(
      RelationRow(
        fromId: row['fromId'] as int,
        toId: row['toId'] as int,
        kind: row['kind'] as String,
        weight: row['weight'] as num?,
      ),
    );
  }
  return out;
}
