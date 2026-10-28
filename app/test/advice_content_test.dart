import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every advice has complete detail and timers are independent', () {
    final advices = (jsonDecode(File('assets/data/advice.json').readAsStringSync())
        as Map<String, dynamic>)['list'] as List<dynamic>;
    final details = jsonDecode(File('assets/data/detail.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(advices, hasLength(767));
    expect(details, hasLength(advices.length));
    for (final raw in advices) {
      final advice = raw as Map<String, dynamic>;
      final id = advice['id'].toString();
      final detail = details[id] as Map<String, dynamic>?;
      expect(detail, isNotNull, reason: 'Missing detail for #$id');
      expect((detail!['plain'] as String).trim(), isNotEmpty);
      expect((detail['cost'] as String).trim(), isNotEmpty);
      expect((detail['sources'] as List).isNotEmpty, isTrue);
      expect(advice['act_type'], isNot('zen-timer'));
    }
    final sleep = advices.cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 103);
    expect(sleep['act_type'], 'daily-streak');
    expect(sleep['cron'], '30 21 * * *');

    final nap = advices.cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 85);
    expect(nap['act_type'], 'daily-streak');
    expect(nap['cron'], '45 12 * * *');
    expect(nap['timing_badge'], contains('12:45'));

    final duration = advices.cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 98);
    expect(duration['act_type'], 'daily-streak');
    expect(duration['cron'], '0 22 * * *');
  });
}
