import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountEditSheet extends StatefulWidget {
  const AccountEditSheet({
    required this.account,
    required this.availableAccounts,
    super.key,
  });

  final FinancialAccount account;
  final List<FinancialAccount> availableAccounts;

  @override
  State<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<AccountEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.account.name,
  );
  late final TextEditingController _provider = TextEditingController(
    text: widget.account.provider ?? '',
  );
  late final TextEditingController _suffix = TextEditingController(
    text: widget.account.accountNumberSuffix ?? '',
  );
  late final TextEditingController _customType = TextEditingController(
    text: widget.account.customTypeName ?? '',
  );
  late final TextEditingController _statement = TextEditingController(
    text: _decimal(widget.account.statementBalanceMinorUnits),
  );
  late final TextEditingController _minimum = TextEditingController(
    text: _decimal(widget.account.minimumPaymentMinorUnits),
  );
  late final TextEditingController _limit = TextEditingController(
    text: _decimal(widget.account.creditLimitMinorUnits),
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.account.notes ?? '',
  );
  late String? _linkedAccountId = widget.account.linkedAccountId;
  late String? _iconKey = widget.account.iconKey;
  late int? _colorArgb = widget.account.colorArgb;
  late DateTime? _statementDate = widget.account.statementDate;
  late DateTime? _paymentDueDate = widget.account.paymentDueDate;
  late bool _allowNegative = widget.account.allowNegativeBalance;

  bool get _creditCard => widget.account.accountType == 'credit_card';
  bool get _debitCard => widget.account.accountType == 'debit_card';
  bool get _negativeEligible =>
      <String>{'bank', 'custom', 'other'}.contains(widget.account.accountType);

  List<FinancialAccount> get _linkable => widget.availableAccounts
      .where(
        (FinancialAccount account) =>
            account.id != widget.account.id &&
            account.isActive &&
            account.archivedAt == null &&
            account.accountType != 'credit_card' &&
            account.accountType != 'debit_card' &&
            account.linkedAccountId == null &&
            account.currencyCode == widget.account.currencyCode,
      )
      .toList(growable: false);

  @override
  void dispose() {
    _name.dispose();
    _provider.dispose();
    _suffix.dispose();
    _customType.dispose();
    _statement.dispose();
    _minimum.dispose();
    _limit.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _decimal(int amount) =>
      '${amount ~/ 100}.${(amount.abs() % 100).toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool statement}) async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate:
          (statement ? _statementDate : _paymentDueDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (statement) {
        _statementDate = selected;
      } else {
        _paymentDueDate = selected;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final int statementBalance = parseMinorUnits(_statement.text) ?? 0;
    final int minimumPayment = parseMinorUnits(_minimum.text) ?? 0;
    final int creditLimit = parseMinorUnits(_limit.text) ?? 0;
    if (_creditCard &&
        creditLimit < widget.account.outstandingCreditMinorUnits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Credit limit cannot be lower than the current outstanding balance.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      UpdateAccountInput(
        accountId: widget.account.id,
        name: _name.text.trim(),
        provider: _provider.text,
        accountNumberSuffix: _suffix.text,
        linkedAccountId: _debitCard ? _linkedAccountId : null,
        customTypeName: _customType.text,
        iconKey: _iconKey,
        colorArgb: _colorArgb,
        statementBalanceMinorUnits: _creditCard ? statementBalance : 0,
        minimumPaymentMinorUnits: _creditCard ? minimumPayment : 0,
        statementDate: _creditCard ? _statementDate : null,
        paymentDueDate: _creditCard ? _paymentDueDate : null,
        notes: _notes.text,
        allowNegativeBalance: _allowNegative,
        creditLimitMinorUnits: _creditCard ? creditLimit : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.92,
    child: SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Edit account',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                ),
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: (String? value) =>
                        validateRequired(value, label: 'Account name'),
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  TextFormField(
                    controller: _provider,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Bank or provider (optional)',
                    ),
                  ),
                  if (widget.account.accountType == 'savings' ||
                      _debitCard) ...<Widget>[
                    const SizedBox(height: AppSpacing.medium),
                    TextFormField(
                      controller: _suffix,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (String? value) =>
                          value == null ||
                              value.isEmpty ||
                              RegExp(r'^\d{4}$').hasMatch(value)
                          ? null
                          : 'Enter only the last four digits.',
                      decoration: const InputDecoration(
                        labelText: 'Last four digits (optional)',
                      ),
                    ),
                  ],
                  if (_debitCard) ...<Widget>[
                    const SizedBox(height: AppSpacing.medium),
                    DropdownButtonFormField<String?>(
                      initialValue: _linkedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Linked deposit account',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Independent account balance'),
                        ),
                        ..._linkable.map(
                          (FinancialAccount account) =>
                              DropdownMenuItem<String?>(
                                value: account.id,
                                child: Text(account.name),
                              ),
                        ),
                      ],
                      onChanged: (String? value) =>
                          setState(() => _linkedAccountId = value),
                    ),
                  ],
                  if (widget.account.accountType == 'custom') ...<Widget>[
                    const SizedBox(height: AppSpacing.medium),
                    TextFormField(
                      controller: _customType,
                      decoration: const InputDecoration(
                        labelText: 'Custom account type',
                      ),
                    ),
                  ],
                  if (_creditCard) ...<Widget>[
                    const SizedBox(height: AppSpacing.medium),
                    _moneyField(_limit, 'Credit limit', requiredPositive: true),
                    const SizedBox(height: AppSpacing.medium),
                    _moneyField(_statement, 'Statement balance'),
                    const SizedBox(height: AppSpacing.medium),
                    _moneyField(_minimum, 'Minimum payment'),
                    const SizedBox(height: AppSpacing.medium),
                    _dateButton(
                      'Statement date',
                      _statementDate,
                      () => _pickDate(statement: true),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    _dateButton(
                      'Payment due date',
                      _paymentDueDate,
                      () => _pickDate(statement: false),
                    ),
                  ],
                  if (_negativeEligible) ...<Widget>[
                    const SizedBox(height: AppSpacing.small),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _allowNegative,
                      title: const Text('Allow an overdraft balance'),
                      onChanged: (bool value) =>
                          setState(() => _allowNegative = value),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.medium),
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'Account color',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Wrap(
                    spacing: AppSpacing.small,
                    children:
                        <int>[
                              0xFF1D6B62,
                              0xFF365B9D,
                              0xFF9A5B16,
                              0xFF7B4A8D,
                              0xFFB4474D,
                            ]
                            .map(
                              (int color) => ChoiceChip(
                                label: const Text(' '),
                                avatar: CircleAvatar(
                                  backgroundColor: Color(color),
                                ),
                                selected: _colorArgb == color,
                                onSelected: (_) =>
                                    setState(() => _colorArgb = color),
                              ),
                            )
                            .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    'Account icon',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Wrap(
                    spacing: AppSpacing.small,
                    children:
                        <(String, IconData)>[
                              ('wallet', Icons.account_balance_wallet_outlined),
                              ('bank', Icons.account_balance_outlined),
                              ('card', Icons.credit_card_outlined),
                              ('cash', Icons.payments_outlined),
                              ('phone', Icons.phone_android_rounded),
                              ('savings', Icons.savings_outlined),
                            ]
                            .map(
                              ((String, IconData) item) => ChoiceChip(
                                avatar: Icon(item.$2, size: 18),
                                label: Text(item.$1),
                                selected: _iconKey == item.$1,
                                onSelected: (_) =>
                                    setState(() => _iconKey = item.$1),
                              ),
                            )
                            .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'Currency: ${widget.account.currencyCode} · cannot be changed after transactions are recorded.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _moneyField(
    TextEditingController controller,
    String label, {
    bool requiredPositive = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: (String? value) {
      final int? amount = value == null ? null : parseMinorUnits(value);
      if (amount == null || amount < 0) {
        return 'Enter an amount of 0 or more with up to two decimals.';
      }
      if (requiredPositive && amount <= 0) return 'Enter a positive limit.';
      return null;
    },
    decoration: InputDecoration(
      labelText: label,
      prefixText: '${widget.account.currencyCode} ',
    ),
  );

  Widget _dateButton(String label, DateTime? date, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          date == null
              ? label
              : '$label · ${date.month}/${date.day}/${date.year}',
        ),
      );
}
