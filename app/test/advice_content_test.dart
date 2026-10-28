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

    final regularity = advices.cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 61);
    expect(regularity['act_type'], 'daily-streak');
    expect(regularity['cron'], '0 23 * * *');
    expect(regularity['t'], '固定作息时间，减少工作日与周末的睡眠时差');

    final consent = advices.cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 280);
    expect(consent['act_type'], 'redline-stamp');
    expect(consent['t'], '对方喝到意识不清、睡着，绝对不要发生关系');

    final statutoryAge = advices.cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 313);
    expect(statutoryAge['act_type'], 'redline-stamp');
    expect(statutoryAge['t'], '对方不满 14 岁就不能发生关系，「她同意」不是理由');
  });
}
