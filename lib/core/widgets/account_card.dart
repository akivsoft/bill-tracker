import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({required this.account, super.key});

  final FinancialAccount account;

  bool get _isCreditCard => account.accountType == 'credit_card';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final IconData icon = switch (account.accountType) {
      'cash' => Icons.payments_outlined,
      'bank' || 'savings' => Icons.account_balance_outlined,
      'debit_card' => Icons.credit_card_outlined,
      'credit_card' => Icons.credit_score_outlined,
      'gcash' || 'maya' || 'e_wallet' => Icons.phone_android_rounded,
      _ => Icons.wallet_outlined,
    };
    final String amount = Money(
      _isCreditCard
          ? account.outstandingCreditMinorUnits
          : account.currentBalanceMinorUnits,
      currencyCode: account.currencyCode,
    ).format();

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xSmall),
                Text(
                  <String>[
                    if (account.provider?.isNotEmpty == true) account.provider!,
                    _accountTypeLabel(account.accountType),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  _isCreditCard ? 'Outstanding balance' : 'Current balance',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(amount, style: Theme.of(context).textTheme.titleLarge),
                if (_isCreditCard) ...<Widget>[
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    'Limit ${Money(account.creditLimitMinorUnits, currencyCode: account.currencyCode).format()} · Available ${Money(account.creditLimitMinorUnits - account.outstandingCreditMinorUnits, currencyCode: account.currencyCode).format()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _accountTypeLabel(String type) => switch (type) {
    'debit_card' => 'Debit card',
    'credit_card' => 'Credit card',
    'e_wallet' => 'E-wallet',
    'gcash' => 'GCash',
    'maya' => 'Maya',
    'savings' => 'Savings',
    'bank' => 'Bank',
    'cash' => 'Cash',
    'custom' => 'Custom account',
    _ => 'Account',
  };
}
