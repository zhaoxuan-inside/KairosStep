// 建议数据流水线入口。
// 用法（在 app/ 目录下）：
//   dart run tool/advice_pipeline/build.dart            // 全量生成 + 校验 + 报告
//   dart run tool/advice_pipeline/build.dart --check    // 幂等校验：磁盘文件必须与重算结果一致
//
// 输入：data-src/{advice,detail,taxonomy_tree}.json（源归档 S，只增不改）
// 输出：assets/data/{entity,dimensions,facets,views,triggers}/*.json（L0-L6，随包发布）
import 'dart:io';

import 'common.dart';
import 'steps/display.dart';
import 'steps/facets.dart';
import 'steps/normalize.dart';
import 'steps/validate.dart';

void main(List<String> args) {
  final checkOnly = args.contains('--check');

  final report = Report();

  // ── 读源 ──
  final adviceSrc = loadSource('advice');
  final detailSrc = loadSource('detail');
  final taxonomy = loadSource('taxonomy_tree');

  final advices = (adviceSrc['list'] as List).cast<Map<String, dynamic>>();
  final details = detailSrc.cast<String, Map<String, dynamic>>();

  final rawTagsByAdvice = <int, List<String>>{};
  final partsByAdvice = <int, List<String>>{};
  final rawDisplayByAdvice = <int, String>{};
  for (final a in advices) {
    final id = (a['id'] as num).toInt();
    rawTagsByAdvice[id] = ((a['tags'] as List?) ?? const []).cast<String>();
    partsByAdvice[id] = ((a['parts'] as List?) ?? const []).cast<String>();
    if (a['tree_display'] is String) {
      rawDisplayByAdvice[id] = a['tree_display'] as String;
    }
  }
  final detailByAdvice = <int, Map<String, dynamic>>{
    for (final e in details.entries) int.parse(e.key): e.value,
  };

  // ── 步骤 ──
  final n = normalize(
    adviceSrc: adviceSrc,
    detailSrc: detailSrc,
    taxonomy: taxonomy,
    report: report,
  );
  final facets = buildFacets(
    adviceRows: n.adviceRows,
    rawTagsByAdvice: rawTagsByAdvice,
    report: report,
  );
  final display = buildDisplay(
    n: n,
    partsByAdvice: partsByAdvice,
    detailByAdvice: detailByAdvice,
    report: report,
  );
  validateLayers(
    n: n,
    partsByAdvice: partsByAdvice,
    rawDisplayByAdvice: rawDisplayByAdvice,
    report: report,
  );

  // ── 序列化 ──
  final files = serializeLayers(n);
  files.addAll(serializeFacets(facets));
  files.addAll(serializeDisplay(display));
  // taxonomy 原样拷贝（字节级不重编码）
  files['dimensions/taxonomy.json'] = taxonomyRaw();

  // 报告
  // ignore: avoid_print
  print('── advice_pipeline 报告 ──');
  // ignore: avoid_print
  print('建议 ${n.adviceRows.length} 条；明细 ${n.detailRows.length} 条；'
      '动作 ${n.actionRows.length} 行；挂载 ${n.nodeRows.length} 行；'
      '标签 ${facets.tagRows.length} 种 / ${facets.adviceTagRows.length} 行；'
      '徽章 ${n.badgeRows.length} 种；关联 ${n.relationRows.length} 行；'
      '触发计划 ${n.triggerPlans.length} 条');
  final modes = <String, int>{};
  for (final p in n.triggerPlans) {
    modes[p['mode'] as String] = (modes[p['mode'] as String] ?? 0) + 1;
  }
  // ignore: avoid_print
  print('触发模式分布: $modes');
  for (final note in report.notes) {
    // ignore: avoid_print
    print('note: $note');
  }

  if (checkOnly) {
    var dirty = 0;
    files.forEach((rel, content) {
      final f = File('$outDir/$rel');
      if (!f.existsSync()) {
        // ignore: avoid_print
        print('CHECK 失败：缺失 $rel');
        dirty++;
        return;
      }
      if (f.readAsStringSync() != content) {
        // ignore: avoid_print
        print('CHECK 失败：内容漂移 $rel');
        dirty++;
      }
    });
    // ignore: avoid_print
    print(dirty == 0 ? 'CHECK 通过：磁盘数据与流水线一致（幂等）' : 'CHECK 失败：$dirty 个文件漂移');
    if (dirty > 0 || !report.ok) exitCode = 1;
    return;
  }

  if (!report.ok) {
    for (final e in report.errors) {
      // ignore: avoid_print
      print('ERROR: $e');
    }
    // ignore: avoid_print
    print('校验失败：${report.errors.length} 个错误，未写盘');
    exitCode = 1;
    return;
  }

  // ── 写盘（全部通过校验才落盘；内容已是编码后的 JSON 字符串） ──
  files.forEach((rel, content) {
    final f = File('$outDir/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  });
  // ignore: avoid_print
  print('已生成 ${files.length} 个分层数据文件 → $outDir/');
}
