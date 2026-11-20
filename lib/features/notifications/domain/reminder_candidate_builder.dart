import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/planner/domain/services/payday_schedule_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:intl/intl.dart';

import 'reminder_planner.dart';

abstract final class ReminderCandidateBuilder {
  static List<ReminderCandidate> build({
    required List<BillEntry> bills,
    required List<BillPaymentEntry> payments,
    required List<LoanEntry> loans,
    required List<LoanInstallmentEntry> installments,
    required List<FinancialAccount> accounts,
    required List<PaydayScheduleEntry> paydays,
    required List<SavingsGoalEntry> goals,
    required DateTime now,
    required DateTime? calendarReminderAt,
  }) {
    final DateTime horizon = now.add(const Duration(days: 120));
    final List<ReminderCandidate> candidates = <ReminderCandidate>[];
    for (final BillEntry bill in bills.where((item) => item.isActive)) {
      final List<DateTime> dates = BillScheduleCalculator.occurrences(
        anchor: bill.dueDate,
        frequency: bill.frequency,
        start: DateTime(now.year, now.month, now.day),
        end: horizon,
      );
      for (final DateTime due in dates) {
        final BillOccurrence occurrence = BillOccurrence(
          bill: bill,
          dueDate: due,
        );
        final BillOccurrenceStatus status = occurrence.status(payments, now);
        if (status == BillOccurrenceStatus.paid ||
            status == BillOccurrenceStatus.skipped ||
            status == BillOccurrenceStatus.cancelled) {
          continue;
        }
        candidates.add(
          ReminderCandidate(
            key: 'bill:${bill.id}:${DateFormat('yyyy-MM-dd').format(due)}',
            title: status == BillOccurrenceStatus.overdue
                ? 'Overdue bill'
                : 'Upcoming bill',
            body: status == BillOccurrenceStatus.overdue
                ? 'An overdue bill needs review in MyFinance.'
                : 'A bill payment is coming up. Open MyFinance to review.',
            category: 'bills',
            dueAt: due,
            isOverdue: status == BillOccurrenceStatus.overdue,
          ),
        );
      }
      if (bill.frequency == 'one_time' && bill.dueDate.isBefore(now)) {
        final BillOccurrence occurrence = BillOccurrence(
          bill: bill,
          dueDate: bill.dueDate,
        );
        if (occurrence.status(payments, now) == BillOccurrenceStatus.overdue) {
          candidates.add(
            ReminderCandidate(
              key:
                  'bill:${bill.id}:${DateFormat('yyyy-MM-dd').format(bill.dueDate)}',
              title: 'Overdue bill',
              body: 'An overdue bill needs review in MyFinance.',
              category: 'bills',
              dueAt: now,
              isOverdue: true,
            ),
          );
        }
      }
    }

    final Set<String> activeLoanIds = loans
        .where(
          (LoanEntry item) =>
              item.archivedAt == null &&
              item.status != 'paid' &&
              item.status != 'cancelled',
        )
        .map((LoanEntry item) => item.id)
        .toSet();
    for (final LoanInstallmentEntry item in installments.where(
      (LoanInstallmentEntry row) =>
          activeLoanIds.contains(row.loanId) &&
          row.status != 'paid' &&
          row.status != 'settled',
    )) {
      final bool overdue = item.dueDate.isBefore(
        DateTime(now.year, now.month, now.day),
      );
      candidates.add(
        ReminderCandidate(
          key:
              'loan:${item.id}:${DateFormat('yyyy-MM-dd').format(item.dueDate)}',
          title: overdue
              ? 'Overdue loan installment'
              : 'Upcoming loan installment',
          body: overdue
              ? 'An overdue installment needs review in MyFinance.'
              : 'A loan installment is coming up. Open MyFinance to review.',
          category: 'loans',
          dueAt: overdue ? now : item.dueDate,
          isOverdue: overdue,
        ),
      );
    }

    for (final FinancialAccount account in accounts.where(
      (FinancialAccount item) =>
          item.isActive &&
          item.accountType == 'credit_card' &&
          item.paymentDueDate != null,
    )) {
      final DateTime due = account.paymentDueDate!;
      final DateTime nextDue =
          DateTime(
            now.year,
            due.month,
            due.day,
          ).isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year + 1, due.month, due.day)
          : DateTime(now.year, due.month, due.day);
      candidates.add(
        ReminderCandidate(
          key: 'card:${account.id}:${DateFormat('yyyy-MM-dd').format(nextDue)}',
          title: 'Credit card payment due',
          body: 'A credit card payment is coming up. Open MyFinance to review.',
          category: 'credit_cards',
          dueAt: nextDue,
        ),
      );
    }

    for (final PaydayScheduleEntry payday in paydays.where(
      (PaydayScheduleEntry item) => item.isActive && item.status != 'received',
    )) {
      for (final DateTime date in PaydayScheduleCalculator.occurrences(
        anchor: payday.paydayDate,
        frequency: payday.frequency,
        start: now,
        end: horizon,
      )) {
        candidates.add(
          ReminderCandidate(
            key: 'payday:${payday.id}:${DateFormat('yyyy-MM-dd').format(date)}',
            title: 'Expected payday',
            body:
                'An expected income date is coming up. Open MyFinance to review.',
            category: 'paydays',
            dueAt: date,
          ),
        );
      }
    }

    for (final SavingsGoalEntry goal in goals.where(
      (SavingsGoalEntry item) =>
          item.status == 'active' &&
          item.targetDate != null &&
          item.contributionSchedule != null,
    )) {
      if (!goal.targetDate!.isBefore(now) &&
          !goal.targetDate!.isAfter(horizon)) {
        candidates.add(
          ReminderCandidate(
            key:
                'savings:${goal.id}:${DateFormat('yyyy-MM-dd').format(goal.targetDate!)}',
            title: 'Savings goal reminder',
            body:
                'A configured savings target date is coming up. Open MyFinance to review.',
            category: 'savings',
            dueAt: goal.targetDate!,
          ),
        );
      }
    }

    if (calendarReminderAt != null && calendarReminderAt.isAfter(now)) {
      candidates.add(
        ReminderCandidate(
          key: 'calendar:${calendarReminderAt.toIso8601String()}',
          title: 'Calendar reminder',
          body: 'Your scheduled calendar reminder is due.',
          category: 'calendar',
          dueAt: calendarReminderAt,
        ),
      );
    }
    return candidates;
  }
}
