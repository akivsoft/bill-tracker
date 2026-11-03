import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({required this.account, this.onTap, super.key});

  final FinancialAccount account;
  final VoidCallback? onTap;

  bool get _isCreditCard => account.accountType == 'credit_card';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final IconData icon = switch (account.iconKey) {
      'bank' => Icons.account_balance_outlined,
      'card' => Icons.credit_card_outlined,
      'cash' => Icons.payments_outlined,
      'phone' => Icons.phone_android_rounded,
      'savings' => Icons.savings_outlined,
      _ => switch (account.accountType) {
        'cash' => Icons.payments_outlined,
        'bank' || 'savings' => Icons.account_balance_outlined,
        'debit_card' => Icons.credit_card_outlined,
        'credit_card' => Icons.credit_score_outlined,
        'gcash' || 'maya' || 'e_wallet' => Icons.phone_android_rounded,
        _ => Icons.wallet_outlined,
      },
    };
    final String amount = Money(
      _isCreditCard
          ? account.outstandingCreditMinorUnits
          : account.currentBalanceMinorUnits,
      currencyCode: account.currencyCode,
    ).format();

    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: account.colorArgb == null
                  ? colors.secondaryContainer
                  : Color(account.colorArgb!).withValues(alpha: 0.16),
              foregroundColor: account.colorArgb == null
                  ? colors.onSecondaryContainer
                  : Color(account.colorArgb!),
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
                      if (account.provider?.isNotEmpty == true)
                        account.provider!,
                      _accountTypeLabel(account.accountType),
                      if (account.accountNumberSuffix?.isNotEmpty == true)
                        '•••• ${account.accountNumberSuffix}',
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
                  if (account.linkedAccountId != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      'Uses linked deposit balance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (!account.isActive ||
                      account.archivedAt != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xSmall),
                    Text(
                      account.archivedAt != null ? 'Archived' : 'Inactive',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: colors.error),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
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
    'custom' => account.customTypeName ?? 'Custom account',
    _ => 'Account',
  };
}
