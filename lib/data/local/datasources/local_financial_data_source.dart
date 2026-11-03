import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/database/tables/bills.dart';
import 'package:bill_tracker/data/local/database/tables/categories.dart';
import 'package:bill_tracker/data/local/database/tables/financial_accounts.dart';
import 'package:bill_tracker/data/local/database/tables/income_expenses.dart';
import 'package:bill_tracker/data/local/database/tables/loans.dart';
import 'package:bill_tracker/data/local/database/tables/savings_and_allocations.dart';
import 'package:bill_tracker/data/local/database/tables/sync_queue.dart';
import 'package:bill_tracker/data/local/database/tables/transactions.dart';
import 'package:bill_tracker/data/sync/sync_queue.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Drift-backed source of truth for financial records and confirmed actions.
/// Every multi-record money operation is wrapped in a SQLite transaction.
class LocalFinancialDataSource {
  LocalFinancialDataSource(this._database);

  final AppDatabase _database;
  static const Uuid _uuid = Uuid();

  Stream<List<AccountBalance>> watchAccounts() =>
      (_database.select(_database.financialAccounts)
            ..where((FinancialAccounts row) => row.archivedAt.isNull())
            ..orderBy(<OrderingTerm Function(FinancialAccounts)>[
              (FinancialAccounts row) => OrderingTerm.asc(row.name),
            ]))
          .watch()
          .map(
            (List<FinancialAccountRecord> rows) =>
                rows.map(_accountSnapshot).toList(growable: false),
          );

  Stream<List<FinancialTransactionView>> watchTransactions() =>
      (_database.select(_database.transactions)
            ..where((Transactions row) => row.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function(Transactions)>[
              (Transactions row) => OrderingTerm.desc(row.occurredAt),
            ]))
          .watch()
          .map(
            (List<TransactionRecord> rows) =>
                rows.map(_transactionView).toList(growable: false),
          );

  Stream<List<FinancialTransactionView>> watchAccountTransactions(
    String accountId,
  ) =>
      (_database.select(_database.transactions)
            ..where(
              (Transactions row) =>
                  row.deletedAt.isNull() &
                  (row.accountId.equals(accountId) |
                      row.sourceAccountId.equals(accountId) |
                      row.destinationAccountId.equals(accountId)),
            )
            ..orderBy(<OrderingTerm Function(Transactions)>[
              (Transactions row) => OrderingTerm.desc(row.occurredAt),
            ]))
          .watch()
          .map(
            (List<TransactionRecord> rows) =>
                rows.map(_transactionView).toList(growable: false),
          );

  Stream<List<FinancialAccount>> watchFinancialAccounts() =>
      _watchFinancialAccounts(includeArchived: false);

  Stream<List<FinancialAccount>> watchAllFinancialAccounts() =>
      _watchFinancialAccounts(includeArchived: true);

  Stream<FinancialAccount?> watchFinancialAccount(String accountId) =>
      (_database.select(_database.financialAccounts)
            ..where((FinancialAccounts row) => row.id.equals(accountId)))
          .watchSingleOrNull()
          .map(
            (FinancialAccountRecord? row) =>
                row == null ? null : _financialAccountEntity(row),
          );

  Stream<List<FinancialAccount>> _watchFinancialAccounts({
    required bool includeArchived,
  }) =>
      (_database.select(_database.financialAccounts)
            ..where(
              (FinancialAccounts row) => includeArchived
                  ? const Constant(true)
                  : row.archivedAt.isNull(),
            )
            ..orderBy(<OrderingTerm Function(FinancialAccounts)>[
              (FinancialAccounts row) => OrderingTerm.asc(row.name),
            ]))
          .watch()
          .map(
            (List<FinancialAccountRecord> rows) =>
                rows.map(_financialAccountEntity).toList(growable: false),
          );

  Stream<List<IncomeEntry>> watchIncome() =>
      (_database
              .select(_database.incomeRecords)
              .join(<Join<HasResultSet, dynamic>>[
                leftOuterJoin(
                  _database.incomeSources,
                  _database.incomeRecords.sourceId.equalsExp(
                    _database.incomeSources.id,
                  ),
                ),
              ])
            ..where(_database.incomeRecords.deletedAt.isNull())
            ..orderBy(<OrderingTerm>[
              OrderingTerm.desc(_database.incomeRecords.expectedDate),
            ]))
          .watch()
          .map(
            (List<TypedResult> rows) => rows
                .map((TypedResult result) {
                  final IncomeRecord row = result.readTable(
                    _database.incomeRecords,
                  );
                  return IncomeEntry(
                    id: row.id,
                    source: row.source,
                    category: result
                        .readTableOrNull(_database.incomeSources)
                        ?.sourceType,
                    amountMinorUnits: row.amountMinorUnits,
                    currencyCode: row.currencyCode,
                    expectedDate: row.expectedDate,
                    actualReceivedAt: row.actualReceivedAt,
                    frequency: row.frequency,
                    status: row.status,
                    receivingAccountId: row.receivingAccountId,
                    notes: row.notes,
                  );
                })
                .toList(growable: false),
          );

  Stream<List<ExpenseEntry>> watchExpenses() =>
      (_database.select(_database.expenses)
            ..where((Expenses row) => row.deletedAt.isNull())
            ..orderBy(<OrderingTerm Function(Expenses)>[
              (Expenses row) => OrderingTerm.desc(row.occurredAt),
            ]))
          .watch()
          .map(
            (List<ExpenseRecord> rows) => rows
                .map(
                  (ExpenseRecord row) => ExpenseEntry(
                    id: row.id,
                    title: row.title,
                    amountMinorUnits: row.amountMinorUnits,
                    currencyCode: row.currencyCode,
                    occurredAt: row.occurredAt,
                    status: row.status,
                    categoryId: row.categoryId,
                    paymentAccountId: row.paymentAccountId,
                    description: row.description,
                    attachmentReference: row.attachmentReference,
                    recurrenceConfiguration: row.recurrenceConfiguration,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<BillEntry>> watchBills() =>
      (_database.select(_database.bills)
            ..where((Bills row) => row.archivedAt.isNull())
            ..orderBy(<OrderingTerm Function(Bills)>[
              (Bills row) => OrderingTerm.asc(row.dueDate),
            ]))
          .watch()
          .map(
            (List<BillRecord> rows) => rows
                .map(
                  (BillRecord row) => BillEntry(
                    id: row.id,
                    name: row.name,
                    amountMinorUnits: row.amountMinorUnits,
                    currencyCode: row.currencyCode,
                    dueDate: row.dueDate,
                    frequency: row.recurrenceRule ?? 'one_time',
                    status: row.status,
                    isActive: row.isActive,
                    automaticAllocation: row.automaticAllocation,
                    categoryId: row.categoryId,
                    paymentAccountId: row.accountId,
                    reminderConfiguration: row.reminderConfiguration,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<LoanEntry>> watchLoans() =>
      (_database.select(_database.loans)
            ..where((Loans row) => row.archivedAt.isNull())
            ..orderBy(<OrderingTerm Function(Loans)>[
              (Loans row) => OrderingTerm.asc(row.nextDueDate),
            ]))
          .watch()
          .map(
            (List<LoanRecord> rows) => rows
                .map(
                  (LoanRecord row) => LoanEntry(
                    id: row.id,
                    name: row.name,
                    providerName: row.providerName,
                    providerId: row.providerId,
                    principalMinorUnits: row.principalMinorUnits,
                    remainingBalanceMinorUnits: row.remainingBalanceMinorUnits,
                    interestRateBasisPoints: row.interestRateBasisPoints,
                    totalInterestMinorUnits: row.totalInterestMinorUnits,
                    currencyCode: row.currencyCode,
                    openedAt: row.openedAt,
                    endDate: row.endDate,
                    durationMonths: row.durationMonths,
                    paymentFrequency: row.paymentFrequency,
                    installmentAmountMinorUnits:
                        row.installmentAmountMinorUnits,
                    totalInstallments: row.totalInstallments,
                    paidInstallments: row.paidInstallments,
                    nextDueDate: row.nextDueDate,
                    paymentAccountId: row.paymentAccountId,
                    status: row.status,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<LoanInstallmentEntry>> watchInstallments(String loanId) =>
      (_database.select(_database.loanInstallments)
            ..where((LoanInstallments row) => row.loanId.equals(loanId))
            ..orderBy(<OrderingTerm Function(LoanInstallments)>[
              (LoanInstallments row) => OrderingTerm.asc(row.installmentNumber),
            ]))
          .watch()
          .map(
            (List<LoanInstallmentRecord> rows) => rows
                .map(
                  (LoanInstallmentRecord row) => LoanInstallmentEntry(
                    id: row.id,
                    loanId: row.loanId,
                    installmentNumber: row.installmentNumber,
                    dueDate: row.dueDate,
                    scheduledMinorUnits: row.scheduledMinorUnits,
                    paidMinorUnits: row.paidMinorUnits,
                    status: row.status,
                    paidAt: row.paidAt,
                    paymentAccountId: row.paymentAccountId,
                    transactionId: row.transactionId,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<LoanInstallmentEntry>> watchAllInstallments() =>
      (_database.select(_database.loanInstallments)
            ..orderBy(<OrderingTerm Function(LoanInstallments)>[
              (LoanInstallments row) => OrderingTerm.asc(row.dueDate),
            ]))
          .watch()
          .map(
            (List<LoanInstallmentRecord> rows) => rows
                .map(
                  (LoanInstallmentRecord row) => LoanInstallmentEntry(
                    id: row.id,
                    loanId: row.loanId,
                    installmentNumber: row.installmentNumber,
                    dueDate: row.dueDate,
                    scheduledMinorUnits: row.scheduledMinorUnits,
                    paidMinorUnits: row.paidMinorUnits,
                    status: row.status,
                    paidAt: row.paidAt,
                    paymentAccountId: row.paymentAccountId,
                    transactionId: row.transactionId,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<SavingsGoalEntry>> watchSavingsGoals() =>
      (_database.select(_database.savingsGoals)
            ..where((SavingsGoals row) => row.archivedAt.isNull())
            ..orderBy(<OrderingTerm Function(SavingsGoals)>[
              (SavingsGoals row) => OrderingTerm.asc(row.name),
            ]))
          .watch()
          .map(
            (List<SavingsGoalRecord> rows) => rows
                .map(
                  (SavingsGoalRecord row) => SavingsGoalEntry(
                    id: row.id,
                    name: row.name,
                    targetAmountMinorUnits: row.targetAmountMinorUnits,
                    currentAmountMinorUnits: row.currentAmountMinorUnits,
                    currencyCode: row.currencyCode,
                    targetDate: row.targetDate,
                    contributionSchedule: row.contributionSchedule,
                    status: row.status,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<CategoryEntry>> watchCategories({String? categoryType}) {
    final query = _database.select(_database.categories)
      ..where((Categories row) => row.archivedAt.isNull());
    if (categoryType != null) {
      query.where((Categories row) => row.categoryType.equals(categoryType));
    }
    return query.watch().map(
      (List<CategoryRecord> rows) => rows
          .map(
            (CategoryRecord row) => CategoryEntry(
              id: row.id,
              name: row.name,
              categoryType: row.categoryType,
              isDefault: row.isDefault,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<PaydayScheduleEntry>> watchPaydaySchedules() =>
      (_database.select(_database.paydaySchedules)
            ..where((PaydaySchedules row) => row.archivedAt.isNull())
            ..orderBy(<OrderingTerm Function(PaydaySchedules)>[
              (PaydaySchedules row) => OrderingTerm.asc(row.paydayDate),
            ]))
          .watch()
          .map(
            (List<PaydayScheduleRecord> rows) => rows
                .map(
                  (PaydayScheduleRecord row) => PaydayScheduleEntry(
                    id: row.id,
                    name: row.name,
                    paydayDate: row.paydayDate,
                    expectedIncomeMinorUnits: row.expectedIncomeMinorUnits,
                    actualIncomeMinorUnits: row.actualIncomeMinorUnits,
                    status: row.status,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Stream<List<AllocationEntry>> watchAllocations(String paydayScheduleId) =>
      (_database.select(_database.financialAllocations)..where(
            (FinancialAllocations row) =>
                row.paydayScheduleId.equals(paydayScheduleId),
          ))
          .watch()
          .map(
            (List<FinancialAllocationRecord> rows) => rows
                .map(
                  (FinancialAllocationRecord row) => AllocationEntry(
                    id: row.id,
                    paydayScheduleId: row.paydayScheduleId,
                    expectedIncomeMinorUnits: row.expectedIncomeMinorUnits,
                    actualIncomeMinorUnits: row.actualIncomeMinorUnits,
                    allocatedAmountMinorUnits: row.allocatedAmountMinorUnits,
                    allocationCategory: row.allocationCategory,
                    relatedBillId: row.relatedBillId,
                    relatedInstallmentId: row.relatedInstallmentId,
                    status: row.status,
                    notes: row.notes,
                  ),
                )
                .toList(growable: false),
          );

  Future<String> createAccount(CreateAccountInput input) async {
    _requireText(input.name, 'name');
    _requireAccountBalance(
      input.openingBalanceMinorUnits,
      input.accountType,
      input.allowNegativeBalance,
    );
    _requireNonNegative(input.creditLimitMinorUnits, 'creditLimit');
    _requireNonNegative(input.outstandingCreditMinorUnits, 'outstandingCredit');
    final int openingOutstanding =
        input.openingOutstandingCreditMinorUnits ??
        input.outstandingCreditMinorUnits;
    _requireNonNegative(openingOutstanding, 'openingOutstandingCredit');
    _requireNonNegative(input.statementBalanceMinorUnits, 'statementBalance');
    _requireNonNegative(input.minimumPaymentMinorUnits, 'minimumPayment');
    _requireText(input.accountType, 'accountType');
    _requireCurrency(input.currencyCode);
    _validateAccountNumberSuffix(input.accountNumberSuffix);
    const Set<String> allowedAccountTypes = <String>{
      'cash',
      'bank',
      'savings',
      'debit_card',
      'credit_card',
      'e_wallet',
      'gcash',
      'maya',
      'custom',
      'other',
    };
    if (!allowedAccountTypes.contains(input.accountType)) {
      throw ArgumentError.value(input.accountType, 'accountType');
    }
    if (input.allowNegativeBalance &&
        !<String>{'bank', 'custom', 'other'}.contains(input.accountType)) {
      throw ArgumentError(
        'Negative balances are available for bank and custom accounts.',
      );
    }
    if (_isCreditCard(input.accountType) &&
        input.openingBalanceMinorUnits != 0) {
      throw ArgumentError(
        'Credit card balances are recorded as outstanding credit.',
      );
    }
    if (openingOutstanding > input.creditLimitMinorUnits) {
      throw ArgumentError(
        'Opening outstanding credit cannot exceed the credit limit.',
      );
    }
    if (!_isCreditCard(input.accountType) &&
        (input.creditLimitMinorUnits != 0 ||
            input.outstandingCreditMinorUnits != 0 ||
            openingOutstanding != 0)) {
      throw ArgumentError(
        'Credit limits and outstanding credit belong to credit-card accounts.',
      );
    }
    if (_isCreditCard(input.accountType) && input.creditLimitMinorUnits <= 0) {
      throw ArgumentError('A credit card needs a positive credit limit.');
    }
    if (input.outstandingCreditMinorUnits > input.creditLimitMinorUnits) {
      throw ArgumentError('Outstanding credit cannot exceed the credit limit.');
    }
    if (!_isCreditCard(input.accountType) &&
        (input.statementBalanceMinorUnits != 0 ||
            input.minimumPaymentMinorUnits != 0 ||
            input.statementDate != null ||
            input.paymentDueDate != null)) {
      throw ArgumentError('Statement details belong to credit-card accounts.');
    }
    if (input.accountType != 'debit_card' && input.linkedAccountId != null) {
      throw ArgumentError('Only debit cards can link to a deposit account.');
    }
    if (input.linkedAccountId != null && input.openingBalanceMinorUnits != 0) {
      throw ArgumentError(
        'A linked debit card cannot hold a separate balance.',
      );
    }

    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      if (input.linkedAccountId != null) {
        final FinancialAccountRecord linkedAccount = await _account(
          input.linkedAccountId!,
        );
        _requireCashAccount(linkedAccount);
        if (linkedAccount.accountType == 'debit_card' ||
            linkedAccount.linkedAccountId != null) {
          throw ArgumentError('Link a debit card to a deposit account.');
        }
        _requireOwner(input.userId, linkedAccount.userId);
        _requireSameCurrency(input.currencyCode, linkedAccount.currencyCode);
      }
      await _database
          .into(_database.financialAccounts)
          .insert(
            FinancialAccountsCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              name: input.name.trim(),
              provider: Value<String?>(_trimOrNull(input.provider)),
              accountType: input.accountType,
              openingBalanceMinorUnits: input.openingBalanceMinorUnits,
              currentBalanceMinorUnits: Value<int>(
                input.openingBalanceMinorUnits,
              ),
              creditLimitMinorUnits: Value<int>(input.creditLimitMinorUnits),
              outstandingCreditMinorUnits: Value<int>(
                input.outstandingCreditMinorUnits,
              ),
              openingOutstandingCreditMinorUnits: Value<int>(
                openingOutstanding,
              ),
              currencyCode: Value<String>(input.currencyCode),
              statementDate: Value<DateTime?>(_asUtc(input.statementDate)),
              paymentDueDate: Value<DateTime?>(_asUtc(input.paymentDueDate)),
              statementBalanceMinorUnits: Value<int>(
                input.statementBalanceMinorUnits,
              ),
              minimumPaymentMinorUnits: Value<int>(
                input.minimumPaymentMinorUnits,
              ),
              accountNumberSuffix: Value<String?>(
                _trimOrNull(input.accountNumberSuffix),
              ),
              linkedAccountId: Value<String?>(input.linkedAccountId),
              customTypeName: Value<String?>(_trimOrNull(input.customTypeName)),
              iconKey: Value<String?>(_trimOrNull(input.iconKey)),
              colorArgb: Value<int?>(input.colorArgb),
              notes: Value<String?>(_trimOrNull(input.notes)),
              allowNegativeBalance: Value<bool>(input.allowNegativeBalance),
              isActive: const Value<bool>(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('financial_accounts', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'name': input.name.trim(),
        'provider': _trimOrNull(input.provider),
        'account_type': input.accountType,
        'opening_balance': _decimalAmount(input.openingBalanceMinorUnits),
        'current_balance': _decimalAmount(input.openingBalanceMinorUnits),
        'credit_limit': _decimalAmount(input.creditLimitMinorUnits),
        'outstanding_credit_balance': _decimalAmount(
          input.outstandingCreditMinorUnits,
        ),
        'opening_outstanding_credit_balance': _decimalAmount(
          openingOutstanding,
        ),
        'currency_code': input.currencyCode,
        'statement_date': _dateOnly(input.statementDate),
        'payment_due_date': _dateOnly(input.paymentDueDate),
        'statement_balance': _decimalAmount(input.statementBalanceMinorUnits),
        'minimum_payment': _decimalAmount(input.minimumPaymentMinorUnits),
        'account_number_suffix': _trimOrNull(input.accountNumberSuffix),
        'linked_account_id': input.linkedAccountId,
        'custom_type_name': _trimOrNull(input.customTypeName),
        'icon_key': _trimOrNull(input.iconKey),
        'color_argb': input.colorArgb,
        'notes': _trimOrNull(input.notes),
        'allow_negative_balance': input.allowNegativeBalance,
        'is_active': true,
      });
    });
    return id;
  }

  Future<void> updateAccount(
    UpdateAccountInput input,
  ) => _database.transaction(() async {
    final FinancialAccountRecord account = await _account(input.accountId);
    if (account.archivedAt != null) {
      throw StateError('Restore this account before editing it.');
    }
    _requireText(input.name, 'name');
    _requireNonNegative(input.statementBalanceMinorUnits, 'statementBalance');
    _requireNonNegative(input.minimumPaymentMinorUnits, 'minimumPayment');
    _validateAccountNumberSuffix(input.accountNumberSuffix);
    final bool isCard = _isCreditCard(account.accountType);
    final int creditLimit =
        input.creditLimitMinorUnits ?? account.creditLimitMinorUnits;
    if (isCard) {
      _requirePositive(creditLimit, 'creditLimit');
      if (creditLimit < account.outstandingCreditMinorUnits) {
        throw ArgumentError(
          'Credit limit cannot be lower than the current outstanding balance.',
        );
      }
    } else if (input.creditLimitMinorUnits != null ||
        input.statementBalanceMinorUnits != 0 ||
        input.minimumPaymentMinorUnits != 0 ||
        input.statementDate != null ||
        input.paymentDueDate != null) {
      throw ArgumentError('Credit details belong to credit-card accounts.');
    }
    if (!<String>{'bank', 'custom', 'other'}.contains(account.accountType) &&
        input.allowNegativeBalance) {
      throw ArgumentError(
        'Negative balances are available for bank and custom accounts.',
      );
    }
    if (!input.allowNegativeBalance && account.currentBalanceMinorUnits < 0) {
      throw StateError(
        'Set the balance to zero or allow a negative balance before disabling overdraft.',
      );
    }
    if (account.accountType != 'debit_card' && input.linkedAccountId != null) {
      throw ArgumentError('Only debit cards can link to a deposit account.');
    }
    if (account.accountType == 'debit_card' && input.linkedAccountId != null) {
      if (input.linkedAccountId == account.id) {
        throw ArgumentError('An account cannot link to itself.');
      }
      final FinancialAccountRecord linked = await _account(
        input.linkedAccountId!,
      );
      _requireCashAccount(linked);
      if (linked.accountType == 'debit_card' ||
          linked.linkedAccountId != null) {
        throw ArgumentError('Link a debit card to a deposit account.');
      }
      _requireOwner(account.userId, linked.userId);
      _requireSameCurrency(account.currencyCode, linked.currencyCode);
      if (account.currentBalanceMinorUnits != 0) {
        throw StateError(
          'Reconcile this debit card to zero before linking it to another account.',
        );
      }
    }
    final DateTime now = _now();
    final int nextVersion = account.localVersion + 1;
    await (_database.update(
      _database.financialAccounts,
    )..where((FinancialAccounts row) => row.id.equals(account.id))).write(
      FinancialAccountsCompanion(
        name: Value<String>(input.name.trim()),
        provider: Value<String?>(_trimOrNull(input.provider)),
        accountNumberSuffix: Value<String?>(
          _trimOrNull(input.accountNumberSuffix),
        ),
        linkedAccountId: Value<String?>(input.linkedAccountId),
        customTypeName: Value<String?>(_trimOrNull(input.customTypeName)),
        iconKey: Value<String?>(_trimOrNull(input.iconKey)),
        colorArgb: Value<int?>(input.colorArgb),
        statementBalanceMinorUnits: Value<int>(
          isCard ? input.statementBalanceMinorUnits : 0,
        ),
        minimumPaymentMinorUnits: Value<int>(
          isCard ? input.minimumPaymentMinorUnits : 0,
        ),
        creditLimitMinorUnits: Value<int>(creditLimit),
        statementDate: Value<DateTime?>(
          isCard ? _asUtc(input.statementDate) : null,
        ),
        paymentDueDate: Value<DateTime?>(
          isCard ? _asUtc(input.paymentDueDate) : null,
        ),
        notes: Value<String?>(_trimOrNull(input.notes)),
        allowNegativeBalance: Value<bool>(input.allowNegativeBalance),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(nextVersion),
        syncState: const Value<String>('pending'),
      ),
    );
    await _enqueue('financial_accounts', account.id, <String, Object?>{
      ..._accountSyncPayload(account),
      'name': input.name.trim(),
      'provider': _trimOrNull(input.provider),
      'account_number_suffix': _trimOrNull(input.accountNumberSuffix),
      'linked_account_id': input.linkedAccountId,
      'custom_type_name': _trimOrNull(input.customTypeName),
      'icon_key': _trimOrNull(input.iconKey),
      'color_argb': input.colorArgb,
      'credit_limit': _decimalAmount(creditLimit),
      'statement_balance': _decimalAmount(
        isCard ? input.statementBalanceMinorUnits : 0,
      ),
      'minimum_payment': _decimalAmount(
        isCard ? input.minimumPaymentMinorUnits : 0,
      ),
      'statement_date': _dateOnly(isCard ? input.statementDate : null),
      'payment_due_date': _dateOnly(isCard ? input.paymentDueDate : null),
      'allow_negative_balance': input.allowNegativeBalance,
      'notes': _trimOrNull(input.notes),
    });
  });

  Future<void> setAccountActive(String accountId, bool isActive) =>
      _database.transaction(() async {
        final FinancialAccountRecord account = await _account(accountId);
        if (account.archivedAt != null) {
          throw StateError('Restore this account before activating it.');
        }
        if (account.isActive == isActive) return;
        final DateTime now = _now();
        await (_database.update(
          _database.financialAccounts,
        )..where((FinancialAccounts row) => row.id.equals(accountId))).write(
          FinancialAccountsCompanion(
            isActive: Value<bool>(isActive),
            updatedAt: Value<DateTime>(now),
            localVersion: Value<int>(account.localVersion + 1),
            syncState: const Value<String>('pending'),
          ),
        );
        await _enqueue('financial_accounts', accountId, <String, Object?>{
          ..._accountSyncPayload(account),
          'is_active': isActive,
        });
      });

  Future<void> archiveAccount(String accountId) =>
      _database.transaction(() async {
        final FinancialAccountRecord account = await _account(accountId);
        if (account.archivedAt != null) return;
        final DateTime now = _now();
        await (_database.update(
          _database.financialAccounts,
        )..where((FinancialAccounts row) => row.id.equals(accountId))).write(
          FinancialAccountsCompanion(
            isActive: const Value<bool>(false),
            archivedAt: Value<DateTime?>(now),
            updatedAt: Value<DateTime>(now),
            localVersion: Value<int>(account.localVersion + 1),
            syncState: const Value<String>('pending'),
          ),
        );
        await _enqueue('financial_accounts', accountId, <String, Object?>{
          ..._accountSyncPayload(account),
          'is_active': false,
          'archived_at': now.toIso8601String(),
        });
      });

  Future<void> restoreAccount(String accountId) =>
      _database.transaction(() async {
        final FinancialAccountRecord account = await _account(accountId);
        if (account.archivedAt == null) return;
        final DateTime now = _now();
        await (_database.update(
          _database.financialAccounts,
        )..where((FinancialAccounts row) => row.id.equals(accountId))).write(
          FinancialAccountsCompanion(
            isActive: const Value<bool>(true),
            archivedAt: const Value<DateTime?>(null),
            updatedAt: Value<DateTime>(now),
            localVersion: Value<int>(account.localVersion + 1),
            syncState: const Value<String>('pending'),
          ),
        );
        await _enqueue('financial_accounts', accountId, <String, Object?>{
          ..._accountSyncPayload(account),
          'is_active': true,
          'archived_at': null,
        });
      });

  Future<void> deleteAccount(
    String accountId,
  ) => _database.transaction(() async {
    await _account(accountId);
    if (await _accountHasFinancialHistory(accountId)) {
      throw StateError(
        'This account has financial history. Archive it to keep its records.',
      );
    }
    if (await _accountHasLinkedOperations(accountId)) {
      throw StateError(
        'This account is linked to planned financial records and cannot be deleted.',
      );
    }
    await (_database.delete(
      _database.financialAccounts,
    )..where((FinancialAccounts row) => row.id.equals(accountId))).go();
    await (_database.delete(_database.syncQueue)..where(
          (SyncQueue row) =>
              row.entityType.equals('financial_accounts') &
              row.entityId.equals(accountId),
        ))
        .go();
  });

  Future<bool> _accountHasFinancialHistory(String accountId) async =>
      (await (_database.select(_database.transactions)..where(
            (Transactions row) =>
                row.accountId.equals(accountId) |
                row.sourceAccountId.equals(accountId) |
                row.destinationAccountId.equals(accountId),
          ))
          .getSingleOrNull()) !=
      null;

  Future<bool> _accountHasLinkedOperations(String accountId) async {
    final bool linkedDebit =
        await (_database.select(_database.financialAccounts)..where(
              (FinancialAccounts row) => row.linkedAccountId.equals(accountId),
            ))
            .getSingleOrNull() !=
        null;
    if (linkedDebit) return true;
    if (await (_database.select(_database.incomeRecords)..where(
              (IncomeRecords row) => row.receivingAccountId.equals(accountId),
            ))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    if (await (_database.select(_database.expenses)
              ..where((Expenses row) => row.paymentAccountId.equals(accountId)))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    if (await (_database.select(_database.bills)
              ..where((Bills row) => row.accountId.equals(accountId)))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    if (await (_database.select(_database.loanPayments)
              ..where((LoanPayments row) => row.accountId.equals(accountId)))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    if (await (_database.select(_database.loanInstallments)..where(
              (LoanInstallments row) => row.paymentAccountId.equals(accountId),
            ))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    if (await (_database.select(_database.savingsContributions)..where(
              (SavingsContributions row) => row.accountId.equals(accountId),
            ))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    if (await (_database.select(_database.accountTransfers)..where(
              (AccountTransfers row) =>
                  row.fromAccountId.equals(accountId) |
                  row.toAccountId.equals(accountId),
            ))
            .getSingleOrNull() !=
        null) {
      return true;
    }
    return false;
  }

  Future<String> createCategory(CreateCategoryInput input) async {
    _requireText(input.name, 'name');
    _requireText(input.categoryType, 'categoryType');
    const Set<String> allowedCategoryTypes = <String>{
      'income',
      'expense',
      'bill',
      'loan',
      'other',
    };
    if (!allowedCategoryTypes.contains(input.categoryType)) {
      throw ArgumentError.value(input.categoryType, 'categoryType');
    }
    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              name: input.name.trim(),
              categoryType: input.categoryType,
              isDefault: Value<bool>(input.isDefault),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('categories', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'name': input.name.trim(),
        'category_type': input.categoryType,
      });
    });
    return id;
  }

  Future<String> createIncome(CreateIncomeInput input) async {
    _requireText(input.source, 'source');
    _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
    _requireCurrency(input.currencyCode);
    _requireFrequency(input.frequency);
    if (input.receivingAccountId != null) {
      final FinancialAccountRecord account = await _account(
        input.receivingAccountId!,
      );
      _requireOwner(input.userId, account.userId);
      _requireActiveAccount(account);
      _requireSameCurrency(input.currencyCode, account.currencyCode);
      if (_isCreditCard(account.accountType)) {
        throw ArgumentError('Income cannot be received into a credit card.');
      }
    }

    final DateTime now = _now();
    final String id = _uuid.v4();
    final String? sourceId = input.category == null
        ? input.sourceId
        : _uuid.v4();
    await _database.transaction(() async {
      if (input.category != null) {
        await _database
            .into(_database.incomeSources)
            .insert(
              IncomeSourcesCompanion.insert(
                id: sourceId!,
                userId: Value<String?>(input.userId),
                name: input.source.trim(),
                sourceType: Value<String>(input.category!.trim()),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      await _database
          .into(_database.incomeRecords)
          .insert(
            IncomeRecordsCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              sourceId: Value<String?>(sourceId),
              source: input.source.trim(),
              amountMinorUnits: input.amountMinorUnits,
              currencyCode: Value<String>(input.currencyCode),
              expectedDate: _asUtcDate(input.expectedDate),
              frequency: Value<String>(input.frequency),
              receivingAccountId: Value<String?>(input.receivingAccountId),
              status: const Value<String>('expected'),
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('income_records', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'income_source_id': sourceId,
        'source_name': input.source.trim(),
        'source_type': input.category,
        'amount': _decimalAmount(input.amountMinorUnits),
        'currency_code': input.currencyCode,
        'expected_date': _dateOnly(input.expectedDate),
        'frequency': input.frequency,
        'receiving_account_id': input.receivingAccountId,
        'status': 'expected',
        'notes': _trimOrNull(input.notes),
      });
    });
    return id;
  }

  Future<void> updateIncome(UpdateIncomeInput input) async {
    _requireText(input.source, 'source');
    _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
    _requireFrequency(input.frequency);
    await _database.transaction(() async {
      final IncomeRecord record =
          await (_database.select(_database.incomeRecords)
                ..where((IncomeRecords row) => row.id.equals(input.incomeId)))
              .getSingle();
      if (record.status != 'expected' || record.transactionId != null) {
        throw StateError('Only expected income can be edited.');
      }
      if (input.receivingAccountId != null) {
        final FinancialAccountRecord account = await _account(
          input.receivingAccountId!,
        );
        _requireOwner(record.userId, account.userId);
        _requireActiveAccount(account);
        _requireSameCurrency(record.currencyCode, account.currencyCode);
        if (_isCreditCard(account.accountType)) {
          throw ArgumentError('Income cannot be received into a credit card.');
        }
      }
      final DateTime now = _now();
      String? sourceId = record.sourceId;
      if (sourceId == null && input.category != null) {
        sourceId = _uuid.v4();
        await _database
            .into(_database.incomeSources)
            .insert(
              IncomeSourcesCompanion.insert(
                id: sourceId,
                userId: Value<String?>(record.userId),
                name: input.source.trim(),
                sourceType: Value<String>(input.category!.trim()),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else if (sourceId != null) {
        await (_database.update(
          _database.incomeSources,
        )..where((IncomeSources row) => row.id.equals(record.sourceId!))).write(
          IncomeSourcesCompanion(
            name: Value<String>(input.source.trim()),
            sourceType: Value<String>(input.category ?? 'other'),
            updatedAt: Value<DateTime>(now),
          ),
        );
      }
      await (_database.update(
        _database.incomeRecords,
      )..where((IncomeRecords row) => row.id.equals(record.id))).write(
        IncomeRecordsCompanion(
          sourceId: Value<String?>(sourceId),
          source: Value<String>(input.source.trim()),
          amountMinorUnits: Value<int>(input.amountMinorUnits),
          expectedDate: Value<DateTime>(_asUtcDate(input.expectedDate)),
          frequency: Value<String>(input.frequency),
          receivingAccountId: Value<String?>(input.receivingAccountId),
          notes: Value<String?>(_trimOrNull(input.notes)),
          updatedAt: Value<DateTime>(now),
          localVersion: Value<int>(record.localVersion + 1),
        ),
      );
      await _enqueue('income_records', record.id, <String, Object?>{
        'id': record.id,
        'source_name': input.source.trim(),
        'source_type': input.category,
        'amount': _decimalAmount(input.amountMinorUnits),
        'expected_date': _dateOnly(input.expectedDate),
        'frequency': input.frequency,
        'receiving_account_id': input.receivingAccountId,
        'notes': _trimOrNull(input.notes),
        'status': 'expected',
      });
    });
  }

  Future<void> cancelIncome(String incomeId) async {
    await _database.transaction(() async {
      final IncomeRecord record = await (_database.select(
        _database.incomeRecords,
      )..where((IncomeRecords row) => row.id.equals(incomeId))).getSingle();
      if (record.status != 'expected' || record.transactionId != null) {
        throw StateError('Only expected income can be cancelled.');
      }
      final DateTime now = _now();
      await (_database.update(
        _database.incomeRecords,
      )..where((IncomeRecords row) => row.id.equals(record.id))).write(
        IncomeRecordsCompanion(
          status: const Value<String>('cancelled'),
          updatedAt: Value<DateTime>(now),
          localVersion: Value<int>(record.localVersion + 1),
        ),
      );
      await _enqueue('income_records', record.id, <String, Object?>{
        'id': record.id,
        'status': 'cancelled',
      });
    });
  }

  Future<String> createExpense(CreateExpenseInput input) async {
    _requireText(input.title, 'title');
    _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
    _requireCurrency(input.currencyCode);
    if (input.paymentAccountId != null) {
      final FinancialAccountRecord account = await _account(
        input.paymentAccountId!,
      );
      _requireOwner(input.userId, account.userId);
      if (!_isCreditCard(account.accountType)) _requireCashAccount(account);
      _requireSameCurrency(input.currencyCode, account.currencyCode);
    }

    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              title: input.title.trim(),
              amountMinorUnits: input.amountMinorUnits,
              currencyCode: Value<String>(input.currencyCode),
              categoryId: Value<String?>(input.categoryId),
              occurredAt: input.occurredAt.toUtc(),
              paymentAccountId: Value<String?>(input.paymentAccountId),
              description: Value<String?>(_trimOrNull(input.description)),
              attachmentReference: Value<String?>(input.attachmentReference),
              recurrenceConfiguration: Value<String?>(
                input.recurrenceConfiguration,
              ),
              status: const Value<String>('planned'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('expenses', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'title': input.title.trim(),
        'amount': _decimalAmount(input.amountMinorUnits),
        'currency_code': input.currencyCode,
        'financial_category_id': input.categoryId,
        'account_id': input.paymentAccountId,
        'spent_at': input.occurredAt.toUtc().toIso8601String(),
        'notes': _trimOrNull(input.description),
        'attachment_reference': input.attachmentReference,
        'recurrence_configuration': input.recurrenceConfiguration,
        'status': 'planned',
      });
    });
    return id;
  }

  Future<void> updateExpense(UpdateExpenseInput input) async {
    _requireText(input.title, 'title');
    _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
    _requireCurrency(input.currencyCode);
    await _database.transaction(() async {
      final ExpenseRecord record = await (_database.select(
        _database.expenses,
      )..where((Expenses row) => row.id.equals(input.expenseId))).getSingle();
      if (record.status != 'planned' || record.transactionId != null) {
        throw StateError('Only planned expenses can be edited.');
      }
      if (input.paymentAccountId != null) {
        final FinancialAccountRecord account = await _account(
          input.paymentAccountId!,
        );
        _requireOwner(record.userId, account.userId);
        _requireSameCurrency(input.currencyCode, account.currencyCode);
        if (!_isCreditCard(account.accountType)) _requireCashAccount(account);
      }
      final DateTime now = _now();
      await (_database.update(
        _database.expenses,
      )..where((Expenses row) => row.id.equals(record.id))).write(
        ExpensesCompanion(
          title: Value<String>(input.title.trim()),
          amountMinorUnits: Value<int>(input.amountMinorUnits),
          currencyCode: Value<String>(input.currencyCode),
          categoryId: Value<String?>(input.categoryId),
          occurredAt: Value<DateTime>(input.occurredAt.toUtc()),
          paymentAccountId: Value<String?>(input.paymentAccountId),
          description: Value<String?>(_trimOrNull(input.description)),
          attachmentReference: Value<String?>(input.attachmentReference),
          recurrenceConfiguration: Value<String?>(
            input.recurrenceConfiguration,
          ),
          updatedAt: Value<DateTime>(now),
        ),
      );
      await _enqueue('expenses', record.id, <String, Object?>{
        'id': record.id,
        'title': input.title.trim(),
        'amount': _decimalAmount(input.amountMinorUnits),
        'currency_code': input.currencyCode,
        'financial_category_id': input.categoryId,
        'account_id': input.paymentAccountId,
        'spent_at': input.occurredAt.toUtc().toIso8601String(),
        'notes': _trimOrNull(input.description),
        'attachment_reference': input.attachmentReference,
        'recurrence_configuration': input.recurrenceConfiguration,
        'status': 'planned',
      });
    });
  }

  Future<void> cancelExpense(String expenseId) async {
    await _database.transaction(() async {
      final ExpenseRecord record = await (_database.select(
        _database.expenses,
      )..where((Expenses row) => row.id.equals(expenseId))).getSingle();
      if (record.status != 'planned' || record.transactionId != null) {
        throw StateError('Only planned expenses can be cancelled.');
      }
      final DateTime now = _now();
      await (_database.update(
        _database.expenses,
      )..where((Expenses row) => row.id.equals(record.id))).write(
        ExpensesCompanion(
          status: const Value<String>('cancelled'),
          updatedAt: Value<DateTime>(now),
        ),
      );
      await _enqueue('expenses', record.id, <String, Object?>{
        'id': record.id,
        'status': 'cancelled',
      });
    });
  }

  Future<String> createBill(CreateBillInput input) async {
    _requireText(input.name, 'name');
    _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
    _requireCurrency(input.currencyCode);
    _requireFrequency(input.frequency);
    if (input.paymentAccountId != null) {
      final FinancialAccountRecord account = await _account(
        input.paymentAccountId!,
      );
      _requireOwner(input.userId, account.userId);
      _requireCashAccount(account);
      _requireSameCurrency(input.currencyCode, account.currencyCode);
    }

    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.bills)
          .insert(
            BillsCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              name: input.name.trim(),
              categoryId: Value<String?>(input.categoryId),
              amountMinorUnits: input.amountMinorUnits,
              currencyCode: Value<String>(input.currencyCode),
              dueDate: _asUtcDate(input.dueDate),
              recurrenceRule: Value<String?>(input.frequency),
              accountId: Value<String?>(input.paymentAccountId),
              reminderConfiguration: Value<String?>(
                input.reminderConfiguration,
              ),
              automaticAllocation: Value<bool>(input.automaticAllocation),
              isActive: const Value<bool>(true),
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('bills', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'name': input.name.trim(),
        'financial_category_id': input.categoryId,
        'amount': _decimalAmount(input.amountMinorUnits),
        'currency_code': input.currencyCode,
        'due_date': _dateOnly(input.dueDate),
        'recurrence_rule': input.frequency,
        'account_id': input.paymentAccountId,
        'reminder_configuration': input.reminderConfiguration,
        'automatic_allocation': input.automaticAllocation,
        'is_active': true,
        'notes': _trimOrNull(input.notes),
      });
    });
    return id;
  }

  Future<String> createLoan(CreateLoanInput input) async {
    _requireText(input.name, 'name');
    _requireText(input.providerName, 'providerName');
    _requirePositive(input.principalMinorUnits, 'principalMinorUnits');
    _requireNonNegative(
      input.remainingBalanceMinorUnits ?? input.principalMinorUnits,
      'remainingBalanceMinorUnits',
    );
    if ((input.remainingBalanceMinorUnits ?? input.principalMinorUnits) >
        input.principalMinorUnits) {
      throw ArgumentError(
        'Remaining balance cannot exceed original principal.',
      );
    }
    _requireNonNegative(
      input.interestRateBasisPoints,
      'interestRateBasisPoints',
    );
    _requireNonNegative(
      input.totalInterestMinorUnits,
      'totalInterestMinorUnits',
    );
    _requireNonNegative(
      input.installmentAmountMinorUnits,
      'installmentAmountMinorUnits',
    );
    _requireNonNegative(input.totalInstallments, 'totalInstallments');
    _requireCurrency(input.currencyCode);
    _requireLoanFrequency(input.paymentFrequency);

    if (input.paymentAccountId != null) {
      final FinancialAccountRecord account = await _account(
        input.paymentAccountId!,
      );
      _requireOwner(input.userId, account.userId);
      _requireCashAccount(account);
      _requireSameCurrency(input.currencyCode, account.currencyCode);
    }

    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      final String providerId = await _ensureLoanProvider(
        input.providerId,
        input.providerName.trim(),
        input.userId,
        now,
      );
      await _database
          .into(_database.loans)
          .insert(
            LoansCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              providerName: input.providerName.trim(),
              providerId: Value<String?>(providerId),
              name: input.name.trim(),
              principalMinorUnits: input.principalMinorUnits,
              remainingBalanceMinorUnits: Value<int>(
                input.remainingBalanceMinorUnits ?? input.principalMinorUnits,
              ),
              interestRateBasisPoints: Value<int>(
                input.interestRateBasisPoints,
              ),
              totalInterestMinorUnits: Value<int>(
                input.totalInterestMinorUnits,
              ),
              currencyCode: Value<String>(input.currencyCode),
              openedAt: _asUtcDate(input.openedAt),
              endDate: Value<DateTime?>(_asUtc(input.endDate)),
              durationMonths: Value<int?>(input.durationMonths),
              paymentFrequency: Value<String>(input.paymentFrequency),
              installmentAmountMinorUnits: Value<int>(
                input.installmentAmountMinorUnits,
              ),
              totalInstallments: Value<int>(input.totalInstallments),
              paymentAccountId: Value<String?>(input.paymentAccountId),
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('loans', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'provider_id': providerId,
        'provider_name': input.providerName.trim(),
        'name': input.name.trim(),
        'principal_amount': _decimalAmount(input.principalMinorUnits),
        'remaining_balance': _decimalAmount(
          input.remainingBalanceMinorUnits ?? input.principalMinorUnits,
        ),
        'interest_rate_basis_points': input.interestRateBasisPoints,
        'interest_rate_percent': input.interestRateBasisPoints / 100,
        'total_interest': _decimalAmount(input.totalInterestMinorUnits),
        'currency_code': input.currencyCode,
        'opened_at': _dateOnly(input.openedAt),
        'end_date': _dateOnly(input.endDate),
        'duration_months': input.durationMonths,
        'payment_frequency': input.paymentFrequency,
        'installment_amount': _decimalAmount(input.installmentAmountMinorUnits),
        'total_installments': input.totalInstallments,
        'paid_installments': 0,
        'payment_account_id': input.paymentAccountId,
        'status': 'active',
        'notes': _trimOrNull(input.notes),
      });
    });
    return id;
  }

  Future<String> createInstallment(CreateInstallmentInput input) async {
    if (input.installmentNumber <= 0) {
      throw ArgumentError.value(input.installmentNumber, 'installmentNumber');
    }
    _requirePositive(input.scheduledAmountMinorUnits, 'scheduledAmount');
    final LoanRecord loan = await _loan(input.loanId);
    _requireOwner(input.userId, loan.userId);
    if (loan.status != 'active') {
      throw StateError('Installments can only be added to active loans.');
    }
    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.loanInstallments)
          .insert(
            LoanInstallmentsCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId ?? loan.userId),
              loanId: input.loanId,
              installmentNumber: input.installmentNumber,
              dueDate: _asUtcDate(input.dueDate),
              scheduledMinorUnits: input.scheduledAmountMinorUnits,
              paymentAccountId: Value<String?>(input.paymentAccountId),
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('loan_installments', id, <String, Object?>{
        'id': id,
        'user_id': input.userId ?? loan.userId,
        'loan_id': input.loanId,
        'installment_number': input.installmentNumber,
        'due_date': _dateOnly(input.dueDate),
        'scheduled_amount': _decimalAmount(input.scheduledAmountMinorUnits),
        'paid_amount': '0.00',
        'status': 'unpaid',
        'payment_account_id': input.paymentAccountId,
        'notes': _trimOrNull(input.notes),
      });
      final DateTime? nextDue = loan.nextDueDate;
      if (nextDue == null || input.dueDate.isBefore(nextDue)) {
        await (_database.update(
          _database.loans,
        )..where((Loans row) => row.id.equals(input.loanId))).write(
          LoansCompanion(
            nextDueDate: Value<DateTime>(_asUtcDate(input.dueDate)),
            updatedAt: Value<DateTime>(now),
            localVersion: Value<int>(loan.localVersion + 1),
          ),
        );
        await _enqueue('loans', loan.id, <String, Object?>{
          'id': loan.id,
          'next_due_date': _dateOnly(input.dueDate),
        });
      }
    });
    return id;
  }

  Future<String> createSavingsGoal(CreateSavingsGoalInput input) async {
    _requireText(input.name, 'name');
    _requirePositive(input.targetAmountMinorUnits, 'targetAmountMinorUnits');
    _requireCurrency(input.currencyCode);
    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              name: input.name.trim(),
              targetAmountMinorUnits: input.targetAmountMinorUnits,
              currencyCode: Value<String>(input.currencyCode),
              targetDate: Value<DateTime?>(_asUtc(input.targetDate)),
              contributionSchedule: Value<String?>(input.contributionSchedule),
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('savings_goals', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'name': input.name.trim(),
        'target_amount': _decimalAmount(input.targetAmountMinorUnits),
        'current_amount': '0.00',
        'currency_code': input.currencyCode,
        'target_date': _dateOnly(input.targetDate),
        'contribution_schedule': input.contributionSchedule,
        'status': 'active',
        'notes': _trimOrNull(input.notes),
      });
    });
    return id;
  }

  Future<String> createPaydaySchedule(CreatePaydayScheduleInput input) async {
    _requireText(input.name, 'name');
    _requireNonNegative(input.expectedIncomeMinorUnits, 'expectedIncome');
    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.paydaySchedules)
          .insert(
            PaydaySchedulesCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId),
              name: input.name.trim(),
              paydayDate: _asUtcDate(input.paydayDate),
              expectedIncomeMinorUnits: Value<int>(
                input.expectedIncomeMinorUnits,
              ),
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('payday_schedules', id, <String, Object?>{
        'id': id,
        'user_id': input.userId,
        'name': input.name.trim(),
        'payday_date': _dateOnly(input.paydayDate),
        'frequency': 'one_time',
        'next_payday': _dateOnly(input.paydayDate),
        'expected_amount': _decimalAmount(input.expectedIncomeMinorUnits),
        'actual_income': '0.00',
        'currency_code': 'PHP',
        'status': 'planned',
        'notes': _trimOrNull(input.notes),
      });
    });
    return id;
  }

  Future<String> createAllocation(CreateAllocationInput input) async {
    _requireNonNegative(input.expectedIncomeMinorUnits, 'expectedIncome');
    _requireNonNegative(input.actualIncomeMinorUnits, 'actualIncome');
    _requireNonNegative(input.allocatedAmountMinorUnits, 'allocatedAmount');
    _requireText(input.allocationCategory, 'allocationCategory');
    final PaydayScheduleRecord schedule =
        await (_database.select(_database.paydaySchedules)..where(
              (PaydaySchedules row) =>
                  row.id.equals(input.paydayScheduleId) &
                  row.archivedAt.isNull(),
            ))
            .getSingle();
    _requireOwner(input.userId, schedule.userId);
    final String allocationKey = _allocationKey(input);
    final FinancialAllocationRecord? duplicate =
        await (_database.select(_database.financialAllocations)..where(
              (FinancialAllocations row) =>
                  row.allocationKey.equals(allocationKey),
            ))
            .getSingleOrNull();
    if (duplicate != null) return duplicate.id;

    final DateTime now = _now();
    final String id = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.financialAllocations)
          .insert(
            FinancialAllocationsCompanion.insert(
              id: id,
              userId: Value<String?>(input.userId ?? schedule.userId),
              paydayScheduleId: input.paydayScheduleId,
              expectedIncomeMinorUnits: Value<int>(
                input.expectedIncomeMinorUnits,
              ),
              actualIncomeMinorUnits: Value<int>(input.actualIncomeMinorUnits),
              allocatedAmountMinorUnits: input.allocatedAmountMinorUnits,
              allocationCategory: input.allocationCategory,
              relatedBillId: Value<String?>(input.relatedBillId),
              relatedInstallmentId: Value<String?>(input.relatedInstallmentId),
              allocationKey: allocationKey,
              notes: Value<String?>(_trimOrNull(input.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue('financial_allocations', id, <String, Object?>{
        'id': id,
        'user_id': input.userId ?? schedule.userId,
        'payday_schedule_id': input.paydayScheduleId,
        'expected_income': _decimalAmount(input.expectedIncomeMinorUnits),
        'actual_income': _decimalAmount(input.actualIncomeMinorUnits),
        'amount': _decimalAmount(input.allocatedAmountMinorUnits),
        'allocation_type': input.allocationCategory,
        'allocation_category': input.allocationCategory,
        'related_bill_id': input.relatedBillId,
        'related_installment_id': input.relatedInstallmentId,
        'target_record_id': input.relatedBillId ?? input.relatedInstallmentId,
        'allocation_key': allocationKey,
        'status': 'planned',
        'notes': _trimOrNull(input.notes),
      });
    });
    return id;
  }

  Future<String> confirmIncome(ConfirmIncomeInput input) =>
      _database.transaction(() async {
        final TransactionRecord? duplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'income',
        );
        if (duplicate != null) return duplicate.id;

        final IncomeRecord income =
            await (_database.select(_database.incomeRecords)..where(
                  (IncomeRecords row) =>
                      row.id.equals(input.incomeId) & row.deletedAt.isNull(),
                ))
                .getSingle();
        if (income.status == 'received' && income.transactionId != null) {
          return income.transactionId!;
        }
        if (income.status != 'expected') {
          throw StateError('Only expected income can be confirmed.');
        }
        final FinancialAccountRecord account = await _account(input.accountId);
        _requireOwner(income.userId, account.userId);
        _requireSameCurrency(income.currencyCode, account.currencyCode);
        _requireCashAccount(account);

        final int nextBalance = FinancialCalculator.confirmIncome(
          currentBalanceMinorUnits: account.currentBalanceMinorUnits,
          amountMinorUnits: income.amountMinorUnits,
        );
        final DateTime now = _now();
        final String transactionId = _uuid.v4();
        await _setAccount(
          account,
          currentBalanceMinorUnits: nextBalance,
          updatedAt: now,
        );
        await _insertTransaction(
          id: transactionId,
          userId: income.userId ?? account.userId,
          accountId: input.accountId,
          destinationAccountId: input.accountId,
          type: 'income',
          direction: 'inflow',
          title: income.source,
          amountMinorUnits: income.amountMinorUnits,
          currencyCode: income.currencyCode,
          relatedRecordType: 'income',
          relatedRecordId: income.id,
          idempotencyKey: input.idempotencyKey,
          notes: income.notes,
          occurredAt: input.receivedAt,
        );
        await (_database.update(
          _database.incomeRecords,
        )..where((IncomeRecords row) => row.id.equals(income.id))).write(
          IncomeRecordsCompanion(
            receivingAccountId: Value<String?>(input.accountId),
            actualReceivedAt: Value<DateTime>(input.receivedAt.toUtc()),
            status: const Value<String>('received'),
            transactionId: Value<String?>(transactionId),
            updatedAt: Value<DateTime>(now),
            localVersion: Value<int>(income.localVersion + 1),
          ),
        );
        await _enqueue('income_records', income.id, <String, Object?>{
          'id': income.id,
          'status': 'received',
          'actual_received_at': input.receivedAt.toUtc().toIso8601String(),
          'receiving_account_id': input.accountId,
          'transaction_id': transactionId,
        });
        return transactionId;
      });

  Future<String> confirmExpense(ConfirmExpenseInput input) =>
      _database.transaction(() async {
        _requireText(input.idempotencyKey, 'idempotencyKey');
        final TransactionRecord? duplicate =
            await (_database.select(_database.transactions)..where(
                  (Transactions row) =>
                      row.idempotencyKey.equals(input.idempotencyKey),
                ))
                .getSingleOrNull();
        if (duplicate != null &&
            duplicate.transactionType != 'expense' &&
            duplicate.transactionType != 'credit_card_purchase') {
          throw StateError(
            'Idempotency key was already used by another action.',
          );
        }
        if (duplicate != null) return duplicate.id;

        final ExpenseRecord expense =
            await (_database.select(_database.expenses)..where(
                  (Expenses row) =>
                      row.id.equals(input.expenseId) & row.deletedAt.isNull(),
                ))
                .getSingle();
        if (expense.status == 'confirmed' && expense.transactionId != null) {
          return expense.transactionId!;
        }
        if (expense.status != 'planned') {
          throw StateError('Only planned expenses can be confirmed.');
        }
        final FinancialAccountRecord account = await _account(input.accountId);
        _requireOwner(expense.userId, account.userId);
        _requireSameCurrency(expense.currencyCode, account.currencyCode);
        final bool isCreditCard = _isCreditCard(account.accountType);
        late final int? nextBalance;
        late final int? nextOutstanding;
        if (isCreditCard) {
          nextOutstanding = FinancialCalculator.creditCardPurchase(
            creditLimitMinorUnits: account.creditLimitMinorUnits,
            outstandingMinorUnits: account.outstandingCreditMinorUnits,
            purchaseMinorUnits: expense.amountMinorUnits,
          );
          nextBalance = null;
        } else {
          _requireCashAccount(account);
          nextBalance = FinancialCalculator.confirmExpense(
            currentBalanceMinorUnits: account.currentBalanceMinorUnits,
            amountMinorUnits: expense.amountMinorUnits,
            allowNegativeBalance: account.allowNegativeBalance,
          );
          nextOutstanding = null;
        }

        final DateTime now = _now();
        final String transactionId = _uuid.v4();
        await _setAccount(
          account,
          currentBalanceMinorUnits: nextBalance,
          outstandingCreditMinorUnits: nextOutstanding,
          updatedAt: now,
        );
        await _insertTransaction(
          id: transactionId,
          userId: expense.userId ?? account.userId,
          accountId: input.accountId,
          sourceAccountId: input.accountId,
          type: isCreditCard ? 'credit_card_purchase' : 'expense',
          direction: 'outflow',
          title: expense.title,
          amountMinorUnits: expense.amountMinorUnits,
          currencyCode: expense.currencyCode,
          categoryId: expense.categoryId,
          relatedRecordType: 'expense',
          relatedRecordId: expense.id,
          idempotencyKey: input.idempotencyKey,
          notes: expense.description,
          occurredAt: input.confirmedAt,
        );
        await (_database.update(
          _database.expenses,
        )..where((Expenses row) => row.id.equals(expense.id))).write(
          ExpensesCompanion(
            paymentAccountId: Value<String?>(input.accountId),
            status: const Value<String>('confirmed'),
            transactionId: Value<String?>(transactionId),
            updatedAt: Value<DateTime>(now),
          ),
        );
        await _enqueue('expenses', expense.id, <String, Object?>{
          'id': expense.id,
          'status': 'confirmed',
          'account_id': input.accountId,
          'spent_at': input.confirmedAt.toUtc().toIso8601String(),
          'transaction_id': transactionId,
        });
        return transactionId;
      });

  Future<String> recordIncome(RecordIncomeInput input) =>
      _database.transaction(() async {
        final TransactionRecord? duplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'income',
        );
        if (duplicate != null) return duplicate.id;
        _requireText(input.source, 'source');
        _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
        final FinancialAccountRecord account = await _account(input.accountId);
        _requireCashAccount(account);
        final int nextBalance = FinancialCalculator.confirmIncome(
          currentBalanceMinorUnits: account.currentBalanceMinorUnits,
          amountMinorUnits: input.amountMinorUnits,
        );
        final DateTime now = _now();
        final DateTime receivedAt = input.occurredAt.toUtc();
        final String incomeId = _uuid.v4();
        final String transactionId = _uuid.v4();
        await _setAccount(
          account,
          currentBalanceMinorUnits: nextBalance,
          updatedAt: now,
        );
        await _database
            .into(_database.incomeRecords)
            .insert(
              IncomeRecordsCompanion.insert(
                id: incomeId,
                userId: Value<String?>(account.userId),
                source: input.source.trim(),
                amountMinorUnits: input.amountMinorUnits,
                currencyCode: Value<String>(account.currencyCode),
                expectedDate: receivedAt,
                actualReceivedAt: Value<DateTime?>(receivedAt),
                frequency: const Value<String>('one_time'),
                receivingAccountId: Value<String?>(account.id),
                status: const Value<String>('received'),
                transactionId: Value<String?>(transactionId),
                notes: Value<String?>(_trimOrNull(input.notes)),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _insertTransaction(
          id: transactionId,
          userId: account.userId,
          accountId: account.id,
          destinationAccountId: account.id,
          type: 'income',
          direction: 'inflow',
          title: input.source.trim(),
          amountMinorUnits: input.amountMinorUnits,
          currencyCode: account.currencyCode,
          category: input.category,
          relatedRecordType: 'income',
          relatedRecordId: incomeId,
          idempotencyKey: input.idempotencyKey,
          notes: input.notes,
          occurredAt: receivedAt,
        );
        await _enqueue('income_records', incomeId, <String, Object?>{
          'id': incomeId,
          'user_id': account.userId,
          'source': input.source.trim(),
          'amount': _decimalAmount(input.amountMinorUnits),
          'currency_code': account.currencyCode,
          'expected_date': _dateOnly(receivedAt),
          'actual_received_at': receivedAt.toIso8601String(),
          'frequency': 'one_time',
          'receiving_account_id': account.id,
          'status': 'received',
          'transaction_id': transactionId,
          'notes': _trimOrNull(input.notes),
        });
        return transactionId;
      });

  Future<String> recordExpense(RecordExpenseInput input) =>
      _database.transaction(() async {
        final TransactionRecord? duplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'expense',
        );
        if (duplicate != null) return duplicate.id;
        _requireText(input.title, 'title');
        _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
        final FinancialAccountRecord account = await _account(input.accountId);
        _requireActiveAccount(account);
        final DateTime now = _now();
        final String expenseId = _uuid.v4();
        final String transactionId = _uuid.v4();
        late final int? nextBalance;
        late final int? nextOutstanding;
        if (_isCreditCard(account.accountType)) {
          nextOutstanding = FinancialCalculator.creditCardPurchase(
            creditLimitMinorUnits: account.creditLimitMinorUnits,
            outstandingMinorUnits: account.outstandingCreditMinorUnits,
            purchaseMinorUnits: input.amountMinorUnits,
          );
          nextBalance = null;
        } else {
          _requireCashAccount(account);
          nextBalance = FinancialCalculator.confirmExpense(
            currentBalanceMinorUnits: account.currentBalanceMinorUnits,
            amountMinorUnits: input.amountMinorUnits,
            allowNegativeBalance: account.allowNegativeBalance,
          );
          nextOutstanding = null;
        }
        await _setAccount(
          account,
          currentBalanceMinorUnits: nextBalance,
          outstandingCreditMinorUnits: nextOutstanding,
          updatedAt: now,
        );
        await _database
            .into(_database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: expenseId,
                userId: Value<String?>(account.userId),
                title: input.title.trim(),
                amountMinorUnits: input.amountMinorUnits,
                currencyCode: Value<String>(account.currencyCode),
                occurredAt: input.occurredAt.toUtc(),
                paymentAccountId: Value<String?>(account.id),
                description: Value<String?>(_trimOrNull(input.notes)),
                status: const Value<String>('confirmed'),
                transactionId: Value<String?>(transactionId),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _insertTransaction(
          id: transactionId,
          userId: account.userId,
          accountId: account.id,
          sourceAccountId: account.id,
          type: _isCreditCard(account.accountType)
              ? 'credit_card_purchase'
              : 'expense',
          direction: 'outflow',
          title: input.title.trim(),
          amountMinorUnits: input.amountMinorUnits,
          currencyCode: account.currencyCode,
          category: input.category,
          relatedRecordType: 'expense',
          relatedRecordId: expenseId,
          idempotencyKey: input.idempotencyKey,
          notes: input.notes,
          occurredAt: input.occurredAt,
        );
        await _enqueue('expenses', expenseId, <String, Object?>{
          'id': expenseId,
          'user_id': account.userId,
          'title': input.title.trim(),
          'amount': _decimalAmount(input.amountMinorUnits),
          'currency_code': account.currencyCode,
          'account_id': account.id,
          'spent_at': input.occurredAt.toUtc().toIso8601String(),
          'status': 'confirmed',
          'transaction_id': transactionId,
          'notes': _trimOrNull(input.notes),
        });
        return transactionId;
      });

  Future<String> confirmBillPayment(BillPaymentInput input) =>
      _database.transaction(() async {
        final BillPaymentRecord? duplicate =
            await (_database.select(_database.billPayments)..where(
                  (BillPayments row) =>
                      row.idempotencyKey.equals(input.idempotencyKey),
                ))
                .getSingleOrNull();
        if (duplicate != null && duplicate.transactionId != null) {
          return duplicate.transactionId!;
        }
        final TransactionRecord? transactionDuplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'bill_payment',
        );
        if (transactionDuplicate != null) return transactionDuplicate.id;

        _requireText(input.occurrenceKey, 'occurrenceKey');
        _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
        final BillRecord bill =
            await (_database.select(_database.bills)..where(
                  (Bills row) =>
                      row.id.equals(input.billId) &
                      row.isActive.equals(true) &
                      row.archivedAt.isNull(),
                ))
                .getSingle();
        final FinancialAccountRecord account = await _account(input.accountId);
        _requireOwner(bill.userId, account.userId);
        _requireSameCurrency(bill.currencyCode, account.currencyCode);
        _requireCashAccount(account);

        final List<BillPaymentRecord> priorPayments =
            await (_database.select(_database.billPayments)..where(
                  (BillPayments row) =>
                      row.billId.equals(input.billId) &
                      row.occurrenceKey.equals(input.occurrenceKey),
                ))
                .get();
        final int alreadyPaid = priorPayments
            .where((BillPaymentRecord payment) => payment.reversedAt == null)
            .fold<int>(
              0,
              (int total, BillPaymentRecord payment) =>
                  total + payment.amountMinorUnits,
            );
        if (alreadyPaid + input.amountMinorUnits > bill.amountMinorUnits) {
          throw StateError('Bill payment exceeds the remaining amount due.');
        }
        final int nextBalance = FinancialCalculator.confirmExpense(
          currentBalanceMinorUnits: account.currentBalanceMinorUnits,
          amountMinorUnits: input.amountMinorUnits,
          allowNegativeBalance: account.allowNegativeBalance,
        );
        final DateTime now = _now();
        final String transactionId = _uuid.v4();
        final String paymentId = _uuid.v4();
        await _setAccount(
          account,
          currentBalanceMinorUnits: nextBalance,
          updatedAt: now,
        );
        await _insertTransaction(
          id: transactionId,
          userId: bill.userId ?? account.userId,
          accountId: input.accountId,
          sourceAccountId: input.accountId,
          type: 'bill_payment',
          direction: 'outflow',
          title: bill.name,
          amountMinorUnits: input.amountMinorUnits,
          currencyCode: bill.currencyCode,
          categoryId: bill.categoryId,
          relatedBillId: bill.id,
          relatedRecordType: 'bill',
          relatedRecordId: bill.id,
          idempotencyKey: input.idempotencyKey,
          notes: input.notes,
          occurredAt: input.paidAt,
        );
        await _database
            .into(_database.billPayments)
            .insert(
              BillPaymentsCompanion.insert(
                id: paymentId,
                userId: Value<String?>(bill.userId ?? account.userId),
                billId: bill.id,
                accountId: account.id,
                transactionId: Value<String?>(transactionId),
                occurrenceKey: Value<String>(input.occurrenceKey),
                idempotencyKey: Value<String?>(input.idempotencyKey),
                amountMinorUnits: input.amountMinorUnits,
                paidAt: input.paidAt.toUtc(),
                notes: Value<String?>(_trimOrNull(input.notes)),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _enqueue('bill_payments', paymentId, <String, Object?>{
          'id': paymentId,
          'user_id': bill.userId ?? account.userId,
          'bill_id': bill.id,
          'account_id': account.id,
          'transaction_id': transactionId,
          'occurrence_key': input.occurrenceKey,
          'amount': _decimalAmount(input.amountMinorUnits),
          'paid_at': input.paidAt.toUtc().toIso8601String(),
          'notes': _trimOrNull(input.notes),
        });
        return transactionId;
      });

  Future<String> confirmLoanPayment(
    LoanPaymentInput input,
  ) => _database.transaction(() async {
    final LoanPaymentRecord? duplicate =
        await (_database.select(_database.loanPayments)..where(
              (LoanPayments row) =>
                  row.idempotencyKey.equals(input.idempotencyKey),
            ))
            .getSingleOrNull();
    if (duplicate != null && duplicate.transactionId != null) {
      return duplicate.transactionId!;
    }
    final TransactionRecord? transactionDuplicate = await _transactionByKey(
      input.idempotencyKey,
      expectedType: 'loan_payment',
    );
    if (transactionDuplicate != null) return transactionDuplicate.id;

    final LoanRecord loan = await _loan(input.loanId);
    if (loan.status != 'active' || loan.archivedAt != null) {
      throw StateError('Only active loans can receive payments.');
    }
    final LoanInstallmentRecord installment =
        await (_database.select(_database.loanInstallments)..where(
              (LoanInstallments row) =>
                  row.id.equals(input.installmentId) &
                  row.loanId.equals(input.loanId),
            ))
            .getSingle();
    if (installment.status == 'paid') {
      throw StateError('This installment is already fully paid.');
    }
    final FinancialAccountRecord account = await _account(input.accountId);
    _requireOwner(loan.userId, account.userId);
    _requireSameCurrency(loan.currencyCode, account.currencyCode);
    _requireCashAccount(account);
    final LoanPaymentBalances result = FinancialCalculator.applyLoanPayment(
      loanRemainingMinorUnits: loan.remainingBalanceMinorUnits,
      scheduledInstallmentMinorUnits: installment.scheduledMinorUnits,
      paidInstallmentMinorUnits: installment.paidMinorUnits,
      paymentMinorUnits: input.amountMinorUnits,
    );
    final int nextAccountBalance = FinancialCalculator.confirmExpense(
      currentBalanceMinorUnits: account.currentBalanceMinorUnits,
      amountMinorUnits: input.amountMinorUnits,
      allowNegativeBalance: account.allowNegativeBalance,
    );
    final DateTime now = _now();
    final String transactionId = _uuid.v4();
    final String paymentId = _uuid.v4();
    final bool installmentCompleted =
        result.installmentRemainingMinorUnits == 0;
    final bool loanCompleted = result.loanRemainingMinorUnits == 0;

    await _setAccount(
      account,
      currentBalanceMinorUnits: nextAccountBalance,
      updatedAt: now,
    );
    await _insertTransaction(
      id: transactionId,
      userId: loan.userId ?? account.userId,
      accountId: account.id,
      sourceAccountId: account.id,
      type: 'loan_payment',
      direction: 'outflow',
      title: '${loan.providerName} · ${loan.name}',
      amountMinorUnits: input.amountMinorUnits,
      currencyCode: loan.currencyCode,
      relatedLoanId: loan.id,
      relatedInstallmentId: installment.id,
      relatedRecordType: 'loan_installment',
      relatedRecordId: installment.id,
      idempotencyKey: input.idempotencyKey,
      notes: input.notes,
      occurredAt: input.paidAt,
    );
    await _database
        .into(_database.loanPayments)
        .insert(
          LoanPaymentsCompanion.insert(
            id: paymentId,
            userId: Value<String?>(loan.userId ?? account.userId),
            loanId: loan.id,
            installmentId: Value<String?>(installment.id),
            accountId: account.id,
            transactionId: Value<String?>(transactionId),
            idempotencyKey: Value<String?>(input.idempotencyKey),
            amountMinorUnits: input.amountMinorUnits,
            paidAt: input.paidAt.toUtc(),
            notes: Value<String?>(_trimOrNull(input.notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await (_database.update(
      _database.loanInstallments,
    )..where((LoanInstallments row) => row.id.equals(installment.id))).write(
      LoanInstallmentsCompanion(
        paidMinorUnits: Value<int>(result.installmentPaidMinorUnits),
        status: Value<String>(installmentCompleted ? 'paid' : 'partial'),
        paidAt: Value<DateTime?>(input.paidAt.toUtc()),
        paymentAccountId: Value<String?>(account.id),
        transactionId: Value<String?>(transactionId),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(installment.localVersion + 1),
      ),
    );
    final List<LoanInstallmentRecord> unpaid =
        await (_database.select(_database.loanInstallments)
              ..where(
                (LoanInstallments row) =>
                    row.loanId.equals(loan.id) &
                    (row.status.equals('unpaid') |
                        row.status.equals('partial')),
              )
              ..orderBy(<OrderingTerm Function(LoanInstallments)>[
                (LoanInstallments row) => OrderingTerm.asc(row.dueDate),
              ]))
            .get();
    await (_database.update(
      _database.loans,
    )..where((Loans row) => row.id.equals(loan.id))).write(
      LoansCompanion(
        remainingBalanceMinorUnits: Value<int>(result.loanRemainingMinorUnits),
        paidInstallments: Value<int>(
          loan.paidInstallments + (installmentCompleted ? 1 : 0),
        ),
        nextDueDate: Value<DateTime?>(
          unpaid.isEmpty ? null : unpaid.first.dueDate,
        ),
        status: Value<String>(loanCompleted ? 'paid' : 'active'),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(loan.localVersion + 1),
      ),
    );
    await _enqueue('loan_payments', paymentId, <String, Object?>{
      'id': paymentId,
      'user_id': loan.userId ?? account.userId,
      'loan_id': loan.id,
      'installment_id': installment.id,
      'account_id': account.id,
      'transaction_id': transactionId,
      'amount': _decimalAmount(input.amountMinorUnits),
      'paid_at': input.paidAt.toUtc().toIso8601String(),
      'status': 'confirmed',
      'notes': _trimOrNull(input.notes),
    });
    await _enqueue('loan_installments', installment.id, <String, Object?>{
      'id': installment.id,
      'paid_amount': _decimalAmount(result.installmentPaidMinorUnits),
      'status': installmentCompleted ? 'paid' : 'partial',
      'paid_at': input.paidAt.toUtc().toIso8601String(),
      'transaction_id': transactionId,
    });
    await _enqueue('loans', loan.id, <String, Object?>{
      'id': loan.id,
      'remaining_balance': _decimalAmount(result.loanRemainingMinorUnits),
      'paid_installments':
          loan.paidInstallments + (installmentCompleted ? 1 : 0),
      'next_due_date': unpaid.isEmpty ? null : _dateOnly(unpaid.first.dueDate),
      'status': loanCompleted ? 'paid' : 'active',
    });
    return transactionId;
  });

  Future<String> transfer(TransferInput input) => _database.transaction(
    () async {
      final AccountTransferRecord? duplicate =
          await (_database.select(_database.accountTransfers)..where(
                (AccountTransfers row) =>
                    row.idempotencyKey.equals(input.idempotencyKey),
              ))
              .getSingleOrNull();
      if (duplicate != null && duplicate.transactionId != null) {
        return duplicate.transactionId!;
      }
      final TransactionRecord? transactionDuplicate = await _transactionByKey(
        input.idempotencyKey,
        expectedType: 'account_transfer',
      );
      if (transactionDuplicate != null) return transactionDuplicate.id;
      if (input.fromAccountId == input.toAccountId) {
        throw ArgumentError('Source and destination accounts must differ.');
      }
      _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
      _requireNonNegative(input.feeMinorUnits, 'feeMinorUnits');
      final FinancialAccountRecord source = await _account(input.fromAccountId);
      final FinancialAccountRecord destination = await _account(
        input.toAccountId,
      );
      _requireOwner(source.userId, destination.userId);
      _requireSameCurrency(source.currencyCode, destination.currencyCode);
      _requireCashAccount(source);
      _requireCashAccount(destination);
      final int totalDebit = input.amountMinorUnits + input.feeMinorUnits;
      final TransferBalances balances = FinancialCalculator.transfer(
        sourceBalanceMinorUnits: source.currentBalanceMinorUnits,
        destinationBalanceMinorUnits: destination.currentBalanceMinorUnits,
        amountMinorUnits: totalDebit,
        allowNegativeSourceBalance: source.allowNegativeBalance,
      );
      final int destinationBalance =
          destination.currentBalanceMinorUnits + input.amountMinorUnits;
      final DateTime now = _now();
      final String transactionId = _uuid.v4();
      final String transferId = _uuid.v4();
      await _setAccount(
        source,
        currentBalanceMinorUnits: balances.sourceBalanceMinorUnits,
        updatedAt: now,
      );
      await _setAccount(
        destination,
        currentBalanceMinorUnits: destinationBalance,
        updatedAt: now,
      );
      await _insertTransaction(
        id: transactionId,
        userId: source.userId ?? destination.userId,
        accountId: source.id,
        sourceAccountId: source.id,
        destinationAccountId: destination.id,
        type: 'account_transfer',
        direction: 'transfer',
        title: 'Transfer to ${destination.name}',
        amountMinorUnits: input.amountMinorUnits,
        currencyCode: source.currencyCode,
        relatedRecordType: 'account_transfer',
        relatedRecordId: transferId,
        idempotencyKey: input.idempotencyKey,
        notes: input.notes,
        occurredAt: input.transferredAt,
      );
      await _database
          .into(_database.accountTransfers)
          .insert(
            AccountTransfersCompanion.insert(
              id: transferId,
              userId: Value<String?>(source.userId ?? destination.userId),
              fromAccountId: source.id,
              toAccountId: destination.id,
              transactionId: Value<String?>(transactionId),
              idempotencyKey: Value<String?>(input.idempotencyKey),
              amountMinorUnits: input.amountMinorUnits,
              feeMinorUnits: Value<int>(input.feeMinorUnits),
              currencyCode: Value<String>(source.currencyCode),
              transferredAt: input.transferredAt.toUtc(),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (input.feeMinorUnits > 0) {
        await _insertTransaction(
          id: _uuid.v4(),
          userId: source.userId,
          accountId: source.id,
          sourceAccountId: source.id,
          type: 'expense',
          direction: 'outflow',
          title: 'Transfer fee',
          amountMinorUnits: input.feeMinorUnits,
          currencyCode: source.currencyCode,
          relatedRecordType: 'account_transfer_fee',
          relatedRecordId: transferId,
          idempotencyKey: '${input.idempotencyKey}:fee',
          occurredAt: input.transferredAt,
        );
      }
      await _enqueue('account_transfers', transferId, <String, Object?>{
        'id': transferId,
        'user_id': source.userId,
        'from_account_id': source.id,
        'to_account_id': destination.id,
        'transaction_id': transactionId,
        'amount': _decimalAmount(input.amountMinorUnits),
        'fee_amount': _decimalAmount(input.feeMinorUnits),
        'transferred_at': input.transferredAt.toUtc().toIso8601String(),
      });
      return transactionId;
    },
  );

  Future<String> recordCreditCardPurchase(CreditPurchaseInput input) =>
      _database.transaction(() async {
        final TransactionRecord? duplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'credit_card_purchase',
        );
        if (duplicate != null) return duplicate.id;
        _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
        _requireText(input.title, 'title');
        final FinancialAccountRecord card = await _account(
          input.creditAccountId,
        );
        if (!_isCreditCard(card.accountType)) {
          throw ArgumentError('Purchases must use a credit card account.');
        }
        _requireActiveAccount(card);
        final int nextOutstanding = FinancialCalculator.creditCardPurchase(
          creditLimitMinorUnits: card.creditLimitMinorUnits,
          outstandingMinorUnits: card.outstandingCreditMinorUnits,
          purchaseMinorUnits: input.amountMinorUnits,
        );
        final DateTime now = _now();
        final String transactionId = _uuid.v4();
        final String expenseId = _uuid.v4();
        await _setAccount(
          card,
          outstandingCreditMinorUnits: nextOutstanding,
          updatedAt: now,
        );
        await _insertTransaction(
          id: transactionId,
          userId: card.userId,
          accountId: card.id,
          sourceAccountId: card.id,
          type: 'credit_card_purchase',
          direction: 'outflow',
          title: input.title.trim(),
          amountMinorUnits: input.amountMinorUnits,
          currencyCode: card.currencyCode,
          categoryId: input.categoryId,
          relatedRecordType: 'expense',
          relatedRecordId: expenseId,
          idempotencyKey: input.idempotencyKey,
          notes: input.notes,
          occurredAt: input.occurredAt,
        );
        await _database
            .into(_database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: expenseId,
                userId: Value<String?>(card.userId),
                title: input.title.trim(),
                amountMinorUnits: input.amountMinorUnits,
                currencyCode: Value<String>(card.currencyCode),
                categoryId: Value<String?>(input.categoryId),
                occurredAt: input.occurredAt.toUtc(),
                paymentAccountId: Value<String?>(card.id),
                description: Value<String?>(_trimOrNull(input.notes)),
                status: const Value<String>('confirmed'),
                transactionId: Value<String?>(transactionId),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _enqueue('expenses', expenseId, <String, Object?>{
          'id': expenseId,
          'title': input.title.trim(),
          'amount': _decimalAmount(input.amountMinorUnits),
          'financial_category_id': input.categoryId,
          'account_id': card.id,
          'spent_at': input.occurredAt.toUtc().toIso8601String(),
          'status': 'confirmed',
          'transaction_id': transactionId,
        });
        return transactionId;
      });

  Future<String> recordCreditCardPayment(CreditPaymentInput input) =>
      _database.transaction(() async {
        final TransactionRecord? duplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'credit_card_payment',
        );
        if (duplicate != null) return duplicate.id;
        final FinancialAccountRecord cash = await _account(input.cashAccountId);
        final FinancialAccountRecord card = await _account(
          input.creditAccountId,
        );
        if (!_isCreditCard(card.accountType)) {
          throw ArgumentError('Destination account must be a credit card.');
        }
        _requireActiveAccount(card);
        _requireCashAccount(cash);
        _requireOwner(cash.userId, card.userId);
        _requireSameCurrency(cash.currencyCode, card.currencyCode);
        final CreditBalances balances = FinancialCalculator.creditCardPayment(
          cashBalanceMinorUnits: cash.currentBalanceMinorUnits,
          outstandingMinorUnits: card.outstandingCreditMinorUnits,
          amountMinorUnits: input.amountMinorUnits,
          allowNegativeCashBalance: cash.allowNegativeBalance,
        );
        final DateTime now = _now();
        final String transactionId = _uuid.v4();
        await _setAccount(
          cash,
          currentBalanceMinorUnits: balances.cashBalanceMinorUnits,
          updatedAt: now,
        );
        await _setAccount(
          card,
          outstandingCreditMinorUnits: balances.outstandingMinorUnits,
          updatedAt: now,
        );
        await _insertTransaction(
          id: transactionId,
          userId: cash.userId ?? card.userId,
          accountId: cash.id,
          sourceAccountId: cash.id,
          destinationAccountId: card.id,
          type: 'credit_card_payment',
          direction: 'transfer',
          title: 'Credit card payment · ${card.name}',
          amountMinorUnits: input.amountMinorUnits,
          currencyCode: cash.currencyCode,
          relatedRecordType: 'credit_card_payment',
          relatedRecordId: card.id,
          idempotencyKey: input.idempotencyKey,
          notes: input.notes,
          occurredAt: input.paidAt,
        );
        return transactionId;
      });

  Future<String?> reconcileAccount(ReconcileAccountInput input) =>
      _database.transaction(() async {
        final TransactionRecord? duplicate = await _transactionByKey(
          input.idempotencyKey,
          expectedType: 'balance_adjustment',
        );
        if (duplicate != null) return duplicate.id;

        final FinancialAccountRecord account = await _account(input.accountId);
        _requireActiveAccount(account);
        final bool isCredit = _isCreditCard(account.accountType);
        if (isCredit) {
          _requireNonNegative(
            input.actualBalanceMinorUnits,
            'actualBalanceMinorUnits',
          );
        } else {
          _requireAccountBalance(
            input.actualBalanceMinorUnits,
            account.accountType,
            account.allowNegativeBalance,
          );
        }
        final int oldBalance = isCredit
            ? account.outstandingCreditMinorUnits
            : account.currentBalanceMinorUnits;
        final int delta = FinancialCalculator.reconciliationDelta(
          recordedBalanceMinorUnits: oldBalance,
          actualBalanceMinorUnits: input.actualBalanceMinorUnits,
        );
        if (delta == 0) return null;

        final DateTime now = _now();
        final String transactionId = _uuid.v4();
        await _setAccount(
          account,
          currentBalanceMinorUnits: isCredit
              ? null
              : input.actualBalanceMinorUnits,
          outstandingCreditMinorUnits: isCredit
              ? input.actualBalanceMinorUnits
              : null,
          updatedAt: now,
        );
        await _insertTransaction(
          id: transactionId,
          userId: account.userId,
          accountId: account.id,
          sourceAccountId: delta < 0 ? account.id : null,
          destinationAccountId: delta > 0 ? account.id : null,
          type: 'balance_adjustment',
          direction: delta > 0 ? 'inflow' : 'outflow',
          title: 'Balance reconciliation',
          amountMinorUnits: delta.abs(),
          currencyCode: account.currencyCode,
          idempotencyKey: input.idempotencyKey,
          notes: input.notes,
          occurredAt: input.reconciledAt,
        );
        return transactionId;
      });

  Future<String> contributeToSavings(
    SavingsContributionInput input,
  ) => _database.transaction(() async {
    final TransactionRecord? duplicate = await _transactionByKey(
      input.idempotencyKey,
      expectedType: 'savings_contribution',
    );
    if (duplicate != null) return duplicate.id;
    _requirePositive(input.amountMinorUnits, 'amountMinorUnits');
    final SavingsGoalRecord goal =
        await (_database.select(_database.savingsGoals)..where(
              (SavingsGoals row) =>
                  row.id.equals(input.goalId) &
                  row.status.equals('active') &
                  row.archivedAt.isNull(),
            ))
            .getSingle();
    final FinancialAccountRecord account = await _account(input.accountId);
    _requireOwner(goal.userId, account.userId);
    _requireSameCurrency(goal.currencyCode, account.currencyCode);
    _requireCashAccount(account);
    final int nextBalance = FinancialCalculator.confirmExpense(
      currentBalanceMinorUnits: account.currentBalanceMinorUnits,
      amountMinorUnits: input.amountMinorUnits,
      allowNegativeBalance: account.allowNegativeBalance,
    );
    final DateTime now = _now();
    final String transactionId = _uuid.v4();
    final String contributionId = _uuid.v4();
    final int nextGoalAmount =
        goal.currentAmountMinorUnits + input.amountMinorUnits;
    await _setAccount(
      account,
      currentBalanceMinorUnits: nextBalance,
      updatedAt: now,
    );
    await _insertTransaction(
      id: transactionId,
      userId: goal.userId ?? account.userId,
      accountId: account.id,
      sourceAccountId: account.id,
      type: 'savings_contribution',
      direction: 'outflow',
      title: goal.name,
      amountMinorUnits: input.amountMinorUnits,
      currencyCode: goal.currencyCode,
      relatedRecordType: 'savings_goal',
      relatedRecordId: goal.id,
      idempotencyKey: input.idempotencyKey,
      notes: input.notes,
      occurredAt: input.contributedAt,
    );
    await _database
        .into(_database.savingsContributions)
        .insert(
          SavingsContributionsCompanion.insert(
            id: contributionId,
            userId: Value<String?>(goal.userId ?? account.userId),
            goalId: goal.id,
            accountId: Value<String?>(account.id),
            transactionId: Value<String?>(transactionId),
            amountMinorUnits: input.amountMinorUnits,
            contributedAt: input.contributedAt.toUtc(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await (_database.update(
      _database.savingsGoals,
    )..where((SavingsGoals row) => row.id.equals(goal.id))).write(
      SavingsGoalsCompanion(
        currentAmountMinorUnits: Value<int>(nextGoalAmount),
        status: Value<String>(
          nextGoalAmount >= goal.targetAmountMinorUnits
              ? 'completed'
              : 'active',
        ),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(goal.localVersion + 1),
      ),
    );
    await _enqueue('savings_contributions', contributionId, <String, Object?>{
      'id': contributionId,
      'user_id': goal.userId ?? account.userId,
      'goal_id': goal.id,
      'account_id': account.id,
      'transaction_id': transactionId,
      'amount': _decimalAmount(input.amountMinorUnits),
      'contributed_at': input.contributedAt.toUtc().toIso8601String(),
    });
    await _enqueue('savings_goals', goal.id, <String, Object?>{
      'id': goal.id,
      'current_amount': _decimalAmount(nextGoalAmount),
      'status': nextGoalAmount >= goal.targetAmountMinorUnits
          ? 'completed'
          : 'active',
    });
    return transactionId;
  });

  Future<String> reverseTransaction({
    required String transactionId,
    required DateTime reversedAt,
    required String idempotencyKey,
    String? notes,
  }) => _database.transaction(() async {
    final TransactionRecord? duplicate = await _transactionByKey(
      idempotencyKey,
      expectedType: 'reversal',
    );
    if (duplicate != null) return duplicate.id;
    final TransactionRecord original =
        await (_database.select(_database.transactions)..where(
              (Transactions row) =>
                  row.id.equals(transactionId) & row.deletedAt.isNull(),
            ))
            .getSingle();
    if (original.transactionType == 'reversal') {
      throw StateError('A reversal transaction cannot be reversed.');
    }
    final TransactionRecord? priorReversal =
        await (_database.select(_database.transactions)..where(
              (Transactions row) => row.reversalOfId.equals(original.id),
            ))
            .getSingleOrNull();
    if (priorReversal != null) return priorReversal.id;

    final int amount = original.amountMinorUnits;
    final String? sourceId = original.sourceAccountId;
    final String? destinationId = original.destinationAccountId;
    final String fallbackAccountId = original.accountId;
    final DateTime now = _now();

    switch (original.transactionType) {
      case 'income':
        final FinancialAccountRecord destination = await _account(
          destinationId ?? fallbackAccountId,
        );
        await _setAccount(
          destination,
          currentBalanceMinorUnits:
              destination.currentBalanceMinorUnits - amount,
          updatedAt: now,
        );
        if (original.relatedRecordType == 'income' &&
            original.relatedRecordId != null) {
          await (_database.update(_database.incomeRecords)..where(
                (IncomeRecords row) => row.id.equals(original.relatedRecordId!),
              ))
              .write(
                IncomeRecordsCompanion(
                  status: const Value<String>('reversed'),
                  updatedAt: Value<DateTime>(now),
                ),
              );
          await _enqueue(
            'income_records',
            original.relatedRecordId!,
            <String, Object?>{
              'id': original.relatedRecordId,
              'status': 'reversed',
            },
          );
        }
        break;
      case 'expense':
      case 'bill_payment':
      case 'loan_payment':
      case 'savings_contribution':
        final FinancialAccountRecord source = await _account(
          sourceId ?? fallbackAccountId,
        );
        await _setAccount(
          source,
          currentBalanceMinorUnits: source.currentBalanceMinorUnits + amount,
          updatedAt: now,
        );
        if (original.transactionType == 'expense' &&
            original.relatedRecordType == 'expense' &&
            original.relatedRecordId != null) {
          await (_database.update(_database.expenses)..where(
                (Expenses row) => row.id.equals(original.relatedRecordId!),
              ))
              .write(
                ExpensesCompanion(
                  status: const Value<String>('reversed'),
                  updatedAt: Value<DateTime>(now),
                ),
              );
          await _enqueue(
            'expenses',
            original.relatedRecordId!,
            <String, Object?>{
              'id': original.relatedRecordId,
              'status': 'reversed',
            },
          );
        }
        if (original.transactionType == 'bill_payment') {
          await (_database.update(_database.billPayments)..where(
                (BillPayments row) => row.transactionId.equals(original.id),
              ))
              .write(
                BillPaymentsCompanion(
                  reversedAt: Value<DateTime>(reversedAt.toUtc()),
                  updatedAt: Value<DateTime>(now),
                ),
              );
          final BillPaymentRecord? payment =
              await (_database.select(_database.billPayments)..where(
                    (BillPayments row) => row.transactionId.equals(original.id),
                  ))
                  .getSingleOrNull();
          if (payment != null) {
            await _enqueue('bill_payments', payment.id, <String, Object?>{
              'id': payment.id,
              'reversed_at': reversedAt.toUtc().toIso8601String(),
            });
          }
        }
        if (original.transactionType == 'loan_payment') {
          await _reverseLoanPayment(original, amount, now);
        }
        if (original.transactionType == 'savings_contribution') {
          await _reverseSavingsContribution(original, amount, now);
        }
        break;
      case 'credit_card_purchase':
        final FinancialAccountRecord card = await _account(
          sourceId ?? fallbackAccountId,
        );
        await _setAccount(
          card,
          outstandingCreditMinorUnits:
              card.outstandingCreditMinorUnits - amount,
          updatedAt: now,
        );
        if (original.relatedRecordType == 'expense' &&
            original.relatedRecordId != null) {
          await (_database.update(_database.expenses)..where(
                (Expenses row) => row.id.equals(original.relatedRecordId!),
              ))
              .write(
                ExpensesCompanion(
                  status: const Value<String>('reversed'),
                  updatedAt: Value<DateTime>(now),
                ),
              );
          await _enqueue(
            'expenses',
            original.relatedRecordId!,
            <String, Object?>{
              'id': original.relatedRecordId,
              'status': 'reversed',
            },
          );
        }
        break;
      case 'credit_card_payment':
        final FinancialAccountRecord cash = await _account(
          sourceId ?? fallbackAccountId,
        );
        final FinancialAccountRecord card = await _account(destinationId!);
        await _setAccount(
          cash,
          currentBalanceMinorUnits: cash.currentBalanceMinorUnits + amount,
          updatedAt: now,
        );
        await _setAccount(
          card,
          outstandingCreditMinorUnits:
              card.outstandingCreditMinorUnits + amount,
          updatedAt: now,
        );
        break;
      case 'account_transfer':
        final FinancialAccountRecord source = await _account(
          sourceId ?? fallbackAccountId,
        );
        final FinancialAccountRecord destination = await _account(
          destinationId!,
        );
        await _setAccount(
          source,
          currentBalanceMinorUnits: source.currentBalanceMinorUnits + amount,
          updatedAt: now,
        );
        await _setAccount(
          destination,
          currentBalanceMinorUnits:
              destination.currentBalanceMinorUnits - amount,
          updatedAt: now,
        );
        await (_database.update(_database.accountTransfers)..where(
              (AccountTransfers row) => row.transactionId.equals(original.id),
            ))
            .write(
              AccountTransfersCompanion(
                reversedAt: Value<DateTime>(reversedAt.toUtc()),
                updatedAt: Value<DateTime>(now),
              ),
            );
        final AccountTransferRecord? transfer =
            await (_database.select(_database.accountTransfers)..where(
                  (AccountTransfers row) =>
                      row.transactionId.equals(original.id),
                ))
                .getSingleOrNull();
        if (transfer != null) {
          await _enqueue('account_transfers', transfer.id, <String, Object?>{
            'id': transfer.id,
            'reversed_at': reversedAt.toUtc().toIso8601String(),
          });
        }
        break;
      case 'balance_adjustment':
        final FinancialAccountRecord account = await _account(
          original.direction == 'inflow'
              ? destinationId ?? fallbackAccountId
              : sourceId ?? fallbackAccountId,
        );
        final int adjustment = original.direction == 'inflow'
            ? -amount
            : amount;
        if (_isCreditCard(account.accountType)) {
          await _setAccount(
            account,
            outstandingCreditMinorUnits:
                account.outstandingCreditMinorUnits + adjustment,
            updatedAt: now,
          );
        } else {
          await _setAccount(
            account,
            currentBalanceMinorUnits:
                account.currentBalanceMinorUnits + adjustment,
            updatedAt: now,
          );
        }
        break;
      default:
        throw StateError(
          'Unsupported transaction type for reversal: ${original.transactionType}',
        );
    }

    final String reversalId = _uuid.v4();
    await _insertTransaction(
      id: reversalId,
      userId: original.userId,
      accountId: original.accountId,
      sourceAccountId: destinationId,
      destinationAccountId: sourceId,
      type: 'reversal',
      direction: 'reversal',
      title: 'Reversal · ${original.title}',
      amountMinorUnits: amount,
      currencyCode: original.currencyCode,
      relatedRecordType: original.relatedRecordType,
      relatedRecordId: original.relatedRecordId,
      reversalOfId: original.id,
      idempotencyKey: idempotencyKey,
      notes: notes,
      occurredAt: reversedAt,
    );
    return reversalId;
  });

  Future<void> _reverseLoanPayment(
    TransactionRecord transaction,
    int amount,
    DateTime now,
  ) async {
    final LoanPaymentRecord payment =
        await (_database.select(_database.loanPayments)..where(
              (LoanPayments row) => row.transactionId.equals(transaction.id),
            ))
            .getSingle();
    if (payment.status != 'confirmed') {
      throw StateError('The loan payment is already reversed.');
    }
    final LoanRecord loan = await _loan(payment.loanId);
    final LoanInstallmentRecord? installment = payment.installmentId == null
        ? null
        : await (_database.select(_database.loanInstallments)..where(
                (LoanInstallments row) => row.id.equals(payment.installmentId!),
              ))
              .getSingleOrNull();
    await (_database.update(
      _database.loanPayments,
    )..where((LoanPayments row) => row.id.equals(payment.id))).write(
      LoanPaymentsCompanion(
        status: const Value<String>('reversed'),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(payment.localVersion + 1),
      ),
    );
    await _enqueue('loan_payments', payment.id, <String, Object?>{
      'id': payment.id,
      'status': 'reversed',
    });

    int paidInstallments = loan.paidInstallments;
    if (installment != null) {
      final List<LoanPaymentRecord> remainingPayments =
          await (_database.select(_database.loanPayments)..where(
                (LoanPayments row) =>
                    row.installmentId.equals(installment.id) &
                    row.status.equals('confirmed'),
              ))
              .get();
      final int remainingPaid = remainingPayments.fold<int>(
        0,
        (int total, LoanPaymentRecord item) => total + item.amountMinorUnits,
      );
      final LoanPaymentRecord? latestPayment = remainingPayments.isEmpty
          ? null
          : remainingPayments.reduce(
              (LoanPaymentRecord a, LoanPaymentRecord b) =>
                  a.paidAt.isAfter(b.paidAt) ? a : b,
            );
      final String nextStatus = remainingPaid == 0
          ? 'unpaid'
          : remainingPaid >= installment.scheduledMinorUnits
          ? 'paid'
          : 'partial';
      if (installment.status == 'paid' && nextStatus != 'paid') {
        paidInstallments = (paidInstallments - 1).clamp(0, 1 << 31);
      }
      await (_database.update(
        _database.loanInstallments,
      )..where((LoanInstallments row) => row.id.equals(installment.id))).write(
        LoanInstallmentsCompanion(
          paidMinorUnits: Value<int>(remainingPaid),
          status: Value<String>(nextStatus),
          paidAt: Value<DateTime?>(latestPayment?.paidAt),
          transactionId: Value<String?>(latestPayment?.transactionId),
          updatedAt: Value<DateTime>(now),
          localVersion: Value<int>(installment.localVersion + 1),
        ),
      );
      await _enqueue('loan_installments', installment.id, <String, Object?>{
        'id': installment.id,
        'paid_amount': _decimalAmount(remainingPaid),
        'status': nextStatus,
      });
    }

    final int remainingLoan = loan.remainingBalanceMinorUnits + amount;
    final List<LoanInstallmentRecord> unpaid =
        await (_database.select(_database.loanInstallments)
              ..where(
                (LoanInstallments row) =>
                    row.loanId.equals(loan.id) &
                    (row.status.equals('unpaid') |
                        row.status.equals('partial')),
              )
              ..orderBy(<OrderingTerm Function(LoanInstallments)>[
                (LoanInstallments row) => OrderingTerm.asc(row.dueDate),
              ]))
            .get();
    await (_database.update(
      _database.loans,
    )..where((Loans row) => row.id.equals(loan.id))).write(
      LoansCompanion(
        remainingBalanceMinorUnits: Value<int>(remainingLoan),
        paidInstallments: Value<int>(paidInstallments),
        nextDueDate: Value<DateTime?>(
          unpaid.isEmpty ? null : unpaid.first.dueDate,
        ),
        status: Value<String>(remainingLoan == 0 ? 'paid' : 'active'),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(loan.localVersion + 1),
      ),
    );
    await _enqueue('loans', loan.id, <String, Object?>{
      'id': loan.id,
      'remaining_balance': _decimalAmount(remainingLoan),
      'paid_installments': paidInstallments,
      'status': remainingLoan == 0 ? 'paid' : 'active',
    });
  }

  Future<void> _reverseSavingsContribution(
    TransactionRecord transaction,
    int amount,
    DateTime now,
  ) async {
    final SavingsContributionRecord contribution =
        await (_database.select(_database.savingsContributions)..where(
              (SavingsContributions row) =>
                  row.transactionId.equals(transaction.id),
            ))
            .getSingle();
    final SavingsGoalRecord goal =
        await (_database.select(_database.savingsGoals)
              ..where((SavingsGoals row) => row.id.equals(contribution.goalId)))
            .getSingle();
    if (goal.currentAmountMinorUnits < amount) {
      throw StateError('Savings goal balance cannot be reversed safely.');
    }
    final int newAmount = goal.currentAmountMinorUnits - amount;
    final String status = newAmount >= goal.targetAmountMinorUnits
        ? 'completed'
        : 'active';
    await (_database.update(
      _database.savingsGoals,
    )..where((SavingsGoals row) => row.id.equals(goal.id))).write(
      SavingsGoalsCompanion(
        currentAmountMinorUnits: Value<int>(newAmount),
        status: Value<String>(status),
        updatedAt: Value<DateTime>(now),
        localVersion: Value<int>(goal.localVersion + 1),
      ),
    );
    await _enqueue('savings_goals', goal.id, <String, Object?>{
      'id': goal.id,
      'current_amount': _decimalAmount(newAmount),
      'status': status,
    });
  }

  Future<String> _ensureLoanProvider(
    String? providerId,
    String name,
    String? userId,
    DateTime now,
  ) async {
    if (providerId != null) {
      final LoanProviderRecord provider = await (_database.select(
        _database.loanProviders,
      )..where((LoanProviders row) => row.id.equals(providerId))).getSingle();
      _requireOwner(userId, provider.userId);
      return provider.id;
    }
    final LoanProviderRecord? existing =
        await (_database.select(_database.loanProviders)..where(
              (LoanProviders row) =>
                  row.name.equals(name) & row.userId.equalsNullable(userId),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final String id = _uuid.v4();
    await _database
        .into(_database.loanProviders)
        .insert(
          LoanProvidersCompanion.insert(
            id: id,
            userId: Value<String?>(userId),
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _enqueue('loan_providers', id, <String, Object?>{
      'id': id,
      'user_id': userId,
      'name': name,
    });
    return id;
  }

  String _allocationKey(CreateAllocationInput input) {
    if (input.relatedBillId != null && input.relatedInstallmentId != null) {
      throw ArgumentError('An allocation can target one obligation at a time.');
    }
    if (input.relatedBillId != null) {
      return '${input.paydayScheduleId}:bill:${input.relatedBillId}';
    }
    if (input.relatedInstallmentId != null) {
      return '${input.paydayScheduleId}:installment:${input.relatedInstallmentId}';
    }
    _requireText(input.allocationKey, 'allocationKey');
    return '${input.paydayScheduleId}:${input.allocationKey.trim()}';
  }

  Future<FinancialAccountRecord> _account(String id) async => (_database.select(
    _database.financialAccounts,
  )..where((FinancialAccounts row) => row.id.equals(id))).getSingle();

  Future<LoanRecord> _loan(String id) async =>
      (_database.select(_database.loans)
            ..where((Loans row) => row.id.equals(id) & row.archivedAt.isNull()))
          .getSingle();

  Future<TransactionRecord?> _transactionByKey(
    String key, {
    required String expectedType,
  }) async {
    _requireText(key, 'idempotencyKey');
    final TransactionRecord? existing =
        await (_database.select(_database.transactions)
              ..where((Transactions row) => row.idempotencyKey.equals(key)))
            .getSingleOrNull();
    if (existing == null) return null;
    if (existing.transactionType != expectedType) {
      throw StateError('Idempotency key was already used by another action.');
    }
    return existing;
  }

  Future<void> _insertTransaction({
    required String id,
    required String? userId,
    required String accountId,
    required String type,
    required String direction,
    required String title,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime occurredAt,
    String? sourceAccountId,
    String? destinationAccountId,
    String? categoryId,
    String? category,
    String? relatedRecordType,
    String? relatedRecordId,
    String? relatedBillId,
    String? relatedLoanId,
    String? relatedInstallmentId,
    String? reversalOfId,
    String? idempotencyKey,
    String? notes,
  }) async {
    _requirePositive(amountMinorUnits, 'amountMinorUnits');
    final DateTime now = _now();
    await _database
        .into(_database.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            userId: Value<String?>(userId),
            accountId: accountId,
            sourceAccountId: Value<String?>(sourceAccountId),
            destinationAccountId: Value<String?>(destinationAccountId),
            transactionType: type,
            direction: Value<String>(direction),
            title: Value<String>(title),
            amountMinorUnits: amountMinorUnits,
            currencyCode: Value<String>(currencyCode),
            description: Value<String?>(_trimOrNull(notes)),
            categoryId: Value<String?>(categoryId),
            category: Value<String?>(_trimOrNull(category)),
            relatedRecordType: Value<String?>(relatedRecordType),
            relatedRecordId: Value<String?>(relatedRecordId),
            relatedBillId: Value<String?>(relatedBillId),
            relatedLoanId: Value<String?>(relatedLoanId),
            relatedInstallmentId: Value<String?>(relatedInstallmentId),
            reversalOfId: Value<String?>(reversalOfId),
            idempotencyKey: Value<String?>(idempotencyKey),
            notes: Value<String?>(_trimOrNull(notes)),
            occurredAt: occurredAt.toUtc(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _enqueue('transactions', id, <String, Object?>{
      'id': id,
      'user_id': userId,
      'account_id': accountId,
      'source_account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'transaction_type': type,
      'direction': direction,
      'title': title,
      'amount': _decimalAmount(amountMinorUnits),
      'currency_code': currencyCode,
      'category_id': categoryId,
      'category': _trimOrNull(category),
      'related_record_type': relatedRecordType,
      'related_record_id': relatedRecordId,
      'related_bill_id': relatedBillId,
      'related_loan_id': relatedLoanId,
      'related_installment_id': relatedInstallmentId,
      'reversal_of_id': reversalOfId,
      'idempotency_key': idempotencyKey,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    });
  }

  Future<void> _setAccount(
    FinancialAccountRecord account, {
    int? currentBalanceMinorUnits,
    int? outstandingCreditMinorUnits,
    required DateTime updatedAt,
  }) async {
    final int nextVersion = account.localVersion + 1;
    await (_database.update(
      _database.financialAccounts,
    )..where((FinancialAccounts row) => row.id.equals(account.id))).write(
      FinancialAccountsCompanion(
        currentBalanceMinorUnits: currentBalanceMinorUnits == null
            ? const Value<int>.absent()
            : Value<int>(currentBalanceMinorUnits),
        outstandingCreditMinorUnits: outstandingCreditMinorUnits == null
            ? const Value<int>.absent()
            : Value<int>(outstandingCreditMinorUnits),
        updatedAt: Value<DateTime>(updatedAt),
        localVersion: Value<int>(nextVersion),
        syncState: const Value<String>('pending'),
      ),
    );
    await _enqueue('financial_accounts', account.id, <String, Object?>{
      ..._accountSyncPayload(account),
      'current_balance': _decimalAmount(
        currentBalanceMinorUnits ?? account.currentBalanceMinorUnits,
      ),
      'outstanding_credit_balance': _decimalAmount(
        outstandingCreditMinorUnits ?? account.outstandingCreditMinorUnits,
      ),
    });
  }

  Map<String, Object?> _accountSyncPayload(FinancialAccountRecord account) =>
      <String, Object?>{
        'id': account.id,
        'user_id': account.userId,
        'name': account.name,
        'provider': account.provider,
        'account_type': account.accountType,
        'opening_balance': _decimalAmount(account.openingBalanceMinorUnits),
        'current_balance': _decimalAmount(account.currentBalanceMinorUnits),
        'credit_limit': _decimalAmount(account.creditLimitMinorUnits),
        'outstanding_credit_balance': _decimalAmount(
          account.outstandingCreditMinorUnits,
        ),
        'opening_outstanding_credit_balance': _decimalAmount(
          account.openingOutstandingCreditMinorUnits,
        ),
        'statement_balance': _decimalAmount(account.statementBalanceMinorUnits),
        'minimum_payment': _decimalAmount(account.minimumPaymentMinorUnits),
        'currency_code': account.currencyCode,
        'statement_date': _dateOnly(account.statementDate),
        'payment_due_date': _dateOnly(account.paymentDueDate),
        'account_number_suffix': account.accountNumberSuffix,
        'linked_account_id': account.linkedAccountId,
        'custom_type_name': account.customTypeName,
        'icon_key': account.iconKey,
        'color_argb': account.colorArgb,
        'notes': account.notes,
        'allow_negative_balance': account.allowNegativeBalance,
        'is_active': account.isActive,
        'archived_at': account.archivedAt?.toIso8601String(),
      };

  Future<void> _enqueue(
    String entityType,
    String entityId,
    Map<String, Object?> payload,
  ) => SyncQueueStore(_database).enqueue(
    entityType: entityType,
    entityId: entityId,
    operation: 'upsert',
    payload: payload,
  );

  AccountBalance _accountSnapshot(FinancialAccountRecord row) => AccountBalance(
    id: row.id,
    accountType: row.accountType,
    currencyCode: row.currencyCode,
    currentBalanceMinorUnits: row.currentBalanceMinorUnits,
    creditLimitMinorUnits: row.creditLimitMinorUnits,
    outstandingCreditMinorUnits: row.outstandingCreditMinorUnits,
    isActive: row.isActive && row.archivedAt == null,
    linkedAccountId: row.linkedAccountId,
    allowNegativeBalance: row.allowNegativeBalance,
  );

  FinancialAccount _financialAccountEntity(FinancialAccountRecord row) =>
      FinancialAccount(
        id: row.id,
        name: row.name,
        accountType: row.accountType,
        currentBalanceMinorUnits: row.currentBalanceMinorUnits,
        currencyCode: row.currencyCode,
        isActive: row.isActive,
        openingBalanceMinorUnits: row.openingBalanceMinorUnits,
        provider: row.provider,
        creditLimitMinorUnits: row.creditLimitMinorUnits,
        outstandingCreditMinorUnits: row.outstandingCreditMinorUnits,
        openingOutstandingCreditMinorUnits:
            row.openingOutstandingCreditMinorUnits,
        statementBalanceMinorUnits: row.statementBalanceMinorUnits,
        minimumPaymentMinorUnits: row.minimumPaymentMinorUnits,
        statementDate: row.statementDate,
        paymentDueDate: row.paymentDueDate,
        accountNumberSuffix: row.accountNumberSuffix,
        linkedAccountId: row.linkedAccountId,
        customTypeName: row.customTypeName,
        iconKey: row.iconKey,
        colorArgb: row.colorArgb,
        notes: row.notes,
        allowNegativeBalance: row.allowNegativeBalance,
        archivedAt: row.archivedAt,
        createdAt: row.createdAt,
      );

  FinancialTransactionView _transactionView(TransactionRecord row) =>
      FinancialTransactionView(
        id: row.id,
        type: row.transactionType,
        title: row.title.isEmpty ? (row.description ?? '') : row.title,
        amountMinorUnits: row.amountMinorUnits,
        currencyCode: row.currencyCode,
        occurredAt: row.occurredAt,
        sourceAccountId: row.sourceAccountId,
        destinationAccountId: row.destinationAccountId,
        relatedRecordId:
            row.relatedRecordId ?? row.relatedBillId ?? row.relatedLoanId,
        reversalOfId: row.reversalOfId,
        direction: row.direction,
        category: row.category,
        description: row.description,
        notes: row.notes,
      );

  void _requireCashAccount(FinancialAccountRecord account) {
    _requireActiveAccount(account);
    if (_isCreditCard(account.accountType)) {
      throw ArgumentError('This operation requires an actual cash account.');
    }
    if (account.accountType == 'debit_card' &&
        account.linkedAccountId != null) {
      throw ArgumentError(
        'Use the linked deposit account to change this debit card balance.',
      );
    }
  }

  void _requireActiveAccount(FinancialAccountRecord account) {
    if (!account.isActive || account.archivedAt != null) {
      throw StateError('This account is inactive.');
    }
  }

  bool _isCreditCard(String accountType) =>
      accountType.toLowerCase().replaceAll(RegExp(r'[_\s-]'), '') ==
      'creditcard';

  void _requireOwner(String? firstUserId, String? secondUserId) {
    if (firstUserId != null &&
        secondUserId != null &&
        firstUserId != secondUserId) {
      throw StateError('Financial records must belong to the same user.');
    }
  }

  void _requireSameCurrency(String first, String second) {
    if (first != second) throw StateError('Currencies do not match.');
  }

  void _requireCurrency(String currencyCode) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw ArgumentError.value(currencyCode, 'currencyCode');
    }
  }

  void _requireFrequency(String frequency) {
    const Set<String> allowed = <String>{
      'one_time',
      'weekly',
      'biweekly',
      'monthly',
      'quarterly',
      'semiannual',
      'annual',
      'custom',
      'irregular',
    };
    if (!allowed.contains(frequency)) {
      throw ArgumentError.value(frequency, 'frequency');
    }
  }

  void _requireLoanFrequency(String frequency) {
    const Set<String> allowed = <String>{
      'weekly',
      'biweekly',
      'monthly',
      'quarterly',
      'semiannual',
      'annual',
      'custom',
      'irregular',
    };
    if (!allowed.contains(frequency)) {
      throw ArgumentError.value(frequency, 'paymentFrequency');
    }
  }

  void _requireText(String value, String name) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  }

  void _requirePositive(int amount, String name) {
    if (amount <= 0) throw ArgumentError.value(amount, name);
  }

  void _requireNonNegative(int amount, String name) {
    if (amount < 0) throw ArgumentError.value(amount, name);
  }

  void _requireAccountBalance(
    int amount,
    String accountType,
    bool allowNegativeBalance,
  ) {
    if (amount >= 0) return;
    if (!allowNegativeBalance ||
        !<String>{'bank', 'custom', 'other'}.contains(accountType)) {
      throw ArgumentError(
        'A negative balance is only allowed for eligible overdraft accounts.',
      );
    }
  }

  void _validateAccountNumberSuffix(String? suffix) {
    final String? value = _trimOrNull(suffix);
    if (value != null && !RegExp(r'^\d{4}$').hasMatch(value)) {
      throw ArgumentError.value(
        suffix,
        'accountNumberSuffix',
        'Store only the last four digits.',
      );
    }
  }

  DateTime _now() => DateTime.now().toUtc();

  DateTime? _asUtc(DateTime? value) =>
      value == null ? null : DateTime.utc(value.year, value.month, value.day);

  DateTime _asUtcDate(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  String _decimalAmount(int minorUnits) {
    final int absolute = minorUnits.abs();
    final String sign = minorUnits < 0 ? '-' : '';
    final String whole = (absolute ~/ 100).toString();
    final String fraction = (absolute % 100).toString().padLeft(2, '0');
    return '$sign$whole.$fraction';
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String? _trimOrNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
