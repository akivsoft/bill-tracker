import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:drift/native.dart';
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
  });
}
