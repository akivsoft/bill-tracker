final class CreateAccountInput {
  const CreateAccountInput({
    required this.name,
    required this.accountType,
    required this.openingBalanceMinorUnits,
    this.userId,
    this.provider,
    this.currencyCode = 'PHP',
    this.creditLimitMinorUnits = 0,
    this.outstandingCreditMinorUnits = 0,
    this.openingOutstandingCreditMinorUnits,
    this.statementDate,
    this.paymentDueDate,
    this.statementBalanceMinorUnits = 0,
    this.minimumPaymentMinorUnits = 0,
    this.accountNumberSuffix,
    this.linkedAccountId,
    this.customTypeName,
    this.iconKey,
    this.colorArgb,
    this.notes,
    this.allowNegativeBalance = false,
  });

  final String? userId;
  final String name;
  final String? provider;
  final String accountType;
  final int openingBalanceMinorUnits;
  final String currencyCode;
  final int creditLimitMinorUnits;
  final int outstandingCreditMinorUnits;
  final int? openingOutstandingCreditMinorUnits;
  final DateTime? statementDate;
  final DateTime? paymentDueDate;
  final int statementBalanceMinorUnits;
  final int minimumPaymentMinorUnits;
  final String? accountNumberSuffix;
  final String? linkedAccountId;
  final String? customTypeName;
  final String? iconKey;
  final int? colorArgb;
  final String? notes;
  final bool allowNegativeBalance;
}

final class UpdateAccountInput {
  const UpdateAccountInput({
    required this.accountId,
    required this.name,
    this.provider,
    this.accountNumberSuffix,
    this.linkedAccountId,
    this.customTypeName,
    this.iconKey,
    this.colorArgb,
    this.statementBalanceMinorUnits = 0,
    this.minimumPaymentMinorUnits = 0,
    this.statementDate,
    this.paymentDueDate,
    this.notes,
    this.allowNegativeBalance = false,
    this.creditLimitMinorUnits,
  });

  final String accountId;
  final String name;
  final String? provider;
  final String? accountNumberSuffix;
  final String? linkedAccountId;
  final String? customTypeName;
  final String? iconKey;
  final int? colorArgb;
  final int statementBalanceMinorUnits;
  final int minimumPaymentMinorUnits;
  final DateTime? statementDate;
  final DateTime? paymentDueDate;
  final String? notes;
  final bool allowNegativeBalance;
  final int? creditLimitMinorUnits;
}

final class RecordIncomeInput {
  const RecordIncomeInput({
    required this.source,
    required this.accountId,
    required this.amountMinorUnits,
    required this.occurredAt,
    required this.idempotencyKey,
    this.category,
    this.notes,
  });

  final String source;
  final String accountId;
  final int amountMinorUnits;
  final DateTime occurredAt;
  final String idempotencyKey;
  final String? category;
  final String? notes;
}

final class RecordExpenseInput {
  const RecordExpenseInput({
    required this.title,
    required this.accountId,
    required this.amountMinorUnits,
    required this.occurredAt,
    required this.idempotencyKey,
    this.category,
    this.notes,
  });

  final String title;
  final String accountId;
  final int amountMinorUnits;
  final DateTime occurredAt;
  final String idempotencyKey;
  final String? category;
  final String? notes;
}

final class CreateCategoryInput {
  const CreateCategoryInput({
    required this.name,
    required this.categoryType,
    this.userId,
    this.isDefault = false,
  });

  final String? userId;
  final String name;
  final String categoryType;
  final bool isDefault;
}

final class CreateIncomeInput {
  const CreateIncomeInput({
    required this.source,
    required this.amountMinorUnits,
    required this.expectedDate,
    this.userId,
    this.sourceId,
    this.category,
    this.currencyCode = 'PHP',
    this.frequency = 'one_time',
    this.receivingAccountId,
    this.notes,
  });

  final String? userId;
  final String? sourceId;
  final String? category;
  final String source;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime expectedDate;
  final String frequency;
  final String? receivingAccountId;
  final String? notes;
}

final class UpdateIncomeInput {
  const UpdateIncomeInput({
    required this.incomeId,
    required this.source,
    required this.amountMinorUnits,
    required this.expectedDate,
    required this.frequency,
    this.category,
    this.receivingAccountId,
    this.notes,
  });

  final String incomeId;
  final String source;
  final int amountMinorUnits;
  final DateTime expectedDate;
  final String frequency;
  final String? category;
  final String? receivingAccountId;
  final String? notes;
}

final class CreateExpenseInput {
  const CreateExpenseInput({
    required this.title,
    required this.amountMinorUnits,
    required this.occurredAt,
    this.userId,
    this.currencyCode = 'PHP',
    this.categoryId,
    this.paymentAccountId,
    this.description,
    this.attachmentReference,
    this.recurrenceConfiguration,
  });

  final String? userId;
  final String title;
  final int amountMinorUnits;
  final String currencyCode;
  final String? categoryId;
  final DateTime occurredAt;
  final String? paymentAccountId;
  final String? description;
  final String? attachmentReference;
  final String? recurrenceConfiguration;
}

final class UpdateExpenseInput {
  const UpdateExpenseInput({
    required this.expenseId,
    required this.title,
    required this.amountMinorUnits,
    required this.occurredAt,
    this.currencyCode = 'PHP',
    this.categoryId,
    this.paymentAccountId,
    this.description,
    this.attachmentReference,
    this.recurrenceConfiguration,
  });

  final String expenseId;
  final String title;
  final int amountMinorUnits;
  final String currencyCode;
  final String? categoryId;
  final DateTime occurredAt;
  final String? paymentAccountId;
  final String? description;
  final String? attachmentReference;
  final String? recurrenceConfiguration;
}

final class CreateBillInput {
  const CreateBillInput({
    required this.name,
    required this.amountMinorUnits,
    required this.dueDate,
    this.userId,
    this.currencyCode = 'PHP',
    this.categoryId,
    this.frequency = 'one_time',
    this.paymentAccountId,
    this.reminderConfiguration,
    this.automaticAllocation = false,
    this.notes,
  });

  final String? userId;
  final String name;
  final String? categoryId;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime dueDate;
  final String frequency;
  final String? paymentAccountId;
  final String? reminderConfiguration;
  final bool automaticAllocation;
  final String? notes;
}

final class CreateLoanInput {
  const CreateLoanInput({
    required this.name,
    required this.providerName,
    required this.principalMinorUnits,
    required this.openedAt,
    this.userId,
    this.providerId,
    this.currencyCode = 'PHP',
    this.remainingBalanceMinorUnits,
    this.interestRateBasisPoints = 0,
    this.totalInterestMinorUnits = 0,
    this.endDate,
    this.durationMonths,
    this.paymentFrequency = 'monthly',
    this.installmentAmountMinorUnits = 0,
    this.totalInstallments = 0,
    this.paymentAccountId,
    this.notes,
  });

  final String? userId;
  final String name;
  final String providerName;
  final String? providerId;
  final int principalMinorUnits;
  final int? remainingBalanceMinorUnits;
  final int interestRateBasisPoints;
  final int totalInterestMinorUnits;
  final String currencyCode;
  final DateTime openedAt;
  final DateTime? endDate;
  final int? durationMonths;
  final String paymentFrequency;
  final int installmentAmountMinorUnits;
  final int totalInstallments;
  final String? paymentAccountId;
  final String? notes;
}

final class CreateInstallmentInput {
  const CreateInstallmentInput({
    required this.loanId,
    required this.installmentNumber,
    required this.dueDate,
    required this.scheduledAmountMinorUnits,
    this.userId,
    this.paymentAccountId,
    this.notes,
  });

  final String? userId;
  final String loanId;
  final int installmentNumber;
  final DateTime dueDate;
  final int scheduledAmountMinorUnits;
  final String? paymentAccountId;
  final String? notes;
}

final class CreateSavingsGoalInput {
  const CreateSavingsGoalInput({
    required this.name,
    required this.targetAmountMinorUnits,
    this.userId,
    this.currencyCode = 'PHP',
    this.targetDate,
    this.contributionSchedule,
    this.notes,
  });

  final String? userId;
  final String name;
  final int targetAmountMinorUnits;
  final String currencyCode;
  final DateTime? targetDate;
  final String? contributionSchedule;
  final String? notes;
}

final class CreatePaydayScheduleInput {
  const CreatePaydayScheduleInput({
    required this.name,
    required this.paydayDate,
    this.userId,
    this.expectedIncomeMinorUnits = 0,
    this.notes,
  });

  final String? userId;
  final String name;
  final DateTime paydayDate;
  final int expectedIncomeMinorUnits;
  final String? notes;
}

final class CreateAllocationInput {
  const CreateAllocationInput({
    required this.paydayScheduleId,
    required this.allocatedAmountMinorUnits,
    required this.allocationCategory,
    required this.allocationKey,
    this.userId,
    this.expectedIncomeMinorUnits = 0,
    this.actualIncomeMinorUnits = 0,
    this.relatedBillId,
    this.relatedInstallmentId,
    this.notes,
  });

  final String? userId;
  final String paydayScheduleId;
  final int expectedIncomeMinorUnits;
  final int actualIncomeMinorUnits;
  final int allocatedAmountMinorUnits;
  final String allocationCategory;
  final String? relatedBillId;
  final String? relatedInstallmentId;
  final String allocationKey;
  final String? notes;
}

final class ConfirmIncomeInput {
  const ConfirmIncomeInput({
    required this.incomeId,
    required this.accountId,
    required this.receivedAt,
    required this.idempotencyKey,
  });

  final String incomeId;
  final String accountId;
  final DateTime receivedAt;
  final String idempotencyKey;
}

final class ConfirmExpenseInput {
  const ConfirmExpenseInput({
    required this.expenseId,
    required this.accountId,
    required this.confirmedAt,
    required this.idempotencyKey,
  });

  final String expenseId;
  final String accountId;
  final DateTime confirmedAt;
  final String idempotencyKey;
}

final class BillPaymentInput {
  const BillPaymentInput({
    required this.billId,
    required this.accountId,
    required this.amountMinorUnits,
    required this.occurrenceKey,
    required this.paidAt,
    required this.idempotencyKey,
    this.notes,
  });

  final String billId;
  final String accountId;
  final int amountMinorUnits;
  final String occurrenceKey;
  final DateTime paidAt;
  final String idempotencyKey;
  final String? notes;
}

final class LoanPaymentInput {
  const LoanPaymentInput({
    required this.loanId,
    required this.installmentId,
    required this.accountId,
    required this.amountMinorUnits,
    required this.paidAt,
    required this.idempotencyKey,
    this.notes,
  });

  final String loanId;
  final String installmentId;
  final String accountId;
  final int amountMinorUnits;
  final DateTime paidAt;
  final String idempotencyKey;
  final String? notes;
}

final class TransferInput {
  const TransferInput({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinorUnits,
    required this.transferredAt,
    required this.idempotencyKey,
    this.feeMinorUnits = 0,
    this.notes,
  });

  final String fromAccountId;
  final String toAccountId;
  final int amountMinorUnits;
  final int feeMinorUnits;
  final DateTime transferredAt;
  final String idempotencyKey;
  final String? notes;
}

final class CreditPurchaseInput {
  const CreditPurchaseInput({
    required this.creditAccountId,
    required this.title,
    required this.amountMinorUnits,
    required this.occurredAt,
    required this.idempotencyKey,
    this.categoryId,
    this.notes,
  });

  final String creditAccountId;
  final String title;
  final int amountMinorUnits;
  final DateTime occurredAt;
  final String idempotencyKey;
  final String? categoryId;
  final String? notes;
}

final class CreditPaymentInput {
  const CreditPaymentInput({
    required this.cashAccountId,
    required this.creditAccountId,
    required this.amountMinorUnits,
    required this.paidAt,
    required this.idempotencyKey,
    this.notes,
  });

  final String cashAccountId;
  final String creditAccountId;
  final int amountMinorUnits;
  final DateTime paidAt;
  final String idempotencyKey;
  final String? notes;
}

final class ReconcileAccountInput {
  const ReconcileAccountInput({
    required this.accountId,
    required this.actualBalanceMinorUnits,
    required this.reconciledAt,
    required this.idempotencyKey,
    this.notes,
  });

  final String accountId;
  final int actualBalanceMinorUnits;
  final DateTime reconciledAt;
  final String idempotencyKey;
  final String? notes;
}

final class SavingsContributionInput {
  const SavingsContributionInput({
    required this.goalId,
    required this.accountId,
    required this.amountMinorUnits,
    required this.contributedAt,
    required this.idempotencyKey,
    this.notes,
  });

  final String goalId;
  final String accountId;
  final int amountMinorUnits;
  final DateTime contributedAt;
  final String idempotencyKey;
  final String? notes;
}
