/// A read-only balance snapshot used by financial calculations.
final class AccountBalance {
  const AccountBalance({
    required this.id,
    required this.accountType,
    required this.currencyCode,
    required this.currentBalanceMinorUnits,
    this.creditLimitMinorUnits = 0,
    this.outstandingCreditMinorUnits = 0,
    this.isActive = true,
  });

  final String id;
  final String accountType;
  final String currencyCode;
  final int currentBalanceMinorUnits;
  final int creditLimitMinorUnits;
  final int outstandingCreditMinorUnits;
  final bool isActive;

  bool get isCreditAccount =>
      accountType.toLowerCase().replaceAll(RegExp(r'[_\s-]'), '') ==
      'creditcard';
}

final class TransferBalances {
  const TransferBalances({
    required this.sourceBalanceMinorUnits,
    required this.destinationBalanceMinorUnits,
  });

  final int sourceBalanceMinorUnits;
  final int destinationBalanceMinorUnits;
}

final class CreditBalances {
  const CreditBalances({
    required this.cashBalanceMinorUnits,
    required this.outstandingMinorUnits,
  });

  final int cashBalanceMinorUnits;
  final int outstandingMinorUnits;
}

final class LoanPaymentBalances {
  const LoanPaymentBalances({
    required this.loanRemainingMinorUnits,
    required this.installmentPaidMinorUnits,
    required this.installmentRemainingMinorUnits,
  });

  final int loanRemainingMinorUnits;
  final int installmentPaidMinorUnits;
  final int installmentRemainingMinorUnits;
}

final class FinancialTransactionView {
  const FinancialTransactionView({
    required this.id,
    required this.type,
    required this.title,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredAt,
    this.sourceAccountId,
    this.destinationAccountId,
    this.relatedRecordId,
    this.reversalOfId,
  });

  final String id;
  final String type;
  final String title;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime occurredAt;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final String? relatedRecordId;
  final String? reversalOfId;
}
