final class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.name,
    required this.accountType,
    required this.currentBalanceMinorUnits,
    required this.currencyCode,
    required this.isActive,
    this.openingBalanceMinorUnits = 0,
    this.provider,
    this.creditLimitMinorUnits = 0,
    this.outstandingCreditMinorUnits = 0,
    this.openingOutstandingCreditMinorUnits = 0,
    this.statementBalanceMinorUnits = 0,
    this.minimumPaymentMinorUnits = 0,
    this.statementDate,
    this.paymentDueDate,
    this.accountNumberSuffix,
    this.linkedAccountId,
    this.customTypeName,
    this.iconKey,
    this.colorArgb,
    this.notes,
    this.allowNegativeBalance = false,
    this.archivedAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String accountType;
  final int currentBalanceMinorUnits;
  final String currencyCode;
  final bool isActive;
  final int openingBalanceMinorUnits;
  final String? provider;
  final int creditLimitMinorUnits;
  final int outstandingCreditMinorUnits;
  final int openingOutstandingCreditMinorUnits;
  final int statementBalanceMinorUnits;
  final int minimumPaymentMinorUnits;
  final DateTime? statementDate;
  final DateTime? paymentDueDate;
  final String? accountNumberSuffix;
  final String? linkedAccountId;
  final String? customTypeName;
  final String? iconKey;
  final int? colorArgb;
  final String? notes;
  final bool allowNegativeBalance;
  final DateTime? archivedAt;
  final DateTime? createdAt;
}

final class IncomeEntry {
  const IncomeEntry({
    required this.id,
    required this.source,
    this.category,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.expectedDate,
    required this.frequency,
    required this.status,
    this.actualReceivedAt,
    this.receivingAccountId,
    this.notes,
  });

  final String id;
  final String source;
  final String? category;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime expectedDate;
  final DateTime? actualReceivedAt;
  final String frequency;
  final String status;
  final String? receivingAccountId;
  final String? notes;
}

final class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.title,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredAt,
    required this.status,
    this.categoryId,
    this.paymentAccountId,
    this.description,
    this.attachmentReference,
    this.recurrenceConfiguration,
  });

  final String id;
  final String title;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime occurredAt;
  final String status;
  final String? categoryId;
  final String? paymentAccountId;
  final String? description;
  final String? attachmentReference;
  final String? recurrenceConfiguration;
}

final class BillEntry {
  const BillEntry({
    required this.id,
    required this.name,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.dueDate,
    required this.frequency,
    this.status = 'unpaid',
    required this.isActive,
    required this.automaticAllocation,
    this.categoryId,
    this.paymentAccountId,
    this.reminderConfiguration,
    this.notes,
  });

  final String id;
  final String name;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime dueDate;
  final String frequency;
  final String status;
  final bool isActive;
  final bool automaticAllocation;
  final String? categoryId;
  final String? paymentAccountId;
  final String? reminderConfiguration;
  final String? notes;
}

final class BillPaymentEntry {
  const BillPaymentEntry({
    required this.id,
    required this.billId,
    required this.accountId,
    required this.amountMinorUnits,
    required this.occurrenceKey,
    required this.paidAt,
    this.transactionId,
    this.reversedAt,
    this.notes,
  });

  final String id;
  final String billId;
  final String accountId;
  final int amountMinorUnits;
  final String occurrenceKey;
  final DateTime paidAt;
  final String? transactionId;
  final DateTime? reversedAt;
  final String? notes;

  bool get isSkipped => notes?.startsWith('[skipped]') ?? false;
}

final class LoanEntry {
  const LoanEntry({
    required this.id,
    required this.name,
    required this.providerName,
    required this.principalMinorUnits,
    required this.remainingBalanceMinorUnits,
    this.totalRepaymentMinorUnits = 0,
    required this.currencyCode,
    required this.openedAt,
    required this.status,
    this.providerId,
    this.interestRateBasisPoints = 0,
    this.totalInterestMinorUnits = 0,
    this.endDate,
    this.durationMonths,
    this.paymentFrequency = 'monthly',
    this.installmentAmountMinorUnits = 0,
    this.totalInstallments = 0,
    this.paidInstallments = 0,
    this.nextDueDate,
    this.paymentAccountId,
    this.notes,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String providerName;
  final String? providerId;
  final int principalMinorUnits;
  final int remainingBalanceMinorUnits;
  final int totalRepaymentMinorUnits;
  final int interestRateBasisPoints;
  final int totalInterestMinorUnits;
  final String currencyCode;
  final DateTime openedAt;
  final DateTime? endDate;
  final int? durationMonths;
  final String paymentFrequency;
  final int installmentAmountMinorUnits;
  final int totalInstallments;
  final int paidInstallments;
  final DateTime? nextDueDate;
  final String? paymentAccountId;
  final String status;
  final String? notes;
  final DateTime? archivedAt;
}

final class LoanInstallmentEntry {
  const LoanInstallmentEntry({
    required this.id,
    required this.loanId,
    required this.installmentNumber,
    required this.dueDate,
    required this.scheduledMinorUnits,
    required this.paidMinorUnits,
    required this.status,
    this.paidAt,
    this.paymentAccountId,
    this.transactionId,
    this.notes,
  });

  final String id;
  final String loanId;
  final int installmentNumber;
  final DateTime dueDate;
  final int scheduledMinorUnits;
  final int paidMinorUnits;
  final String status;
  final DateTime? paidAt;
  final String? paymentAccountId;
  final String? transactionId;
  final String? notes;
}

final class LoanPaymentEntry {
  const LoanPaymentEntry({
    required this.id,
    required this.loanId,
    required this.amountMinorUnits,
    required this.paidAt,
    required this.status,
    this.installmentId,
    this.accountId,
    this.transactionId,
    this.notes,
  });

  final String id;
  final String loanId;
  final String? installmentId;
  final String? accountId;
  final String? transactionId;
  final int amountMinorUnits;
  final DateTime paidAt;
  final String status;
  final String? notes;
}

final class SavingsGoalEntry {
  const SavingsGoalEntry({
    required this.id,
    required this.name,
    required this.targetAmountMinorUnits,
    required this.currentAmountMinorUnits,
    required this.currencyCode,
    required this.status,
    this.targetDate,
    this.contributionSchedule,
    this.notes,
  });

  final String id;
  final String name;
  final int targetAmountMinorUnits;
  final int currentAmountMinorUnits;
  final String currencyCode;
  final DateTime? targetDate;
  final String? contributionSchedule;
  final String status;
  final String? notes;
}

final class CategoryEntry {
  const CategoryEntry({
    required this.id,
    required this.name,
    required this.categoryType,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String categoryType;
  final bool isDefault;
}

final class PaydayScheduleEntry {
  const PaydayScheduleEntry({
    required this.id,
    required this.name,
    required this.paydayDate,
    required this.expectedIncomeMinorUnits,
    required this.actualIncomeMinorUnits,
    required this.status,
    this.notes,
    this.frequency = 'one_time',
    this.currencyCode = 'PHP',
    this.receivingAccountId,
    this.incomeRecordId,
    this.actualReceivedAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final DateTime paydayDate;
  final int expectedIncomeMinorUnits;
  final int actualIncomeMinorUnits;
  final String status;
  final String? notes;
  final String frequency;
  final String currencyCode;
  final String? receivingAccountId;
  final String? incomeRecordId;
  final DateTime? actualReceivedAt;
  final bool isActive;
}

final class AllocationEntry {
  const AllocationEntry({
    required this.id,
    required this.paydayScheduleId,
    required this.allocatedAmountMinorUnits,
    required this.allocationCategory,
    required this.status,
    this.expectedIncomeMinorUnits = 0,
    this.actualIncomeMinorUnits = 0,
    this.relatedBillId,
    this.relatedDueDate,
    this.relatedInstallmentId,
    this.relatedSavingsGoalId,
    this.periodDate,
    this.priority = 3,
    this.fulfilledAmountMinorUnits = 0,
    this.notes,
  });

  final String id;
  final String paydayScheduleId;
  final int expectedIncomeMinorUnits;
  final int actualIncomeMinorUnits;
  final int allocatedAmountMinorUnits;
  final String allocationCategory;
  final String? relatedBillId;
  final DateTime? relatedDueDate;
  final String? relatedInstallmentId;
  final String? relatedSavingsGoalId;
  final DateTime? periodDate;
  final int priority;
  final int fulfilledAmountMinorUnits;
  final String status;
  final String? notes;
}
