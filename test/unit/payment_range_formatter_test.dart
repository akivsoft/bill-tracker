import 'package:bill_tracker/features/bills/domain/services/payment_range_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentRangeFormatter', () {
    test('labels an exact full month with its year', () {
      expect(
        PaymentRangeFormatter.label(
          DateTimeRange(
            start: DateTime(2026, 12, 1),
            end: DateTime(2026, 12, 31),
          ),
        ),
        'December 2026',
      );
    });

    test('labels partial month ranges with both days', () {
      expect(
        PaymentRangeFormatter.label(
          DateTimeRange(
            start: DateTime(2026, 12, 1),
            end: DateTime(2026, 12, 15),
          ),
        ),
        'Dec 1–15, 2026',
      );
    });

    test('uses actual leap February month length', () {
      expect(
        PaymentRangeFormatter.label(
          DateTimeRange(
            start: DateTime(2028, 2, 1),
            end: DateTime(2028, 2, 29),
          ),
        ),
        'February 2028',
      );
    });

    test('shows years across a year boundary', () {
      expect(
        PaymentRangeFormatter.label(
          DateTimeRange(
            start: DateTime(2026, 12, 15),
            end: DateTime(2027, 1, 15),
          ),
        ),
        'Dec 15, 2026 – Jan 15, 2027',
      );
    });
  });
}
