import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

const int php100 = 10000;
const int php1000 = 100000;
const int php10000 = 1000000;

void main() {
  group('FinancialCalculator', () {
    test('available money excludes credit limits and inactive accounts', () {
      const List<AccountBalance> accounts = <AccountBalance>[
        AccountBalance(
          id: 'cash',
          accountType: 'cash',
          currencyCode: 'PHP',
          currentBalanceMinorUnits: php10000,
        ),
        AccountBalance(
          id: 'bank',
          accountType: 'savings',
          currencyCode: 'PHP',
          currentBalanceMinorUnits: php10000 * 2,
        ),
        AccountBalance(
          id: 'card',
          accountType: 'credit_card',
          currencyCode: 'PHP',
          currentBalanceMinorUnits: 0,
          creditLimitMinorUnits: php10000 * 5,
          outstandingCreditMinorUnits: php10000,
        ),
        AccountBalance(
          id: 'archived',
          accountType: 'cash',
          currencyCode: 'PHP',
          currentBalanceMinorUnits: php10000,
          isActive: false,
        ),
      ];

      expect(FinancialCalculator.actualAvailableMoney(accounts), php10000 * 3);
    });

    test('available credit equals limit less outstanding balance', () {
      expect(
        FinancialCalculator.availableCredit(
          creditLimitMinorUnits: php10000 * 5,
          outstandingMinorUnits: php10000,
        ),
        php10000 * 4,
      );
    });

    test('projected money subtracts obligations and planned expenses', () {
      expect(
        FinancialCalculator.projectedRemainingMoney(
          actualAvailableMinorUnits: php10000 * 3,
          expectedIncomeMinorUnits: php10000,
          upcomingObligationsMinorUnits: php10000 * 2,
          plannedExpensesMinorUnits: php10000,
        ),
        php10000,
      );
    });
  });

  group('LocalFinancialDataSource', () {
    late AppDatabase database;
    late LocalFinancialDataSource dataSource;
    final DateTime now = DateTime.utc(2026, 11, 3, 12);

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      dataSource = LocalFinancialDataSource(database);
    });

    tearDown(() async => database.close());

    Future<String> account({
      required String name,
      String type = 'cash',
      int balance = php10000,
      int creditLimit = 0,
      int outstanding = 0,
    }) => dataSource.createAccount(
      CreateAccountInput(
        name: name,
        accountType: type,
        openingBalanceMinorUnits: balance,
        creditLimitMinorUnits: creditLimit,
        outstandingCreditMinorUnits: outstanding,
      ),
    );

    Future<int> balanceOf(String id) async => (await (database.select(
      database.financialAccounts,
    )..where((row) => row.id.equals(id))).getSingle()).currentBalanceMinorUnits;

    test(
      'transfer atomically debits and credits without changing total cash',
      () async {
        final String sourceId = await account(name: 'Cash', balance: php10000);
        final String destinationId = await account(
          name: 'Bank',
          type: 'savings',
          balance: php10000 * 2,
        );

        await dataSource.transfer(
          TransferInput(
            fromAccountId: sourceId,
            toAccountId: destinationId,
            amountMinorUnits: php1000,
            transferredAt: now,
            idempotencyKey: 'transfer-1',
          ),
        );

        expect(await balanceOf(sourceId), php10000 - php1000);
        expect(await balanceOf(destinationId), php10000 * 2 + php1000);
        final List<TransactionRecord> transactions = await database
            .select(database.transactions)
            .get();
        expect(transactions.single.transactionType, 'account_transfer');
        expect(transactions.single.amountMinorUnits, php1000);
      },
    );

    test(
      'immediate income and expense preserve transaction links atomically',
      () async {
        final String accountId = await account(name: 'Manual ledger');
        final String incomeTransactionId = await dataSource.recordIncome(
          RecordIncomeInput(
            source: 'Cash income',
            accountId: accountId,
            amountMinorUnits: php100,
            occurredAt: now,
            idempotencyKey: 'manual-income-ledger',
          ),
        );
        final int afterIncome = await balanceOf(accountId);
        expect(afterIncome, php10000 + php100);
        final income = await database
            .select(database.incomeRecords)
            .getSingle();
        expect(income.transactionId, incomeTransactionId);

        final String expenseTransactionId = await dataSource.recordExpense(
          RecordExpenseInput(
            title: 'Cash expense',
            accountId: accountId,
            amountMinorUnits: php100,
            occurredAt: now,
            idempotencyKey: 'manual-expense-ledger',
          ),
        );
        expect(await balanceOf(accountId), afterIncome - php100);
        final expense = await database.select(database.expenses).getSingle();
        expect(expense.transactionId, expenseTransactionId);
        expect(
          await database.select(database.transactions).get(),
          hasLength(2),
        );

        expect(
          await dataSource.recordIncome(
            RecordIncomeInput(
              source: 'Cash income',
              accountId: accountId,
              amountMinorUnits: php100,
              occurredAt: now,
              idempotencyKey: 'manual-income-ledger',
            ),
          ),
          incomeTransactionId,
        );
        expect(await balanceOf(accountId), afterIncome - php100);
        expect(
          await database.select(database.transactions).get(),
          hasLength(2),
        );
      },
    );

    test('expected income changes balance only after confirmation', () async {
      final String accountId = await account(name: 'Bank');
      final String incomeId = await dataSource.createIncome(
        CreateIncomeInput(
          source: 'Salary',
          amountMinorUnits: php10000,
          expectedDate: now,
          receivingAccountId: accountId,
        ),
      );
      expect(await balanceOf(accountId), php10000);

      final String transactionId = await dataSource.confirmIncome(
        ConfirmIncomeInput(
          incomeId: incomeId,
          accountId: accountId,
          receivedAt: now,
          idempotencyKey: 'income-1',
        ),
      );

      expect(await balanceOf(accountId), php10000 * 2);
      final IncomeRecord income = await (database.select(
        database.incomeRecords,
      )..where((row) => row.id.equals(incomeId))).getSingle();
      expect(income.status, 'received');
      expect(income.transactionId, transactionId);
    });

    test('planned expense changes balance only when confirmed', () async {
      final String accountId = await account(name: 'Cash');
      final String expenseId = await dataSource.createExpense(
        CreateExpenseInput(
          title: 'Groceries',
          amountMinorUnits: php1000,
          occurredAt: now,
        ),
      );
      expect(await balanceOf(accountId), php10000);

      await dataSource.confirmExpense(
        ConfirmExpenseInput(
          expenseId: expenseId,
          accountId: accountId,
          confirmedAt: now,
          idempotencyKey: 'expense-1',
        ),
      );

      expect(await balanceOf(accountId), php10000 - php1000);
      final ExpenseRecord expense = await (database.select(
        database.expenses,
      )..where((row) => row.id.equals(expenseId))).getSingle();
      expect(expense.status, 'confirmed');
    });

    test('planned credit-card expense increases debt when recorded', () async {
      final String cardId = await account(
        name: 'Visa',
        type: 'credit_card',
        balance: 0,
        creditLimit: php10000 * 5,
      );
      final String expenseId = await dataSource.createExpense(
        CreateExpenseInput(
          title: 'Groceries on card',
          amountMinorUnits: php1000,
          occurredAt: now,
          paymentAccountId: cardId,
        ),
      );

      await dataSource.confirmExpense(
        ConfirmExpenseInput(
          expenseId: expenseId,
          accountId: cardId,
          confirmedAt: now,
          idempotencyKey: 'card-expense-1',
        ),
      );

      final card = await (database.select(
        database.financialAccounts,
      )..where((row) => row.id.equals(cardId))).getSingle();
      final transaction =
          await (database.select(database.transactions)
                ..where((row) => row.idempotencyKey.equals('card-expense-1')))
              .getSingle();
      expect(card.currentBalanceMinorUnits, 0);
      expect(card.outstandingCreditMinorUnits, php1000);
      expect(transaction.transactionType, 'credit_card_purchase');
    });

    test(
      'expected income edits and cancels without changing account balance',
      () async {
        final String accountId = await account(name: 'Bank');
        final String incomeId = await dataSource.createIncome(
          CreateIncomeInput(
            source: 'Salary',
            amountMinorUnits: php1000,
            expectedDate: now,
          ),
        );

        await dataSource.updateIncome(
          UpdateIncomeInput(
            incomeId: incomeId,
            source: 'Monthly salary',
            amountMinorUnits: php10000,
            expectedDate: now,
            frequency: 'monthly',
            receivingAccountId: accountId,
          ),
        );
        await dataSource.cancelIncome(incomeId);

        final IncomeRecord income = await (database.select(
          database.incomeRecords,
        )..where((row) => row.id.equals(incomeId))).getSingle();
        expect(income.status, 'cancelled');
        expect(income.amountMinorUnits, php10000);
        expect(await balanceOf(accountId), php10000);
      },
    );

    test(
      'planned expense edits and cancels without recording a transaction',
      () async {
        final String accountId = await account(name: 'Cash');
        final String expenseId = await dataSource.createExpense(
          CreateExpenseInput(
            title: 'Old title',
            amountMinorUnits: php100,
            occurredAt: now,
          ),
        );
        await dataSource.updateExpense(
          UpdateExpenseInput(
            expenseId: expenseId,
            title: 'Updated title',
            amountMinorUnits: php1000,
            occurredAt: now,
            paymentAccountId: accountId,
          ),
        );
        await dataSource.cancelExpense(expenseId);

        final ExpenseRecord expense = await (database.select(
          database.expenses,
        )..where((row) => row.id.equals(expenseId))).getSingle();
        expect(expense.title, 'Updated title');
        expect(expense.status, 'cancelled');
        expect(await balanceOf(accountId), php10000);
        expect(await database.select(database.transactions).get(), isEmpty);
      },
    );

    test(
      'bill creation does not deduct money; confirmed payment does',
      () async {
        final String accountId = await account(name: 'Cash');
        final String billId = await dataSource.createBill(
          CreateBillInput(
            name: 'Electricity',
            amountMinorUnits: php1000,
            dueDate: now,
            paymentAccountId: accountId,
            automaticAllocation: true,
          ),
        );
        expect(await balanceOf(accountId), php10000);

        await dataSource.confirmBillPayment(
          BillPaymentInput(
            billId: billId,
            accountId: accountId,
            amountMinorUnits: php1000,
            occurrenceKey: '2026-11',
            paidAt: now,
            idempotencyKey: 'bill-payment-1',
          ),
        );

        expect(await balanceOf(accountId), php10000 - php1000);
        expect(
          await database.select(database.billPayments).get(),
          hasLength(1),
        );
      },
    );

    test(
      'bill partial payments complete one period and duplicates do not deduct twice',
      () async {
        final String accountId = await account(name: 'Cash');
        final String billId = await dataSource.createBill(
          CreateBillInput(
            name: 'Water',
            amountMinorUnits: php1000,
            dueDate: now,
          ),
        );
        final BillPaymentInput first = BillPaymentInput(
          billId: billId,
          accountId: accountId,
          amountMinorUnits: php100,
          occurrenceKey: '2026-11-03',
          paidAt: now,
          idempotencyKey: 'bill-partial-1',
        );
        await dataSource.confirmBillPayment(first);
        var bill = await (database.select(
          database.bills,
        )..where((row) => row.id.equals(billId))).getSingle();
        expect(bill.status, 'partial');
        expect(await balanceOf(accountId), php10000 - php100);

        final BillPaymentInput second = BillPaymentInput(
          billId: billId,
          accountId: accountId,
          amountMinorUnits: php1000 - php100,
          occurrenceKey: '2026-11-03',
          paidAt: now,
          idempotencyKey: 'bill-partial-2',
        );
        final String transactionId = await dataSource.confirmBillPayment(
          second,
        );
        final String duplicateId = await dataSource.confirmBillPayment(second);
        bill = await (database.select(
          database.bills,
        )..where((row) => row.id.equals(billId))).getSingle();
        expect(duplicateId, transactionId);
        expect(bill.status, 'paid');
        expect(await balanceOf(accountId), php10000 - php1000);
        expect(
          await database.select(database.billPayments).get(),
          hasLength(2),
        );
      },
    );

    test(
      'reversing a bill payment restores cash and reopens the bill',
      () async {
        final String accountId = await account(name: 'Cash');
        final String billId = await dataSource.createBill(
          CreateBillInput(
            name: 'Internet',
            amountMinorUnits: php1000,
            dueDate: now,
          ),
        );
        final String transactionId = await dataSource.confirmBillPayment(
          BillPaymentInput(
            billId: billId,
            accountId: accountId,
            amountMinorUnits: php1000,
            occurrenceKey: '2026-11-03',
            paidAt: now,
            idempotencyKey: 'bill-reverse-1',
          ),
        );

        await dataSource.reverseTransaction(
          transactionId: transactionId,
          reversedAt: now,
          idempotencyKey: 'bill-reverse-key',
        );

        final bill = await (database.select(
          database.bills,
        )..where((row) => row.id.equals(billId))).getSingle();
        final payment = await database
            .select(database.billPayments)
            .getSingle();
        expect(await balanceOf(accountId), php10000);
        expect(bill.status, 'unpaid');
        expect(payment.reversedAt, isNotNull);
      },
    );

    test(
      'skipping a period creates a marker without a transaction or deduction',
      () async {
        final String accountId = await account(name: 'Cash');
        final String billId = await dataSource.createBill(
          CreateBillInput(
            name: 'Phone',
            amountMinorUnits: php1000,
            dueDate: now,
          ),
        );
        await dataSource.skipBillOccurrence(
          SkipBillOccurrenceInput(
            billId: billId,
            accountId: accountId,
            occurrenceKey: '2026-11-03',
            skippedAt: now,
            idempotencyKey: 'bill-skip-1',
          ),
        );
        final payment = await database
            .select(database.billPayments)
            .getSingle();
        expect(payment.amountMinorUnits, 0);
        expect(payment.notes, startsWith('[skipped]'));
        expect(await balanceOf(accountId), php10000);
        expect(await database.select(database.transactions).get(), isEmpty);
      },
    );

    test(
      'bill with payment history cannot be removed and archives safely',
      () async {
        final String accountId = await account(name: 'Cash');
        final String billId = await dataSource.createBill(
          CreateBillInput(
            name: 'Rent',
            amountMinorUnits: php1000,
            dueDate: now,
          ),
        );
        await dataSource.confirmBillPayment(
          BillPaymentInput(
            billId: billId,
            accountId: accountId,
            amountMinorUnits: php1000,
            occurrenceKey: '2026-11-03',
            paidAt: now,
            idempotencyKey: 'bill-archive-1',
          ),
        );

        await expectLater(dataSource.deleteBill(billId), throwsStateError);
        await dataSource.archiveBill(billId);

        expect(await database.select(database.bills).get(), hasLength(1));
        expect(
          await database.select(database.billPayments).get(),
          hasLength(1),
        );
      },
    );

    test(
      'loan installment supports a partial payment and updates balances',
      () async {
        final String accountId = await account(name: 'Cash');
        final String loanId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'Phone plan',
            providerName: 'BillEase',
            principalMinorUnits: php10000 * 2,
            openedAt: now,
          ),
        );
        final String installmentId = await dataSource.createInstallment(
          CreateInstallmentInput(
            loanId: loanId,
            installmentNumber: 1,
            dueDate: now,
            scheduledAmountMinorUnits: php1000,
          ),
        );

        await dataSource.confirmLoanPayment(
          LoanPaymentInput(
            loanId: loanId,
            installmentId: installmentId,
            accountId: accountId,
            amountMinorUnits: php100,
            paidAt: now,
            idempotencyKey: 'loan-partial-1',
          ),
        );

        expect(await balanceOf(accountId), php10000 - php100);
        final LoanInstallmentRecord installment = await (database.select(
          database.loanInstallments,
        )..where((row) => row.id.equals(installmentId))).getSingle();
        final LoanRecord loan = await (database.select(
          database.loans,
        )..where((row) => row.id.equals(loanId))).getSingle();
        expect(installment.status, 'partial');
        expect(installment.paidMinorUnits, php100);
        expect(loan.remainingBalanceMinorUnits, php10000 * 2 - php100);
      },
    );

    test(
      'separate loans may share a provider without wallet deposits',
      () async {
        final String firstId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'GCash Loan A',
            providerName: 'GCash',
            principalMinorUnits: php1000,
            openedAt: now,
          ),
        );
        final String secondId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'GCash Loan B',
            providerName: 'GCash',
            principalMinorUnits: php1000 * 2,
            openedAt: now,
          ),
        );
        final LoanRecord first = await (database.select(
          database.loans,
        )..where((row) => row.id.equals(firstId))).getSingle();
        final LoanRecord second = await (database.select(
          database.loans,
        )..where((row) => row.id.equals(secondId))).getSingle();

        expect(first.id, isNot(second.id));
        expect(first.providerId, second.providerId);
        expect(first.remainingBalanceMinorUnits, php1000);
        expect(second.remainingBalanceMinorUnits, php1000 * 2);
        expect(await database.select(database.transactions).get(), isEmpty);
      },
    );

    test(
      'loan funds are credited only through explicit disbursement confirmation',
      () async {
        final String accountId = await account(name: 'Bank');
        final String loanId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'New loan',
            providerName: 'Maya Credit',
            principalMinorUnits: php1000 * 5,
            openedAt: now,
            totalRepaymentMinorUnits: php1000 * 6,
            totalInterestMinorUnits: php1000,
          ),
        );
        expect(await balanceOf(accountId), php10000);
        final String transactionId = await dataSource.recordLoanDisbursement(
          LoanDisbursementInput(
            loanId: loanId,
            accountId: accountId,
            amountMinorUnits: php1000 * 4,
            receivedAt: now,
            idempotencyKey: 'loan-disbursement-1',
          ),
        );
        expect(await balanceOf(accountId), php10000 + php1000 * 4);
        final TransactionRecord transaction = await (database.select(
          database.transactions,
        )..where((row) => row.id.equals(transactionId))).getSingle();
        expect(transaction.transactionType, 'loan_disbursement');
        expect(transaction.direction, 'inflow');
        expect(transaction.relatedLoanId, loanId);
        expect(
          (await (database.select(
                database.loans,
              )..where((row) => row.id.equals(loanId))).getSingle())
              .remainingBalanceMinorUnits,
          php1000 * 6,
        );
        await dataSource.reverseTransaction(
          transactionId: transactionId,
          reversedAt: now.add(const Duration(days: 1)),
          idempotencyKey: 'loan-disbursement-reversal',
        );
        expect(await balanceOf(accountId), php10000);
      },
    );

    test('lender balance adjustment is explicit and wallet-neutral', () async {
      final String accountId = await account(name: 'Cash');
      final String loanId = await dataSource.createLoan(
        CreateLoanInput(
          name: 'Settled loan',
          providerName: 'Atome',
          principalMinorUnits: php1000,
          openedAt: now,
        ),
      );
      final String installmentId = await dataSource.createInstallment(
        CreateInstallmentInput(
          loanId: loanId,
          installmentNumber: 1,
          dueDate: now.subtract(const Duration(days: 5)),
          scheduledAmountMinorUnits: php1000,
        ),
      );

      await dataSource.adjustLoanBalance(
        AdjustLoanBalanceInput(
          loanId: loanId,
          remainingBalanceMinorUnits: 0,
          adjustedAt: now,
          reason: 'Lender confirmed settlement',
        ),
      );

      final LoanRecord loan = await (database.select(
        database.loans,
      )..where((row) => row.id.equals(loanId))).getSingle();
      final LoanInstallmentRecord installment = await (database.select(
        database.loanInstallments,
      )..where((row) => row.id.equals(installmentId))).getSingle();
      expect(loan.status, 'paid');
      expect(loan.remainingBalanceMinorUnits, 0);
      expect(loan.notes, contains('Lender confirmed settlement'));
      expect(installment.status, 'settled');
      expect(await balanceOf(accountId), php10000);
      expect(await database.select(database.transactions).get(), isEmpty);
    });

    test(
      'loan repayment can be recorded without wallet deduction and reversed',
      () async {
        final String accountId = await account(name: 'Cash');
        final String loanId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'Recorded loan',
            providerName: 'GCash',
            principalMinorUnits: php1000 * 2,
            openedAt: now,
          ),
        );
        final String installmentId = await dataSource.createInstallment(
          CreateInstallmentInput(
            loanId: loanId,
            installmentNumber: 1,
            dueDate: now,
            scheduledAmountMinorUnits: php1000,
          ),
        );
        final String paymentId = await dataSource.confirmLoanPayment(
          LoanPaymentInput(
            loanId: loanId,
            installmentId: installmentId,
            amountMinorUnits: php100,
            paidAt: now.subtract(const Duration(days: 1)),
            idempotencyKey: 'loan-no-wallet-payment',
          ),
        );
        expect(await balanceOf(accountId), php10000);
        final LoanPaymentRecord payment = await (database.select(
          database.loanPayments,
        )..where((row) => row.id.equals(paymentId))).getSingle();
        expect(payment.accountId, isNull);
        expect(payment.transactionId, isNull);
        expect(payment.status, 'confirmed');
        expect(
          payment.paidAt.isAtSameMomentAs(
            now.subtract(const Duration(days: 1)),
          ),
          isTrue,
        );

        await dataSource.reverseUnaccountedLoanPayment(payment.id);

        final LoanRecord loan = await (database.select(
          database.loans,
        )..where((row) => row.id.equals(loanId))).getSingle();
        expect(loan.remainingBalanceMinorUnits, php1000 * 2);
        expect(await balanceOf(accountId), php10000);
        expect(
          (await (database.select(
            database.loanPayments,
          )..where((row) => row.id.equals(payment.id))).getSingle()).status,
          'reversed',
        );
      },
    );

    test(
      'full loan payment completes installment and updates loan balance',
      () async {
        final String accountId = await account(name: 'Cash');
        final String loanId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'Small loan',
            providerName: 'Tala',
            principalMinorUnits: php1000 * 2,
            openedAt: now,
          ),
        );
        final String installmentId = await dataSource.createInstallment(
          CreateInstallmentInput(
            loanId: loanId,
            installmentNumber: 1,
            dueDate: now,
            scheduledAmountMinorUnits: php1000,
          ),
        );

        await dataSource.confirmLoanPayment(
          LoanPaymentInput(
            loanId: loanId,
            installmentId: installmentId,
            accountId: accountId,
            amountMinorUnits: php1000,
            paidAt: now,
            idempotencyKey: 'loan-full-1',
          ),
        );

        final LoanInstallmentRecord installment = await (database.select(
          database.loanInstallments,
        )..where((row) => row.id.equals(installmentId))).getSingle();
        final LoanRecord loan = await (database.select(
          database.loans,
        )..where((row) => row.id.equals(loanId))).getSingle();
        expect(installment.status, 'paid');
        expect(loan.remainingBalanceMinorUnits, php1000);
        expect(loan.paidInstallments, 1);
      },
    );

    test(
      'repeating a loan payment with the same key does not deduct twice',
      () async {
        final String accountId = await account(name: 'Cash');
        final String loanId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'Loan',
            providerName: 'Maya Credit',
            principalMinorUnits: php1000,
            openedAt: now,
          ),
        );
        final String installmentId = await dataSource.createInstallment(
          CreateInstallmentInput(
            loanId: loanId,
            installmentNumber: 1,
            dueDate: now,
            scheduledAmountMinorUnits: php1000,
          ),
        );
        final LoanPaymentInput payment = LoanPaymentInput(
          loanId: loanId,
          installmentId: installmentId,
          accountId: accountId,
          amountMinorUnits: php1000,
          paidAt: now,
          idempotencyKey: 'loan-retry-1',
        );

        final String first = await dataSource.confirmLoanPayment(payment);
        final String retry = await dataSource.confirmLoanPayment(payment);

        expect(retry, first);
        expect(await balanceOf(accountId), php10000 - php1000);
        expect(
          await database.select(database.loanPayments).get(),
          hasLength(1),
        );
      },
    );

    test(
      'expense reversal restores balance and preserves both transactions',
      () async {
        final String accountId = await account(name: 'Cash');
        final String expenseId = await dataSource.createExpense(
          CreateExpenseInput(
            title: 'Medicine',
            amountMinorUnits: php1000,
            occurredAt: now,
          ),
        );
        final String originalId = await dataSource.confirmExpense(
          ConfirmExpenseInput(
            expenseId: expenseId,
            accountId: accountId,
            confirmedAt: now,
            idempotencyKey: 'expense-original',
          ),
        );

        final String reversalId = await dataSource.reverseTransaction(
          transactionId: originalId,
          reversedAt: now.add(const Duration(days: 1)),
          idempotencyKey: 'expense-reversal',
        );
        final String repeatedReversalId = await dataSource.reverseTransaction(
          transactionId: originalId,
          reversedAt: now.add(const Duration(days: 1)),
          idempotencyKey: 'expense-reversal-retry',
        );

        expect(repeatedReversalId, reversalId);
        expect(await balanceOf(accountId), php10000);
        final List<TransactionRecord> rows = await database
            .select(database.transactions)
            .get();
        expect(rows, hasLength(2));
        expect(
          rows.map((row) => row.transactionType),
          containsAll(<String>['expense', 'reversal']),
        );
      },
    );

    test(
      'loan payment reversal restores account, installment, and loan balances',
      () async {
        final String accountId = await account(name: 'Cash');
        final String loanId = await dataSource.createLoan(
          CreateLoanInput(
            name: 'Installment loan',
            providerName: 'Home Credit',
            principalMinorUnits: php1000,
            openedAt: now,
          ),
        );
        final String installmentId = await dataSource.createInstallment(
          CreateInstallmentInput(
            loanId: loanId,
            installmentNumber: 1,
            dueDate: now,
            scheduledAmountMinorUnits: php1000,
          ),
        );
        final String paymentId = await dataSource.confirmLoanPayment(
          LoanPaymentInput(
            loanId: loanId,
            installmentId: installmentId,
            accountId: accountId,
            amountMinorUnits: php1000,
            paidAt: now,
            idempotencyKey: 'loan-reversible-payment',
          ),
        );

        await dataSource.reverseTransaction(
          transactionId: paymentId,
          reversedAt: now.add(const Duration(days: 1)),
          idempotencyKey: 'loan-payment-reversal',
        );

        expect(await balanceOf(accountId), php10000);
        final LoanRecord loan = await (database.select(
          database.loans,
        )..where((row) => row.id.equals(loanId))).getSingle();
        final LoanInstallmentRecord installment = await (database.select(
          database.loanInstallments,
        )..where((row) => row.id.equals(installmentId))).getSingle();
        final LoanPaymentRecord payment = await (database.select(
          database.loanPayments,
        )..where((row) => row.transactionId.equals(paymentId))).getSingle();
        expect(loan.remainingBalanceMinorUnits, php1000);
        expect(loan.paidInstallments, 0);
        expect(loan.status, 'active');
        expect(installment.status, 'unpaid');
        expect(installment.paidMinorUnits, 0);
        expect(payment.status, 'reversed');
      },
    );

    test('balance reconciliation records a signed difference', () async {
      final String accountId = await account(name: 'Cash');

      final String? transactionId = await dataSource.reconcileAccount(
        ReconcileAccountInput(
          accountId: accountId,
          actualBalanceMinorUnits: php10000 - php100,
          reconciledAt: now,
          idempotencyKey: 'reconcile-1',
        ),
      );

      expect(transactionId, isNotNull);
      expect(await balanceOf(accountId), php10000 - php100);
      final TransactionRecord adjustment = await (database.select(
        database.transactions,
      )..where((row) => row.id.equals(transactionId!))).getSingle();
      expect(adjustment.transactionType, 'balance_adjustment');
      expect(adjustment.direction, 'outflow');
      expect(adjustment.amountMinorUnits, php100);
    });

    test(
      'credit purchase and payment change credit and cash separately',
      () async {
        final String cashId = await account(
          name: 'Bank',
          type: 'savings',
          balance: php10000 * 2,
        );
        final String cardId = await account(
          name: 'Card',
          type: 'credit_card',
          balance: 0,
          creditLimit: php10000 * 5,
          outstanding: php10000,
        );

        final String purchaseId = await dataSource.recordCreditCardPurchase(
          CreditPurchaseInput(
            creditAccountId: cardId,
            title: 'Fuel',
            amountMinorUnits: php1000,
            occurredAt: now,
            idempotencyKey: 'card-purchase-1',
          ),
        );
        final FinancialAccountRecord cardAfterPurchase = await (database.select(
          database.financialAccounts,
        )..where((row) => row.id.equals(cardId))).getSingle();
        expect(
          cardAfterPurchase.outstandingCreditMinorUnits,
          php10000 + php1000,
        );
        expect(
          FinancialCalculator.actualAvailableMoney(
            await dataSource.watchAccounts().first,
          ),
          php10000 * 2,
        );

        await dataSource.recordCreditCardPayment(
          CreditPaymentInput(
            cashAccountId: cashId,
            creditAccountId: cardId,
            amountMinorUnits: php1000,
            paidAt: now,
            idempotencyKey: 'card-payment-1',
          ),
        );

        expect(await balanceOf(cashId), php10000 * 2 - php1000);
        final FinancialAccountRecord cardAfterPayment = await (database.select(
          database.financialAccounts,
        )..where((row) => row.id.equals(cardId))).getSingle();
        expect(cardAfterPayment.outstandingCreditMinorUnits, php10000);
        expect(await database.select(database.expenses).get(), hasLength(1));
        final TransactionRecord payment = await (database.select(
          database.transactions,
        )..where((row) => row.id.equals(purchaseId))).getSingle();
        expect(payment.transactionType, 'credit_card_purchase');
      },
    );

    test('multiple recurring payday schedules remain independent', () async {
      final String weeklyId = await dataSource.createPaydaySchedule(
        CreatePaydayScheduleInput(
          name: 'Clinic salary',
          paydayDate: DateTime(2026, 11, 6),
          expectedIncomeMinorUnits: php10000,
          frequency: 'weekly',
        ),
      );
      final String twiceMonthlyId = await dataSource.createPaydaySchedule(
        CreatePaydayScheduleInput(
          name: 'Tutoring',
          paydayDate: DateTime(2026, 11, 15),
          expectedIncomeMinorUnits: php100,
          frequency: 'twice_monthly',
        ),
      );

      final List<PaydayScheduleEntry> schedules = await dataSource
          .watchPaydaySchedules()
          .first;
      expect(schedules, hasLength(2));
      expect(
        schedules.map((PaydayScheduleEntry row) => row.id),
        containsAll(<String>[weeklyId, twiceMonthlyId]),
      );
      expect(
        schedules.singleWhere((row) => row.id == weeklyId).frequency,
        'weekly',
      );
      expect(
        schedules.singleWhere((row) => row.id == twiceMonthlyId).frequency,
        'twice_monthly',
      );
    });

    test(
      'allocation keys prevent duplicate bill assignments for a payday',
      () async {
        final String scheduleId = await dataSource.createPaydaySchedule(
          CreatePaydayScheduleInput(
            name: 'Salary',
            paydayDate: DateTime(2026, 11, 15),
            expectedIncomeMinorUnits: php10000,
            frequency: 'twice_monthly',
          ),
        );
        final String billId = await dataSource.createBill(
          CreateBillInput(
            name: 'Rent',
            amountMinorUnits: php1000,
            dueDate: DateTime(2026, 11, 1),
          ),
        );
        final CreateAllocationInput allocation = CreateAllocationInput(
          paydayScheduleId: scheduleId,
          allocatedAmountMinorUnits: php1000,
          allocationCategory: 'rent',
          allocationKey: 'rent-custom',
          relatedBillId: billId,
          relatedDueDate: DateTime(2026, 11, 1),
          periodDate: DateTime(2026, 11, 15),
        );
        final String firstId = await dataSource.createAllocation(allocation);
        final String duplicateId = await dataSource.createAllocation(
          allocation,
        );
        expect(duplicateId, firstId);
        expect(
          await database.select(database.financialAllocations).get(),
          hasLength(1),
        );
        final String otherSchedule = await dataSource.createPaydaySchedule(
          CreatePaydayScheduleInput(
            name: 'Second salary',
            paydayDate: DateTime(2026, 11, 30),
            expectedIncomeMinorUnits: php10000,
            frequency: 'monthly',
          ),
        );
        final String crossPaydayDuplicate = await dataSource.createAllocation(
          CreateAllocationInput(
            paydayScheduleId: otherSchedule,
            allocatedAmountMinorUnits: php1000,
            allocationCategory: 'rent',
            allocationKey: 'another-key',
            relatedBillId: billId,
            relatedDueDate: DateTime(2026, 11, 1),
            periodDate: DateTime(2026, 11, 30),
          ),
        );
        expect(crossPaydayDuplicate, firstId);

        final String paymentTransactionId = await dataSource.confirmBillPayment(
          BillPaymentInput(
            billId: billId,
            accountId: await account(name: 'Cash'),
            amountMinorUnits: php1000,
            occurrenceKey: '2026-11-01',
            paidAt: now,
            idempotencyKey: 'rent-allocation-payment',
          ),
        );
        FinancialAllocationRecord savedAllocation = await (database.select(
          database.financialAllocations,
        )..where((row) => row.id.equals(firstId))).getSingle();
        expect(savedAllocation.status, 'completed');
        expect(savedAllocation.fulfilledAmountMinorUnits, php1000);

        await dataSource.reverseTransaction(
          transactionId: paymentTransactionId,
          reversedAt: now,
          idempotencyKey: 'rent-allocation-reversal',
        );
        savedAllocation = await (database.select(
          database.financialAllocations,
        )..where((row) => row.id.equals(firstId))).getSingle();
        expect(savedAllocation.status, 'planned');
        expect(savedAllocation.fulfilledAmountMinorUnits, 0);
      },
    );

    test(
      'dashboard transaction streams bound date range and recent count',
      () async {
        final String accountId = await account(name: 'Dashboard cash');
        for (final (String key, DateTime date) in <(String, DateTime)>[
          ('old', DateTime.utc(2026, 9, 30)),
          ('current', DateTime.utc(2026, 10, 5)),
          ('latest', DateTime.utc(2026, 10, 6)),
        ]) {
          await database
              .into(database.transactions)
              .insert(
                TransactionsCompanion.insert(
                  id: key,
                  accountId: accountId,
                  transactionType: 'income',
                  direction: const Value<String>('inflow'),
                  title: Value<String>(key),
                  amountMinorUnits: 1000,
                  currencyCode: const Value<String>('PHP'),
                  occurredAt: date,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        final List<FinancialTransactionView> inRange = await dataSource
            .watchTransactionsInRange(
              startInclusive: DateTime.utc(2026, 10, 1),
              endExclusive: DateTime.utc(2026, 11, 1),
              currencyCode: 'PHP',
            )
            .first;
        final List<FinancialTransactionView> recent = await dataSource
            .watchRecentTransactions(limit: 1)
            .first;

        expect(inRange, hasLength(2));
        expect(inRange.map((row) => row.title), <String>['current', 'latest']);
        expect(recent, hasLength(1));
        expect(recent.single.title, 'latest');
      },
    );
  });
}
