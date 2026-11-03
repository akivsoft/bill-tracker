import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';

/// Financial rules shared by repositories and presentation providers.
/// All amounts are integer minor units; this class never converts to `double`.
final class FinancialCalculator {
  const FinancialCalculator._();

  static int actualAvailableMoney(
    Iterable<AccountBalance> accounts, {
    String currencyCode = 'PHP',
  }) => accounts
      .where(
        (AccountBalance account) =>
            account.isActive &&
            !account.isCreditAccount &&
            !account.isLinkedDebitCard &&
            account.currencyCode == currencyCode,
      )
      .fold<int>(0, (int total, AccountBalance account) {
        return total + account.currentBalanceMinorUnits;
      });

  static int availableCredit({
    required int creditLimitMinorUnits,
    required int outstandingMinorUnits,
  }) {
    _requireNonNegative(creditLimitMinorUnits, 'creditLimitMinorUnits');
    _requireNonNegative(outstandingMinorUnits, 'outstandingMinorUnits');
    return creditLimitMinorUnits - outstandingMinorUnits;
  }

  static int projectedRemainingMoney({
    required int actualAvailableMinorUnits,
    required int expectedIncomeMinorUnits,
    required int upcomingObligationsMinorUnits,
    required int plannedExpensesMinorUnits,
  }) {
    _requireNonNegative(expectedIncomeMinorUnits, 'expectedIncomeMinorUnits');
    _requireNonNegative(
      upcomingObligationsMinorUnits,
      'upcomingObligationsMinorUnits',
    );
    _requireNonNegative(plannedExpensesMinorUnits, 'plannedExpensesMinorUnits');
    return actualAvailableMinorUnits +
        expectedIncomeMinorUnits -
        upcomingObligationsMinorUnits -
        plannedExpensesMinorUnits;
  }

  static int confirmIncome({
    required int currentBalanceMinorUnits,
    required int amountMinorUnits,
  }) {
    _requirePositive(amountMinorUnits, 'amountMinorUnits');
    return currentBalanceMinorUnits + amountMinorUnits;
  }

  static int confirmExpense({
    required int currentBalanceMinorUnits,
    required int amountMinorUnits,
    bool allowNegativeBalance = false,
  }) {
    _requirePositive(amountMinorUnits, 'amountMinorUnits');
    if (!allowNegativeBalance) {
      _requireSufficientBalance(currentBalanceMinorUnits, amountMinorUnits);
    }
    return currentBalanceMinorUnits - amountMinorUnits;
  }

  static TransferBalances transfer({
    required int sourceBalanceMinorUnits,
    required int destinationBalanceMinorUnits,
    required int amountMinorUnits,
    bool allowNegativeSourceBalance = false,
  }) {
    _requirePositive(amountMinorUnits, 'amountMinorUnits');
    if (!allowNegativeSourceBalance) {
      _requireSufficientBalance(sourceBalanceMinorUnits, amountMinorUnits);
    }
    return TransferBalances(
      sourceBalanceMinorUnits: sourceBalanceMinorUnits - amountMinorUnits,
      destinationBalanceMinorUnits:
          destinationBalanceMinorUnits + amountMinorUnits,
    );
  }

  static int creditCardPurchase({
    required int creditLimitMinorUnits,
    required int outstandingMinorUnits,
    required int purchaseMinorUnits,
  }) {
    _requirePositive(purchaseMinorUnits, 'purchaseMinorUnits');
    final int remainingCredit = availableCredit(
      creditLimitMinorUnits: creditLimitMinorUnits,
      outstandingMinorUnits: outstandingMinorUnits,
    );
    if (purchaseMinorUnits > remainingCredit) {
      throw StateError('Purchase exceeds available credit.');
    }
    return outstandingMinorUnits + purchaseMinorUnits;
  }

  static CreditBalances creditCardPayment({
    required int cashBalanceMinorUnits,
    required int outstandingMinorUnits,
    required int amountMinorUnits,
    bool allowNegativeCashBalance = false,
  }) {
    _requirePositive(amountMinorUnits, 'amountMinorUnits');
    if (!allowNegativeCashBalance) {
      _requireSufficientBalance(cashBalanceMinorUnits, amountMinorUnits);
    }
    _requireSufficientBalance(outstandingMinorUnits, amountMinorUnits);
    return CreditBalances(
      cashBalanceMinorUnits: cashBalanceMinorUnits - amountMinorUnits,
      outstandingMinorUnits: outstandingMinorUnits - amountMinorUnits,
    );
  }

  static int creditUtilizationBasisPoints({
    required int creditLimitMinorUnits,
    required int outstandingMinorUnits,
  }) {
    _requireNonNegative(creditLimitMinorUnits, 'creditLimitMinorUnits');
    _requireNonNegative(outstandingMinorUnits, 'outstandingMinorUnits');
    if (creditLimitMinorUnits == 0) return 0;
    return outstandingMinorUnits * 10000 ~/ creditLimitMinorUnits;
  }

  static LoanPaymentBalances applyLoanPayment({
    required int loanRemainingMinorUnits,
    required int scheduledInstallmentMinorUnits,
    required int paidInstallmentMinorUnits,
    required int paymentMinorUnits,
  }) {
    _requirePositive(paymentMinorUnits, 'paymentMinorUnits');
    final int installmentRemaining =
        scheduledInstallmentMinorUnits - paidInstallmentMinorUnits;
    _requireSufficientBalance(loanRemainingMinorUnits, paymentMinorUnits);
    _requireSufficientBalance(installmentRemaining, paymentMinorUnits);
    return LoanPaymentBalances(
      loanRemainingMinorUnits: loanRemainingMinorUnits - paymentMinorUnits,
      installmentPaidMinorUnits: paidInstallmentMinorUnits + paymentMinorUnits,
      installmentRemainingMinorUnits: installmentRemaining - paymentMinorUnits,
    );
  }

  static int reconciliationDelta({
    required int recordedBalanceMinorUnits,
    required int actualBalanceMinorUnits,
  }) => actualBalanceMinorUnits - recordedBalanceMinorUnits;

  static int _requirePositive(int amount, String name) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, name, 'Must be positive.');
    }
    return amount;
  }

  static int _requireNonNegative(int amount, String name) {
    if (amount < 0) {
      throw ArgumentError.value(amount, name, 'Cannot be negative.');
    }
    return amount;
  }

  static void _requireSufficientBalance(int balance, int amount) {
    if (balance < amount) throw StateError('Insufficient balance.');
  }
}
