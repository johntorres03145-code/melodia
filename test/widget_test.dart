import 'package:flutter_test/flutter_test.dart';

import 'package:melodia/utils/greeting.dart';

void main() {
  test('greetingByHour respeta los rangos del día', () {
    expect(greetingByHour(DateTime(2026, 1, 1, 6)), 'Good morning');
    expect(greetingByHour(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(greetingByHour(DateTime(2026, 1, 1, 19)), 'Good evening');
    expect(greetingByHour(DateTime(2026, 1, 1, 23)), 'Good evening');
    expect(greetingByHour(DateTime(2026, 1, 1, 2)), 'Good night');
    expect(greetingByHour(DateTime(2026, 1, 1, 4)), 'Good night');
  });
}