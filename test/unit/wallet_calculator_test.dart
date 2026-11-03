import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/wallets/domain/services/wallet_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletCalculator', () {
    test('credit card calculations safely handle zero limits', () {
      const FinancialAccount account = FinancialAccount(
        id: 'card',
        name: 'Card',
        accountType: 'credit_card',
        currentBalanceMinorUnits: 0,
        currencyCode: 'PHP',
        isActive: true,
        creditLimitMinorUnits: 0,
        outstandingCreditMinorUnits: 12500,
      );

      expect(WalletCalculator.availableCredit(account), -12500);
      expect(WalletCalculator.creditUtilizationBasisPoints(account), 0);
    });

    test(
      'balance history reflects only recorded income, spend, and reversal',
      () {
        final DateTime first = DateTime(2026, 10, 20);
        final DateTime second = DateTime(2026, 10, 21);
        const FinancialAccount account = FinancialAccount(
          id: 'cash',
          name: 'Cash',
          accountType: 'cash',
          currentBalanceMinorUnits: 14500,
          openingBalanceMinorUnits: 10000,
          currencyCode: 'PHP',
          isActive: true,
        );
        final List<FinancialTransactionView> transactions =
            <FinancialTransactionView>[
              FinancialTransactionView(
                id: 'income',
                type: 'income',
                title: 'Pay',
                amountMinorUnits: 5000,
                currencyCode: 'PHP',
                occurredAt: first,
                destinationAccountId: 'cash',
              ),
              FinancialTransactionView(
                id: 'expense',
                type: 'expense',
                title: 'Food',
                amountMinorUnits: 1000,
                currencyCode: 'PHP',
                occurredAt: second,
                sourceAccountId: 'cash',
              ),
              FinancialTransactionView(
                id: 'reversal',
                type: 'reversal',
                title: 'Reverse food',
                amountMinorUnits: 1000,
                currencyCode: 'PHP',
                occurredAt: second.add(const Duration(days: 1)),
                reversalOfId: 'expense',
              ),
            ];

        final List<BalanceHistoryPoint> points =
            WalletCalculator.balanceHistory(
              account,
              transactions,
              range: BalanceHistoryRange.custom,
              now: DateTime(2026, 10, 31),
              customStart: DateTime(2026, 10, 1),
              customEnd: DateTime(2026, 10, 31),
            );

        expect(
          points.map((BalanceHistoryPoint point) => point.balanceMinorUnits),
          <int>[15000, 14000, 15000],
        );
      },
    );

    test('balance history is empty when no transactions exist', () {
      const FinancialAccount account = FinancialAccount(
        id: 'cash',
        name: 'Cash',
        accountType: 'cash',
        currentBalanceMinorUnits: 10000,
        openingBalanceMinorUnits: 10000,
        currencyCode: 'PHP',
        isActive: true,
      );

      expect(
        WalletCalculator.balanceHistory(
          account,
          const <FinancialTransactionView>[],
          range: BalanceHistoryRange.monthly,
          now: DateTime(2026, 11, 3),
        ),
        isEmpty,
      );
    });
  });
}
