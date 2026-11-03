import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:flutter/material.dart';

class AccountEntrySheet extends StatefulWidget {
  const AccountEntrySheet({required this.currencyCode, super.key});

  final String currencyCode;

  @override
  State<AccountEntrySheet> createState() => _AccountEntrySheetState();
}

class _AccountEntrySheetState extends State<AccountEntrySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  final TextEditingController _outstandingController = TextEditingController(
    text: '0',
  );
  String _type = 'cash';

  static const List<(String, String)> _types = <(String, String)>[
    ('cash', 'Cash'),
    ('bank', 'Bank account'),
    ('savings', 'Savings account'),
    ('debit_card', 'Debit card'),
    ('credit_card', 'Credit card'),
    ('gcash', 'GCash'),
    ('maya', 'Maya'),
    ('e_wallet', 'Other e-wallet'),
    ('custom', 'Custom account'),
  ];

  bool get _creditCard => _type == 'credit_card';

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    _outstandingController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final int balance = _parseOrZero(_balanceController.text);
    final int limit = _parseOrZero(_limitController.text);
    final int outstanding = _parseOrZero(_outstandingController.text);
    if (_creditCard && outstanding > limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outstanding balance cannot exceed the credit limit.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      CreateAccountInput(
        name: _nameController.text.trim(),
        provider: _providerController.text.trim(),
        accountType: _type,
        openingBalanceMinorUnits: _creditCard ? 0 : balance,
        creditLimitMinorUnits: _creditCard ? limit : 0,
        outstandingCreditMinorUnits: _creditCard ? outstanding : 0,
        currencyCode: widget.currencyCode,
      ),
    );
  }

  int _parseOrZero(String value) =>
      parseMinorUnits(value.trim().isEmpty ? '0' : value) ?? 0;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.medium,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Add an account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) =>
                    value == null || value.trim().isEmpty
                    ? 'Enter an account name.'
                    : null,
                decoration: const InputDecoration(labelText: 'Account name'),
              ),
              const SizedBox(height: AppSpacing.medium),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Account type'),
                items: _types
                    .map(
                      ((String, String) type) => DropdownMenuItem<String>(
                        value: type.$1,
                        child: Text(type.$2),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) =>
                    setState(() => _type = value ?? 'cash'),
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _providerController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Provider (optional)',
                  hintText: 'e.g. BPI, GCash',
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              if (_creditCard) ...<Widget>[
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (String? value) {
                    final int? amount = value == null
                        ? null
                        : parseMinorUnits(value);
                    return amount == null || amount <= 0
                        ? 'Enter a credit limit.'
                        : null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Credit limit',
                    prefixText: '${widget.currencyCode} ',
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _outstandingController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final int? amount = parseMinorUnits(value);
                    return amount == null || amount < 0
                        ? 'Enter a non-negative amount.'
                        : null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Outstanding balance',
                    prefixText: '${widget.currencyCode} ',
                  ),
                ),
              ] else
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final int? amount = parseMinorUnits(value);
                    return amount == null || amount < 0
                        ? 'Enter a balance of 0 or more with up to two decimals.'
                        : null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Current balance',
                    prefixText: '${widget.currencyCode} ',
                    helperText: 'Leave blank to start at 0.',
                  ),
                ),
              const SizedBox(height: AppSpacing.large),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Save account'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
