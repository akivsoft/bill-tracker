import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter_test/flutter_test.dart';

BillEntry _bill({bool allocate = false}) => BillEntry(
  id: 'rent',
  name: 'Rent',
  amountMinorUnits: 5000000,
  currencyCode: 'PHP',
  dueDate: DateTime(2026, 1, 31),
  frequency: 'monthly',
  isActive: true,
  automaticAllocation: allocate,
);

void main() {
  group('BillScheduleCalculator', () {
    test('monthly dates clamp to month end and return to anchor day', () {
      expect(
        BillScheduleCalculator.occurrences(
          anchor: DateTime(2026, 1, 31),
          frequency: 'monthly',
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 4, 30),
        ),
        <DateTime>[
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 31),
          DateTime(2026, 4, 30),
        ],
      );
    });

    test('monthly February recurrence handles leap years', () {
      expect(
        BillScheduleCalculator.occurrences(
          anchor: DateTime(2024, 1, 31),
          frequency: 'monthly',
          start: DateTime(2024, 2, 1),
          end: DateTime(2024, 2, 29),
        ),
        <DateTime>[DateTime(2024, 2, 29)],
      );
    });

    test('period payments and skips determine occurrence status', () {
      final BillOccurrence occurrence = BillOccurrence(
        bill: _bill(),
        dueDate: DateTime(2026, 1, 31),
      );
      final DateTime now = DateTime(2026, 2, 1);
      final List<BillPaymentEntry> partial = <BillPaymentEntry>[
        BillPaymentEntry(
          id: 'payment',
          billId: 'rent',
          accountId: 'cash',
          amountMinorUnits: 2000000,
          occurrenceKey: '2026-01-31',
          paidAt: DateTime(2026, 1, 31),
        ),
      ];
      expect(occurrence.remaining(partial), 3000000);
      expect(
        occurrence.status(partial, now),
        BillOccurrenceStatus.partiallyPaid,
      );

      final BillPaymentEntry skipped = BillPaymentEntry(
        id: 'skip',
        billId: 'rent',
        accountId: 'cash',
        amountMinorUnits: 0,
        occurrenceKey: '2026-01-31',
        paidAt: now,
        notes: '[skipped]',
      );
      expect(
        occurrence.status(<BillPaymentEntry>[skipped], now),
        BillOccurrenceStatus.skipped,
      );
    });

    test('allocation forecast stays separate from actual money', () {
      final List<BillOccurrence> due = <BillOccurrence>[
        BillOccurrence(
          bill: _bill(allocate: true),
          dueDate: DateTime(2026, 1, 31),
        ),
        BillOccurrence(
          bill: BillEntry(
            id: 'internet',
            name: 'Internet',
            amountMinorUnits: 200000,
            currencyCode: 'PHP',
            dueDate: DateTime(2026, 1, 31),
            frequency: 'monthly',
            isActive: true,
            automaticAllocation: false,
          ),
          dueDate: DateTime(2026, 1, 31),
        ),
      ];
      final BillAllocationForecast forecast = BillScheduleCalculator.forecast(
        occurrences: due,
        payments: const <BillPaymentEntry>[],
        actualAvailableMinorUnits: 10000000,
      );
      expect(forecast.upcomingObligationsMinorUnits, 5200000);
      expect(forecast.allocatedMinorUnits, 5000000);
      expect(forecast.unallocatedMinorUnits, 200000);
      expect(forecast.projectedRemainingMinorUnits, 4800000);
    });
  });
}
