/// 数据层：建议树路径表（entity/advice_node.json）——主题树叶子挂载。
class NodePathRow {
  const NodePathRow({required this.id, required this.path});

  final int id;
  final String path;
}

List<NodePathRow> loadAdviceNodes(Map<String, dynamic> json) {
  final out = <NodePathRow>[];
  for (final row in (json['list'] as List).cast<Map<String, dynamic>>()) {
    out.add(NodePathRow(id: row['id'] as int, path: row['path'] as String));
  }
  return out;
}
