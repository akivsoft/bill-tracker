import 'package:bill_tracker/features/loans/domain/services/loan_status_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoanStatusCalculator', () {
    final DateTime today = DateTime(2026, 11, 3);
    final LoanEntry loan = LoanEntry(
      id: 'loan-a',
      name: 'GCash Loan A',
      providerName: 'GCash',
      principalMinorUnits: 200000,
      remainingBalanceMinorUnits: 100000,
      currencyCode: 'PHP',
      openedAt: DateTime(2026, 9, 1),
      status: 'active',
    );

    test('overdue takes precedence over in progress', () {
      expect(
        LoanStatusCalculator.status(loan, <LoanInstallmentEntry>[
          LoanInstallmentEntry(
            id: 'paid',
            loanId: loan.id,
            installmentNumber: 1,
            dueDate: DateTime(2026, 10, 1),
            scheduledMinorUnits: 100000,
            paidMinorUnits: 100000,
            status: 'paid',
          ),
          LoanInstallmentEntry(
            id: 'late',
            loanId: loan.id,
            installmentNumber: 2,
            dueDate: DateTime(2026, 11, 1),
            scheduledMinorUnits: 100000,
            paidMinorUnits: 50000,
            status: 'partial',
          ),
        ], today),
        LoanStatus.overdue,
      );
    });

    test('partial payments remain in progress before the due date', () {
      expect(
        LoanStatusCalculator.status(loan, <LoanInstallmentEntry>[
          LoanInstallmentEntry(
            id: 'partial',
            loanId: loan.id,
            installmentNumber: 1,
            dueDate: DateTime(2026, 12, 1),
            scheduledMinorUnits: 100000,
            paidMinorUnits: 25000,
            status: 'partial',
          ),
        ], today),
        LoanStatus.inProgress,
      );
    });

    test('zero remaining is fully paid and cancellation is retained', () {
      expect(
        LoanStatusCalculator.status(
          LoanEntry(
            id: 'paid',
            name: 'Paid loan',
            providerName: 'GCash',
            principalMinorUnits: 100000,
            remainingBalanceMinorUnits: 0,
            currencyCode: 'PHP',
            openedAt: DateTime(2026),
            status: 'paid',
          ),
          const <LoanInstallmentEntry>[],
          today,
        ),
        LoanStatus.fullyPaid,
      );
      expect(
        LoanStatusCalculator.status(
          LoanEntry(
            id: 'cancelled',
            name: 'Cancelled loan',
            providerName: 'GCash',
            principalMinorUnits: 100000,
            remainingBalanceMinorUnits: 100000,
            currencyCode: 'PHP',
            openedAt: DateTime(2026),
            status: 'cancelled',
          ),
          const <LoanInstallmentEntry>[],
          today,
        ),
        LoanStatus.cancelled,
      );
    });
  });
}
