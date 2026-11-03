import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';

enum LoanStatus { notStarted, inProgress, overdue, fullyPaid, cancelled }

final class LoanStatusCalculator {
  const LoanStatusCalculator._();

  static LoanStatus status(
    LoanEntry loan,
    Iterable<LoanInstallmentEntry> installments,
    DateTime today,
  ) {
    if (loan.status == 'cancelled') return LoanStatus.cancelled;
    final List<LoanInstallmentEntry> rows = installments
        .where((LoanInstallmentEntry item) => item.loanId == loan.id)
        .toList();
    if (loan.remainingBalanceMinorUnits <= 0) return LoanStatus.fullyPaid;
    final DateTime date = DateTime(today.year, today.month, today.day);
    final bool overdue = rows.any((LoanInstallmentEntry item) {
      if (item.status == 'settled' || item.status == 'paid') return false;
      final int remaining = item.scheduledMinorUnits - item.paidMinorUnits;
      final DateTime due = DateTime(
        item.dueDate.year,
        item.dueDate.month,
        item.dueDate.day,
      );
      return remaining > 0 && due.isBefore(date);
    });
    if (overdue) return LoanStatus.overdue;
    final bool anyPayment = rows.any(
      (LoanInstallmentEntry item) => item.paidMinorUnits > 0,
    );
    return anyPayment ? LoanStatus.inProgress : LoanStatus.notStarted;
  }
}
