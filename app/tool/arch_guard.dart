// 架构依赖守护（ARCHITECTURE.md §10）：扫描 lib/ 的 import，违例即失败。
// 用法：dart run tool/arch_guard.dart
// 规则（ARCHITECTURE §2 依赖守恒律的机器可查子集）：
import 'dart:io';

const rules = <String, List<String>>{
  // 层（lib/ 下目录前缀）: 禁止 import 的路径前缀
  'lib/domain/': [
    'lib/state/',
    'lib/ui/',
    'package:shared_preferences',
    'package:flutter/material.dart', // 领域层不依赖 Material（foundation 除外）
  ],
  'lib/ui/': ['lib/data/catalog.dart', 'lib/data/engine_config.dart', 'lib/semantic/'],
  'lib/state/': ['lib/ui/'],
  'lib/data/': ['lib/domain/', 'lib/state/', 'lib/ui/'],
  'lib/semantic/': ['lib/domain/', 'lib/state/', 'lib/ui/'],
};

// 例外（依赖倒置的合法方向：infra 实现 domain 定义的 Port）
const allowed = <String, List<String>>{
  'lib/infra/': ['lib/domain/delivery/notification_sink.dart', 'lib/models/'],
};

void main() {
  final violations = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('import ') && !line.startsWith('export ')) continue;
      final target = line
          .replaceAll(RegExp(r'^(import|export)\s+'), '')
          .replaceAll(RegExp(r"[';].*$"), '')
          .trim();
      final resolved = target.startsWith('package:kairo_step/')
          ? 'lib/${target.substring('package:kairo_step/'.length)}'
          : _resolveRelative(path, target);

      rules.forEach((scope, forbidden) {
        if (!path.startsWith(scope)) return;
        for (final bad in forbidden) {
          if (resolved == null) continue;
          final hit = resolved.startsWith(bad) ||
              (bad.startsWith('package:') && line.contains(bad));
          if (!hit) continue;
          // 例外白名单
          final ok = allowed.entries.any(
            (e) => path.startsWith(e.key) &&
                e.value.any((w) => resolved.startsWith(w)),
          );
          if (ok) continue;
          violations.add('$path:${i + 1} → $target（违反 $scope 禁止 import $bad）');
        }
      });
    }
  }

  if (violations.isEmpty) {
    // ignore: avoid_print
    print('arch_guard ✓ 依赖规则 0 违例（扫描 ${files.length} 个文件）');
    return;
  }
  for (final v in violations) {
    // ignore: avoid_print
    print('arch_guard ✗ $v');
  }
  // ignore: avoid_print
  print('arch_guard 失败：${violations.length} 处违例');
  exitCode = 1;
}

String? _resolveRelative(String fromFile, String target) {
  if (!target.startsWith('.')) return target;
  final parts = fromFile.split('/')..removeLast();
  for (final seg in target.split('/')) {
    if (seg == '..') {
      parts.removeLast();
    } else if (seg == '.') {
      continue;
    } else {
      parts.add(seg);
    }
  }
  return parts.join('/');
}
