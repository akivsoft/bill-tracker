import 'dart:collection';

import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';

enum WalletAccountGroup { all, cash, banks, eWallets, creditCards, other }

enum WalletSortOrder { name, balanceHighToLow, balanceLowToHigh }

enum BalanceHistoryRange { daily, weekly, monthly, custom }

final class AccountLedgerSummary {
  const AccountLedgerSummary({
    this.moneyReceivedMinorUnits = 0,
    this.moneySpentMinorUnits = 0,
    this.transfersReceivedMinorUnits = 0,
    this.transfersSentMinorUnits = 0,
    this.creditCardPaymentsMinorUnits = 0,
    this.adjustmentsMinorUnits = 0,
  });

  final int moneyReceivedMinorUnits;
  final int moneySpentMinorUnits;
  final int transfersReceivedMinorUnits;
  final int transfersSentMinorUnits;
  final int creditCardPaymentsMinorUnits;
  final int adjustmentsMinorUnits;
}

final class BalanceHistoryPoint {
  const BalanceHistoryPoint({
    required this.date,
    required this.balanceMinorUnits,
  });

  final DateTime date;
  final int balanceMinorUnits;
}

/// Wallet calculations use stored integer minor units for all money values.
final class WalletCalculator {
  const WalletCalculator._();

  static bool isCreditCard(FinancialAccount account) =>
      account.accountType == 'credit_card';

  static int accountBalance(FinancialAccount account) => isCreditCard(account)
      ? account.outstandingCreditMinorUnits
      : account.currentBalanceMinorUnits;

  static int availableCredit(FinancialAccount account) =>
      account.creditLimitMinorUnits - account.outstandingCreditMinorUnits;

  static int creditUtilizationBasisPoints(FinancialAccount account) =>
      account.creditLimitMinorUnits == 0
      ? 0
      : account.outstandingCreditMinorUnits *
            10000 ~/
            account.creditLimitMinorUnits;

  static AccountLedgerSummary summarize(
    FinancialAccount account,
    Iterable<FinancialTransactionView> transactions,
  ) {
    final Map<String, FinancialTransactionView> byId =
        <String, FinancialTransactionView>{
          for (final FinancialTransactionView transaction in transactions)
            transaction.id: transaction,
        };
    int received = 0;
    int spent = 0;
    int transfersIn = 0;
    int transfersOut = 0;
    int cardPayments = 0;
    int adjustments = 0;
    for (final FinancialTransactionView transaction in transactions) {
      final _Activity activity = _activity(account, transaction, byId);
      received += activity.received;
      spent += activity.spent;
      transfersIn += activity.transfersIn;
      transfersOut += activity.transfersOut;
      cardPayments += activity.cardPayments;
      adjustments += activity.adjustments;
    }
    return AccountLedgerSummary(
      moneyReceivedMinorUnits: received,
      moneySpentMinorUnits: spent,
      transfersReceivedMinorUnits: transfersIn,
      transfersSentMinorUnits: transfersOut,
      creditCardPaymentsMinorUnits: cardPayments,
      adjustmentsMinorUnits: adjustments,
    );
  }

  /// Produces points only where recorded transactions changed the balance.
  /// Empty days and periods are omitted rather than filled with estimates.
  static List<BalanceHistoryPoint> balanceHistory(
    FinancialAccount account,
    Iterable<FinancialTransactionView> transactions, {
    required BalanceHistoryRange range,
    required DateTime now,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final List<FinancialTransactionView> ordered = transactions.toList()
      ..sort((FinancialTransactionView a, FinancialTransactionView b) {
        final int byDate = a.occurredAt.compareTo(b.occurredAt);
        return byDate == 0 ? a.id.compareTo(b.id) : byDate;
      });
    if (ordered.isEmpty) return const <BalanceHistoryPoint>[];

    final DateTime start = switch (range) {
      BalanceHistoryRange.daily => now.subtract(const Duration(days: 30)),
      BalanceHistoryRange.weekly => now.subtract(const Duration(days: 84)),
      BalanceHistoryRange.monthly => DateTime(now.year, now.month - 12),
      BalanceHistoryRange.custom =>
        customStart ?? DateTime(now.year, now.month),
    };
    final DateTime end = switch (range) {
      BalanceHistoryRange.custom => customEnd ?? now,
      _ => now,
    };
    if (end.isBefore(start)) return const <BalanceHistoryPoint>[];

    final Map<String, FinancialTransactionView> byId =
        <String, FinancialTransactionView>{
          for (final FinancialTransactionView transaction in ordered)
            transaction.id: transaction,
        };
    int balance = isCreditCard(account)
        ? account.openingOutstandingCreditMinorUnits
        : account.openingBalanceMinorUnits;
    final LinkedHashMap<DateTime, int> points = LinkedHashMap<DateTime, int>();
    for (final FinancialTransactionView transaction in ordered) {
      balance += _balanceDelta(account, transaction, byId);
      final DateTime date = transaction.occurredAt;
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final DateTime bucket = switch (range) {
        BalanceHistoryRange.daily ||
        BalanceHistoryRange.custom => DateTime(date.year, date.month, date.day),
        BalanceHistoryRange.weekly => _weekStart(date),
        BalanceHistoryRange.monthly => DateTime(date.year, date.month),
      };
      points[bucket] = balance;
    }
    return points.entries
        .map(
          (MapEntry<DateTime, int> entry) => BalanceHistoryPoint(
            date: entry.key,
            balanceMinorUnits: entry.value,
          ),
        )
        .toList(growable: false);
  }

  static _Activity _activity(
    FinancialAccount account,
    FinancialTransactionView transaction,
    Map<String, FinancialTransactionView> byId,
  ) {
    if (transaction.type == 'reversal' && transaction.reversalOfId != null) {
      return _activity(
        account,
        byId[transaction.reversalOfId] ?? transaction,
        byId,
      ).negated();
    }
    final int amount = transaction.amountMinorUnits;
    switch (transaction.type) {
      case 'income':
        return transaction.destinationAccountId == account.id
            ? _Activity(received: amount)
            : const _Activity();
      case 'expense':
      case 'bill_payment':
      case 'loan_payment':
      case 'savings_contribution':
        return transaction.sourceAccountId == account.id
            ? _Activity(spent: amount)
            : const _Activity();
      case 'credit_card_purchase':
        return transaction.sourceAccountId == account.id
            ? _Activity(spent: amount)
            : const _Activity();
      case 'account_transfer':
        return _Activity(
          transfersIn: transaction.destinationAccountId == account.id
              ? amount
              : 0,
          transfersOut: transaction.sourceAccountId == account.id ? amount : 0,
        );
      case 'credit_card_payment':
        if (transaction.destinationAccountId == account.id) {
          return _Activity(cardPayments: amount);
        }
        return transaction.sourceAccountId == account.id
            ? _Activity(transfersOut: amount)
            : const _Activity();
      case 'balance_adjustment':
        return _Activity(
          adjustments: _balanceDelta(account, transaction, byId),
        );
      default:
        return const _Activity();
    }
  }

  static int _balanceDelta(
    FinancialAccount account,
    FinancialTransactionView transaction,
    Map<String, FinancialTransactionView> byId,
  ) {
    if (transaction.type == 'reversal' && transaction.reversalOfId != null) {
      final FinancialTransactionView? original = byId[transaction.reversalOfId];
      return original == null ? 0 : -_balanceDelta(account, original, byId);
    }
    final int amount = transaction.amountMinorUnits;
    switch (transaction.type) {
      case 'income':
        return transaction.destinationAccountId == account.id ? amount : 0;
      case 'expense':
      case 'bill_payment':
      case 'loan_payment':
      case 'savings_contribution':
        return transaction.sourceAccountId == account.id ? -amount : 0;
      case 'account_transfer':
        if (transaction.sourceAccountId == account.id) return -amount;
        if (transaction.destinationAccountId == account.id) return amount;
        return 0;
      case 'credit_card_purchase':
        return transaction.sourceAccountId == account.id ? amount : 0;
      case 'credit_card_payment':
        if (transaction.destinationAccountId == account.id) return -amount;
        return transaction.sourceAccountId == account.id ? -amount : 0;
      case 'balance_adjustment':
        if (transaction.sourceAccountId == account.id) return -amount;
        if (transaction.destinationAccountId == account.id) return amount;
        return 0;
      default:
        return 0;
    }
  }

  static DateTime _weekStart(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}

final class _Activity {
  const _Activity({
    this.received = 0,
    this.spent = 0,
    this.transfersIn = 0,
    this.transfersOut = 0,
    this.cardPayments = 0,
    this.adjustments = 0,
  });

  final int received;
  final int spent;
  final int transfersIn;
  final int transfersOut;
  final int cardPayments;
  final int adjustments;

  _Activity negated() => _Activity(
    received: -received,
    spent: -spent,
    transfersIn: -transfersIn,
    transfersOut: -transfersOut,
    cardPayments: -cardPayments,
    adjustments: -adjustments,
  );
}
