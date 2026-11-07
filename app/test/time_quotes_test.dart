import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/core/time_quotes.dart';

void main() {
  test('quote pool is curated: non-empty, unique, single-line', () {
    expect(kTimeQuotes, hasLength(greaterThanOrEqualTo(8)));
    expect(kTimeQuotes.toSet(), hasLength(kTimeQuotes.length));
    for (final quote in kTimeQuotes) {
      expect(quote.trim(), isNotEmpty);
      expect(quote.contains('\n'), isFalse);
    }
  });

  test('pickTimeQuote always returns a quote from the pool', () {
    final rng = Random(42);
    final picked = {for (var i = 0; i < 200; i++) pickTimeQuote(rng)};
    expect(picked.difference(kTimeQuotes.toSet()), isEmpty);
  });
}
