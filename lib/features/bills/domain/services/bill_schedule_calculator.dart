import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';

enum BillOccurrenceStatus {
  upcoming,
  unpaid,
  partiallyPaid,
  paid,
  overdue,
  skipped,
  cancelled,
}

final class BillOccurrence {
  const BillOccurrence({required this.bill, required this.dueDate});

  final BillEntry bill;
  final DateTime dueDate;

  String get key =>
      '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

  int remaining(Iterable<BillPaymentEntry> payments) {
    final List<BillPaymentEntry> matching = payments
        .where(
          (BillPaymentEntry payment) =>
              payment.billId == bill.id &&
              payment.occurrenceKey == key &&
              payment.reversedAt == null,
        )
        .toList();
    if (matching.any((BillPaymentEntry payment) => payment.isSkipped)) return 0;
    final int paid = matching.fold<int>(
      0,
      (int sum, BillPaymentEntry payment) => sum + payment.amountMinorUnits,
    );
    return (bill.amountMinorUnits - paid).clamp(0, bill.amountMinorUnits);
  }

  BillOccurrenceStatus status(
    Iterable<BillPaymentEntry> payments,
    DateTime today,
  ) {
    if (!bill.isActive) return BillOccurrenceStatus.cancelled;
    final List<BillPaymentEntry> matching = payments
        .where(
          (BillPaymentEntry payment) =>
              payment.billId == bill.id &&
              payment.occurrenceKey == key &&
              payment.reversedAt == null,
        )
        .toList();
    if (matching.any((BillPaymentEntry payment) => payment.isSkipped)) {
      return BillOccurrenceStatus.skipped;
    }
    final int outstanding = remaining(payments);
    if (outstanding == 0) return BillOccurrenceStatus.paid;
    final int paid = bill.amountMinorUnits - outstanding;
    if (paid > 0) return BillOccurrenceStatus.partiallyPaid;
    final DateTime day = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);
    if (day.isAfter(todayOnly)) return BillOccurrenceStatus.upcoming;
    if (day.isBefore(todayOnly)) return BillOccurrenceStatus.overdue;
    return BillOccurrenceStatus.unpaid;
  }
}

final class BillAllocationForecast {
  const BillAllocationForecast({
    required this.upcomingObligationsMinorUnits,
    required this.allocatedMinorUnits,
    required this.unallocatedMinorUnits,
    required this.projectedRemainingMinorUnits,
  });

  final int upcomingObligationsMinorUnits;
  final int allocatedMinorUnits;
  final int unallocatedMinorUnits;
  final int projectedRemainingMinorUnits;
}

final class BillScheduleCalculator {
  const BillScheduleCalculator._();

  static List<DateTime> occurrences({
    required DateTime anchor,
    required String frequency,
    required DateTime start,
    required DateTime end,
    int limit = 500,
  }) {
    final DateTime first = DateTime(anchor.year, anchor.month, anchor.day);
    final DateTime rangeStart = DateTime(start.year, start.month, start.day);
    final DateTime rangeEnd = DateTime(end.year, end.month, end.day);
    if (rangeEnd.isBefore(rangeStart) || end.isBefore(anchor)) {
      return const <DateTime>[];
    }
    if (frequency == 'one_time') {
      return !first.isBefore(rangeStart) && !first.isAfter(rangeEnd)
          ? <DateTime>[first]
          : const <DateTime>[];
    }
    final List<DateTime> result = <DateTime>[];
    final int estimated = _indexNear(anchor, frequency, rangeStart);
    final int begin = estimated > 0 ? estimated - 1 : 0;
    for (int offset = 0; offset < limit; offset++) {
      final int index = begin + offset;
      final DateTime occurrence = _at(anchor, frequency, index);
      if (occurrence.isAfter(rangeEnd)) break;
      if (!occurrence.isBefore(rangeStart)) result.add(occurrence);
    }
    return result;
  }

  static DateTime? nextAfter(
    DateTime anchor,
    String frequency,
    DateTime after,
  ) {
    if (frequency == 'one_time') return null;
    final DateTime target = DateTime(after.year, after.month, after.day);
    for (int index = 0; index < 500; index++) {
      final DateTime candidate = _at(anchor, frequency, index);
      if (candidate.isAfter(target)) return candidate;
    }
    return null;
  }

  static BillAllocationForecast forecast({
    required Iterable<BillOccurrence> occurrences,
    required Iterable<BillPaymentEntry> payments,
    required int actualAvailableMinorUnits,
  }) {
    int total = 0;
    int allocated = 0;
    for (final BillOccurrence occurrence in occurrences) {
      final BillOccurrenceStatus state = occurrence.status(
        payments,
        DateTime.now(),
      );
      if (state == BillOccurrenceStatus.paid ||
          state == BillOccurrenceStatus.skipped ||
          state == BillOccurrenceStatus.cancelled) {
        continue;
      }
      final int amount = occurrence.remaining(payments);
      total += amount;
      if (occurrence.bill.automaticAllocation) allocated += amount;
    }
    return BillAllocationForecast(
      upcomingObligationsMinorUnits: total,
      allocatedMinorUnits: allocated,
      unallocatedMinorUnits: total - allocated,
      projectedRemainingMinorUnits: actualAvailableMinorUnits - total,
    );
  }

  static DateTime _at(DateTime anchor, String frequency, int index) {
    final DateTime day = DateTime(anchor.year, anchor.month, anchor.day);
    return switch (frequency) {
      'daily' => day.add(Duration(days: index)),
      'weekly' => day.add(Duration(days: index * 7)),
      'biweekly' => day.add(Duration(days: index * 14)),
      'monthly' => _addMonths(anchor, index),
      'quarterly' => _addMonths(anchor, index * 3),
      'semiannual' => _addMonths(anchor, index * 6),
      'annual' || 'annually' => _addMonths(anchor, index * 12),
      _ when frequency.startsWith('custom:') => day.add(
        Duration(days: (int.tryParse(frequency.substring(7)) ?? 30) * index),
      ),
      _ => day,
    };
  }

  static int _indexNear(DateTime anchor, String frequency, DateTime start) {
    final int days = DateTime(
      start.year,
      start.month,
      start.day,
    ).difference(DateTime(anchor.year, anchor.month, anchor.day)).inDays;
    if (days <= 0) return 0;
    if (frequency == 'daily') return days;
    if (frequency == 'weekly') return days ~/ 7;
    if (frequency == 'biweekly') return days ~/ 14;
    final int months =
        (start.year - anchor.year) * 12 + start.month - anchor.month;
    if (frequency == 'monthly') return months;
    if (frequency == 'quarterly') return months ~/ 3;
    if (frequency == 'semiannual') return months ~/ 6;
    if (frequency == 'annual' || frequency == 'annually') return months ~/ 12;
    if (frequency.startsWith('custom:')) {
      return days ~/ (int.tryParse(frequency.substring(7)) ?? 30);
    }
    return 0;
  }

  static DateTime _addMonths(DateTime anchor, int months) {
    final int monthIndex = anchor.year * 12 + anchor.month - 1 + months;
    final int year = monthIndex ~/ 12;
    final int month = monthIndex % 12 + 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, anchor.day.clamp(1, lastDay));
  }
}
