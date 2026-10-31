// 步骤 ② normalize：源归档 S → L0 规范化实体层（一个文件一个关系，见 REFACTOR_DESIGN §4.9）。
// 源归档只读；本步骤是纯函数：输入决定输出，无全局状态。
import 'dart:io';

import '../common.dart';
import 'resolve_triggers.dart';

/// 全库规范化产物（内存形态，供后续步骤与校验复用）。
class Normalized {
  Normalized({
    required this.adviceRows,
    required this.actionRows,
    required this.detailRows,
    required this.sourceRows,
    required this.relationRows,
    required this.nodeRows,
    required this.badgeRows,
    required this.triggerPlans,
    required this.taxonomy,
    required this.report,
  });

  final List<Map<String, dynamic>> adviceRows;
  final List<Map<String, dynamic>> actionRows;
  final List<Map<String, dynamic>> detailRows;
  final List<Map<String, dynamic>> sourceRows;
  final List<Map<String, dynamic>> relationRows;
  final List<Map<String, dynamic>> nodeRows;
  final List<Map<String, dynamic>> badgeRows;
  final List<Map<String, dynamic>> triggerPlans;
  final Map<String, dynamic> taxonomy;
  final Report report;
}

class Report {
  final List<String> errors = [];
  final List<String> notes = [];

  void error(String msg) => errors.add(msg);
  void note(String msg) => notes.add(msg);

  bool get ok => errors.isEmpty;
}

Normalized normalize({
  required Map<String, dynamic> adviceSrc,
  required Map<String, dynamic> detailSrc,
  required Map<String, dynamic> taxonomy,
  required Report report,
}) {
  final advices = (adviceSrc['list'] as List).cast<Map<String, dynamic>>();
  final details = detailSrc; // 顶层：字符串化 id → 明细对象

  final adviceIds = advices.map((a) => (a['id'] as num).toInt()).toSet();
  final detailIds = details.keys.map(int.parse).toSet();

  // 完整性与参照检查（现存量缺口的显式化）
  for (final missing in detailIds.difference(adviceIds)) {
    report.error('detail.json 存在无对应建议的孤儿明细：id=$missing');
  }
  for (final missing in adviceIds.difference(detailIds)) {
    report.error('advice.json 存在无证据包的建议：id=$missing（需登记为合法缺口或补数据）');
  }

  // ── advice 基表（cron/prerequisites/style 为原始 1:1 字段；badgeKey → badge 字典） ──
  // style：13 种交互形态原始键（作者字段）；Phase 4 的 display_bindings 在其上叠加参数与聚光覆盖。
  final adviceRows = <Map<String, dynamic>>[];
  for (final a in advices) {
    adviceRows.add({
      'id': (a['id'] as num).toInt(),
      'chapterCode': a['c'] as String,
      'title': a['t'] as String,
      'badgeKey': a['timing_badge'] as String? ?? '日常 · 建议',
      'style': a['act_type'] as String? ?? 'quick-checkin',
      'prerequisites': a['prerequisites'] ?? const <String, dynamic>{},
      'cron': a['cron'] as String? ?? '* * * * *',
    });
  }
  adviceRows.sort((x, y) => (x['id'] as int).compareTo(y['id'] as int));

  // ── advice_action 子表（重复组出表，1NF；ordinal 保序） ──
  final actionRows = <Map<String, dynamic>>[];
  for (final a in advices) {
    final id = (a['id'] as num).toInt();
    final parts = ((a['parts'] as List?) ?? const []).cast<String>();
    for (var i = 0; i < parts.length; i++) {
      actionRows.add({
        'id': id,
        'ordinal': i,
        'kind': i == 0 ? 'core' : 'caveat',
        'text': parts[i],
      });
    }
  }
  actionRows.sort((x, y) {
    final byId = (x['id'] as int).compareTo(y['id'] as int);
    return byId != 0 ? byId : (x['ordinal'] as int).compareTo(y['ordinal'] as int);
  });

  // ── advice_detail 1:1 + detail_source 子表 ──
  final detailRows = <Map<String, dynamic>>[];
  final sourceRows = <Map<String, dynamic>>[];
  for (final entry in details.entries) {
    final adviceId = int.parse(entry.key);
    final d = entry.value as Map<String, dynamic>;
    final row = <String, dynamic>{
      'adviceId': adviceId,
      'humanized': d['h'] as String,
      'grade': (d['grade'] as String?) ?? 'C',
    };
    for (final key in ['cost', 'plain', 'benefit', 'notes']) {
      if (d[key] is String && (d[key] as String).isNotEmpty) {
        row[key] = d[key];
      }
    }
    detailRows.add(row);

    final sources = (d['sources'] as List?) ?? const [];
    for (var i = 0; i < sources.length; i++) {
      final pair = (sources[i] as List).cast<String>();
      final sRow = <String, dynamic>{
        'adviceId': adviceId,
        'ordinal': i,
        'name': pair[0],
      };
      if (pair.length > 1) sRow['url'] = pair[1];
      sourceRows.add(sRow);
    }
  }
  int adviceOrder(Map<String, dynamic> r) => r['adviceId'] as int;
  detailRows.sort((a, b) => adviceOrder(a).compareTo(adviceOrder(b)));
  sourceRows.sort((a, b) {
    final byId = adviceOrder(a).compareTo(adviceOrder(b));
    return byId != 0 ? byId : (a['ordinal'] as int).compareTo(b['ordinal'] as int);
  });

  // ── advice_relation 联结表（detail.rel → kind: related；保序） ──
  final relationRows = <Map<String, dynamic>>[];
  for (final entry in details.entries) {
    final fromId = int.parse(entry.key);
    final rel = ((entry.value as Map<String, dynamic>)['rel'] as List?) ?? const [];
    for (var i = 0; i < rel.length; i++) {
      relationRows.add({
        'fromId': fromId,
        'toId': (rel[i] as num).toInt(),
        'kind': 'related',
        'ordinal': i,
      });
    }
  }
  relationRows.sort((a, b) {
    final byFrom = (a['fromId'] as int).compareTo(b['fromId'] as int);
    if (byFrom != 0) return byFrom;
    return (a['ordinal'] as int).compareTo(b['ordinal'] as int);
  });
  // 已登记缺口的孤儿行保留但显式标记（运行时行为不变：rel 列表原样，UI 对缺失 id 空安全）；
  // 未登记的孤儿才是错误。
  for (final r in relationRows) {
    if (!adviceIds.contains(r['toId'])) {
      final known = knownRelationOrphans[r['fromId']]?.contains(r['toId']) ?? false;
      if (known) {
        r['status'] = 'known_gap';
        report.note('已登记的关联缺口（保留并标记 known_gap）：${r['fromId']} → ${r['toId']}');
      } else {
        report.error('relation 孤儿外键：${r['fromId']} → ${r['toId']} 不存在（如属库内缺口请登记 knownRelationOrphans）');
      }
    }
  }

  // ── advice_node 联结表（多重挂载；tree_display 冗余自此消除，由维度树重算） ──
  final nodeRows = <Map<String, dynamic>>[];
  for (final a in advices) {
    final id = (a['id'] as num).toInt();
    final paths = ((a['tree_paths'] as List?) ?? const []).cast<String>();
    final treePath = a['tree_path'] as String?;
    final effective = paths.isNotEmpty
        ? paths
        : (treePath != null ? [treePath] : const <String>[]);
    if (effective.isEmpty) {
      report.error('建议无维度挂载：id=$id');
      continue;
    }
    if (paths.isNotEmpty && treePath != null && paths.first != treePath) {
      report.error('tree_path 与 tree_paths[0] 不一致：id=$id（$treePath vs ${paths.first}）');
    }
    for (var i = 0; i < effective.length; i++) {
      nodeRows.add({'id': id, 'ordinal': i, 'path': effective[i]});
    }
  }
  nodeRows.sort((a, b) {
    final byId = (a['id'] as int).compareTo(b['id'] as int);
    return byId != 0 ? byId : (a['ordinal'] as int).compareTo(b['ordinal'] as int);
  });

  // ── badge 字典（51 种去重；modelKey 复刻 TimingModel.of） ──
  final badges = <String>{};
  for (final a in advices) {
    badges.add(a['timing_badge'] as String? ?? '日常 · 建议');
  }
  final badgeRows = [
    for (final text in badges.toList()..sort())
      {'text': text, 'modelKey': timingModelKeyOf(text)},
  ];

  // ── L6 触发计划（复刻 effectiveTriggerOf，等价性由测试证明） ──
  final triggerPlans = buildTriggerPlans(advices);

  return Normalized(
    adviceRows: adviceRows,
    actionRows: actionRows,
    detailRows: detailRows,
    sourceRows: sourceRows,
    relationRows: relationRows,
    nodeRows: nodeRows,
    badgeRows: badgeRows,
    triggerPlans: triggerPlans,
    taxonomy: taxonomy,
    report: report,
  );
}

/// 维度树路径 → 面包屑（由 taxonomy 重算，替代 tree_display 冗余）。
/// 结构：首层为域键（health/daily/...），深层节点挂在上一层的 `sub` 键下。
/// 返回 null 表示路径不存在。
String? breadcrumbOf(Map<String, dynamic> taxonomy, String path) {
  final segments = path.split('/');
  final names = <String>[];
  Map<String, dynamic> level = taxonomy;
  for (final seg in segments) {
    final next = level[seg];
    if (next is! Map<String, dynamic>) return null;
    names.add(next['name'] as String);
    final sub = next['sub'];
    level = sub is Map<String, dynamic> ? sub : const <String, dynamic>{};
  }
  return names.join(' > ');
}

/// 汇总写盘（serialize 顺序即键序，保证 byte 级幂等）。
Map<String, String> serializeLayers(Normalized n) {
  final files = <String, String>{};
  String json(Object data) => encodeStable(data);

  files['entity/advice.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.adviceRows,
  });
  files['entity/advice_action.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.actionRows,
  });
  files['entity/advice_detail.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.detailRows,
  });
  files['entity/detail_source.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.sourceRows,
  });
  files['entity/advice_relation.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.relationRows,
  });
  files['entity/advice_node.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.nodeRows,
  });
  files['dimensions/badge.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.badgeRows,
  });
  files['triggers/advice_trigger.json'] = json({
    'schemaVersion': schemaVersion,
    'list': n.triggerPlans,
  });
  return files;
}

/// taxonomy 原样拷贝（字节级，不重编码）。
String taxonomyRaw() =>
    File('$srcDir/taxonomy_tree.json').readAsStringSync();
