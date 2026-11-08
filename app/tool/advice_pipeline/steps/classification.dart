import '../common.dart';
import 'normalize.dart';

/// Classification is presentation/interest metadata, never an inferred persona gate.
Map<String, String> serializeClassification(Normalized n) {
  final paths = <int, List<String>>{};
  for (final row in n.nodeRows) {
    (paths[row['id'] as int] ??= []).add(row['path'] as String);
  }
  final plans = {for (final p in n.triggerPlans) p['id'] as int: p};
  final rows = <Map<String, dynamic>>[];
  for (final advice in n.adviceRows) {
    final id = advice['id'] as int;
    final memberships = paths[id]!;
    final plan = plans[id]!;
    rows.add({
      'id': id,
      'primaryTopic': memberships.first,
      'topicPaths': memberships,
      'domain': memberships.first.split('/').first,
      'lane': plan['emergency'] == true ? 'emergency' : plan['mode'],
    });
  }
  return {
    'views/advice_classification.json': encodeStable({
      'schemaVersion': schemaVersion,
      'list': rows,
    }),
  };
}
