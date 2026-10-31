// 步骤 ⑦ validate：参照完整性 + 域约束 + 计数校验（等价 DB 的 FK / CHECK / NOT NULL）。
import '../common.dart';
import 'normalize.dart';

/// 对规范化内存结构执行全部约束检查，错误写入 report（调用方据 report.ok 决定退出码）。
void validateLayers({
  required Normalized n,
  required Map<int, List<String>> partsByAdvice,
  required Map<int, String> rawDisplayByAdvice,
  required Report report,
}) {
  final adviceIds = n.adviceRows.map((r) => r['id'] as int).toSet();

  // 计数断言
  if (n.adviceRows.length != 737) {
    report.error('建议基表条数 ${n.adviceRows.length} ≠ 737');
  }
  if (n.detailRows.length != n.adviceRows.length) {
    report.error('明细 ${n.detailRows.length} 条 ≠ 基表 ${n.adviceRows.length} 条');
  }

  // NOT NULL / 域约束
  final grades = {'A', 'B', 'C'};
  for (final d in n.detailRows) {
    if (!grades.contains(d['grade'])) {
      report.error('证据等级越域：id=${d['adviceId']} grade=${d['grade']}');
    }
  }
  final cronRe = RegExp(r'^(\S+ ){4}\S+$');
  for (final a in n.adviceRows) {
    final cron = a['cron'] as String;
    if (!cronRe.hasMatch(cron)) {
      report.error('cron 非五段式：id=${a['id']} cron="$cron"');
    }
    final prereq = a['prerequisites'] as Map<String, dynamic>;
    for (final key in prereq.keys) {
      if (!prerequisiteKeys.contains(key)) {
        report.error('prerequisites 未知画像键：id=${a['id']} key=$key');
      }
      final v = prereq[key];
      if (key == 'min_age' && v is! num) {
        report.error('min_age 必须为数值：id=${a['id']} value=$v');
      } else if (key != 'min_age' && v is! bool) {
        report.error('布尔画像键异常：id=${a['id']} key=$key value=$v');
      }
    }
  }

  // badge 字典覆盖 + 唯一性
  final badgeTexts = n.badgeRows.map((r) => r['text'] as String).toSet();
  for (final a in n.adviceRows) {
    if (!badgeTexts.contains(a['badgeKey'])) {
      report.error('badge 字典缺项：${a['badgeKey']}');
    }
  }

  // action 覆盖：每条建议至少一个 core（parts 为空属数据缺陷）
  for (final advice in n.adviceRows) {
    final parts = partsByAdvice[advice['id'] as int] ?? const <String>[];
    if (parts.isEmpty) {
      report.error('建议无原子动作拆解：id=${advice['id']}');
    }
  }

  // node 覆盖：每条建议 ≥1 挂载，路径必须是 taxonomy 叶子
  final leafPaths = _leafPaths(n.taxonomy);
  for (final node in n.nodeRows) {
    final path = node['path'] as String;
    if (!leafPaths.contains(path)) {
      report.error('维度挂载路径不是叶子：id=${node['id']} path=$path');
    }
  }
  final mountedIds = n.nodeRows.map((r) => r['id'] as int).toSet();
  for (final id in adviceIds.difference(mountedIds)) {
    report.error('建议无维度挂载：id=$id');
  }

  // breadcrumb 重算 == 原 tree_display（反规范化消除的前置证明）
  final primaryPathByAdvice = <int, String>{};
  for (final node in n.nodeRows) {
    if ((node['ordinal'] as int) == 0) {
      primaryPathByAdvice[node['id'] as int] = node['path'] as String;
    }
  }
  var checked = 0;
  for (final e in rawDisplayByAdvice.entries) {
    final path = primaryPathByAdvice[e.key];
    if (path == null) continue;
    final recomputed = breadcrumbOf(n.taxonomy, path);
    if (recomputed != e.value) {
      report.error(
        '面包屑重算不一致：id=${e.key}\n  重算: $recomputed\n  原值: ${e.value}',
      );
    }
    checked++;
  }
  report.note('breadcrumb 校验 $checked 条');
}

Set<String> _leafPaths(Map<String, dynamic> node, [String prefix = '']) {
  final leaves = <String>{};
  node.forEach((key, value) {
    if (value is! Map<String, dynamic>) return;
    final path = prefix.isEmpty ? key : '$prefix/$key';
    final sub = value['sub'];
    if (sub is Map<String, dynamic> && sub.isNotEmpty) {
      leaves.addAll(_leafPaths(sub, path));
    } else {
      leaves.add(path);
    }
  });
  return leaves;
}
