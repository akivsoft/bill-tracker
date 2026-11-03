import 'package:bill_tracker/features/planner/domain/services/payday_schedule_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaydayScheduleCalculator', () {
    test('projects biweekly dates without storing occurrences', () {
      final dates = PaydayScheduleCalculator.occurrences(
        anchor: DateTime(2026, 10, 30),
        frequency: 'biweekly',
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 12, 1),
      );
      expect(dates, <DateTime>[DateTime(2026, 11, 13), DateTime(2026, 11, 27)]);
    });

    test('twice monthly paydays use the 1st and 15th', () {
      final dates = PaydayScheduleCalculator.occurrences(
        anchor: DateTime(2026, 11, 15),
        frequency: 'twice_monthly',
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 12, 1),
      );
      expect(dates, <DateTime>[DateTime(2026, 11, 15), DateTime(2026, 12, 1)]);
    });

    test('monthly schedules clamp leap February and return to anchor day', () {
      final dates = PaydayScheduleCalculator.occurrences(
        anchor: DateTime(2024, 1, 31),
        frequency: 'monthly',
        start: DateTime(2024, 2, 1),
        end: DateTime(2024, 4, 30),
      );
      expect(dates, <DateTime>[
        DateTime(2024, 2, 29),
        DateTime(2024, 3, 31),
        DateTime(2024, 4, 30),
      ]);
    });
  });
}
