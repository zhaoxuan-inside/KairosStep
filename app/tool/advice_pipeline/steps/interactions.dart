import '../common.dart';
import 'normalize.dart';

/// L5 presentation is independent from legacy style-based trigger inference.
Map<String, String> serializeInteractions({
  required Normalized n,
  required Map<int, List<String>> parts,
  required Report report,
}) {
  final overrides =
      loadSource('interaction_overrides')['overrides'] as Map<String, dynamic>;
  final ids = n.adviceRows.map((a) => '${a['id']}').toSet();
  for (final id in overrides.keys) {
    if (!ids.contains(id)) report.error('Unknown interaction override: $id');
  }
  final rows = <Map<String, dynamic>>[];
  for (final a in n.adviceRows) {
    final id = a['id'] as int;
    final override = (overrides['$id'] as Map<String, dynamic>?) ?? const {};
    final style = (override['style'] ?? a['style']) as String;
    final specialized = override['override'] as String?;
    final params = <String, dynamic>{
      'sourceStyle': a['style'],
      'completion':
          const {
            'redline-stamp',
            'context-guard',
            'emergency-action',
          }.contains(style)
          ? 'acknowledgement'
          : specialized == 'record'
          ? 'record'
          : 'action',
      'items': parts[id] ?? const <String>[],
      ...((override['params'] as Map<String, dynamic>?) ?? const {}),
    };
    if (const {'deadline', 'writing'}.contains(specialized)) {
      params['completion'] = 'planning';
    }
    if (a['style'] == 'windowed-cadence' && override.isEmpty) {
      report.error('Window interaction needs explicit semantics: $id');
    }
    if (style == 'slider-calc' && specialized != 'record') {
      report.error('Unspecified numeric calculation: $id');
    }
    rows.add({
      'id': id,
      'style': style,
      'override': ?specialized,
      'reason': override['reason'] ?? '保留与任务类型相符的交互，使用统一的明确反馈语义',
      'params': params,
    });
  }
  return {
    'styles/display_bindings.json': encodeStable({
      'schemaVersion': schemaVersion,
      'list': rows,
    }),
  };
}
