import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountEntrySheet extends StatefulWidget {
  const AccountEntrySheet({
    required this.currencyCode,
    this.availableAccounts = const <FinancialAccount>[],
    super.key,
  });

  final String currencyCode;
  final List<FinancialAccount> availableAccounts;

  @override
  State<AccountEntrySheet> createState() => _AccountEntrySheetState();
}

class _AccountEntrySheetState extends State<AccountEntrySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController(
    text: '0',
  );
  final TextEditingController _limitController = TextEditingController();
  final TextEditingController _outstandingController = TextEditingController(
    text: '0',
  );
  final TextEditingController _statementBalanceController =
      TextEditingController(text: '0');
  final TextEditingController _minimumPaymentController = TextEditingController(
    text: '0',
  );
  final TextEditingController _suffixController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _type = 'cash';
  String _currencyCode = 'PHP';
  String _iconKey = 'wallet';
  String? _linkedAccountId;
  int? _colorArgb;
  DateTime? _statementDate;
  DateTime? _paymentDueDate;
  bool _allowNegativeBalance = false;

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
    ('other', 'Other deposit account'),
  ];

  static const List<String> _currencies = <String>[
    'PHP',
    'USD',
    'SGD',
    'EUR',
    'GBP',
  ];

  static const Map<String, IconData> _icons = <String, IconData>{
    'wallet': Icons.account_balance_wallet_outlined,
    'bank': Icons.account_balance_outlined,
    'card': Icons.credit_card_outlined,
    'cash': Icons.payments_outlined,
    'phone': Icons.phone_android_rounded,
    'savings': Icons.savings_outlined,
  };

  static const List<int> _colors = <int>[
    0xFF1D6B62,
    0xFF365B9D,
    0xFF9A5B16,
    0xFF7B4A8D,
    0xFFB4474D,
  ];

  bool get _creditCard => _type == 'credit_card';
  bool get _linkedDebit => _type == 'debit_card' && _linkedAccountId != null;
  bool get _negativeBalanceEligible =>
      <String>{'bank', 'custom', 'other'}.contains(_type);

  List<FinancialAccount> get _linkableAccounts => widget.availableAccounts
      .where(
        (FinancialAccount account) =>
            account.isActive &&
            account.archivedAt == null &&
            account.accountType != 'credit_card' &&
            account.accountType != 'debit_card' &&
            account.linkedAccountId == null &&
            account.currencyCode == _currencyCode,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _currencyCode = _currencies.contains(widget.currencyCode)
        ? widget.currencyCode
        : 'PHP';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    _outstandingController.dispose();
    _statementBalanceController.dispose();
    _minimumPaymentController.dispose();
    _suffixController.dispose();
    _customTypeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool statement}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          (statement ? _statementDate : _paymentDueDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (statement) {
        _statementDate = picked;
      } else {
        _paymentDueDate = picked;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final int openingBalance = _linkedDebit || _creditCard
        ? 0
        : parseMinorUnits(_balanceController.text) ?? 0;
    final int limit = _creditCard
        ? parseMinorUnits(_limitController.text) ?? 0
        : 0;
    final int outstanding = _creditCard
        ? parseMinorUnits(_outstandingController.text) ?? 0
        : 0;
    if (_creditCard && outstanding > limit) {
      _showError('Outstanding balance cannot exceed the credit limit.');
      return;
    }
    Navigator.of(context).pop(
      CreateAccountInput(
        name: _nameController.text.trim(),
        provider: _providerController.text,
        accountType: _type,
        openingBalanceMinorUnits: openingBalance,
        currencyCode: _currencyCode,
        creditLimitMinorUnits: limit,
        outstandingCreditMinorUnits: outstanding,
        openingOutstandingCreditMinorUnits: outstanding,
        statementBalanceMinorUnits: _creditCard
            ? parseMinorUnits(_statementBalanceController.text) ?? 0
            : 0,
        minimumPaymentMinorUnits: _creditCard
            ? parseMinorUnits(_minimumPaymentController.text) ?? 0
            : 0,
        statementDate: _creditCard ? _statementDate : null,
        paymentDueDate: _creditCard ? _paymentDueDate : null,
        accountNumberSuffix: _suffixController.text,
        linkedAccountId: _linkedDebit ? _linkedAccountId : null,
        customTypeName: _type == 'custom' ? _customTypeController.text : null,
        iconKey: _iconKey,
        colorArgb: _colorArgb,
        notes: _notesController.text,
        allowNegativeBalance: _allowNegativeBalance,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.94,
    child: SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.medium,
                AppSpacing.medium,
                AppSpacing.small,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Add an account',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  0,
                  AppSpacing.medium,
                  AppSpacing.large,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      validator: (String? value) =>
                          validateRequired(value, label: 'Account name'),
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                        prefixIcon: Icon(Icons.wallet_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Account type',
                      ),
                      items: _types
                          .map(
                            ((String, String) type) => DropdownMenuItem<String>(
                              value: type.$1,
                              child: Text(type.$2),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) => setState(() {
                        _type = value ?? 'cash';
                        if (_type != 'debit_card') _linkedAccountId = null;
                        if (!_negativeBalanceEligible) {
                          _allowNegativeBalance = false;
                        }
                      }),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    TextFormField(
                      controller: _providerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Bank or provider (optional)',
                        hintText: 'e.g. BPI, GCash, Maya',
                      ),
                    ),
                    if (_type == 'custom') ...<Widget>[
                      const SizedBox(height: AppSpacing.medium),
                      TextFormField(
                        controller: _customTypeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Custom account type',
                          hintText: 'e.g. Cooperative, gift card',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.medium),
                    DropdownButtonFormField<String>(
                      initialValue: _currencyCode,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: _currencies
                          .map(
                            (String currency) => DropdownMenuItem<String>(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (String? value) => setState(() {
                        _currencyCode = value ?? 'PHP';
                        if (!_linkableAccounts.any(
                          (FinancialAccount account) =>
                              account.id == _linkedAccountId,
                        )) {
                          _linkedAccountId = null;
                        }
                      }),
                    ),
                    if (_creditCard) ...<Widget>[
                      const SizedBox(height: AppSpacing.medium),
                      _moneyField(
                        controller: _limitController,
                        label: 'Credit limit',
                        requiredValue: true,
                        positive: true,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _moneyField(
                        controller: _outstandingController,
                        label: 'Current outstanding balance',
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _moneyField(
                        controller: _statementBalanceController,
                        label: 'Statement balance',
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _moneyField(
                        controller: _minimumPaymentController,
                        label: 'Minimum payment',
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _dateButton(
                        label: 'Statement date',
                        date: _statementDate,
                        onPressed: () => _pickDate(statement: true),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      _dateButton(
                        label: 'Payment due date',
                        date: _paymentDueDate,
                        onPressed: () => _pickDate(statement: false),
                      ),
                    ] else ...<Widget>[
                      if (_type == 'debit_card') ...<Widget>[
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
                            ..._linkableAccounts.map(
                              (
                                FinancialAccount account,
                              ) => DropdownMenuItem<String?>(
                                value: account.id,
                                child: Text(
                                  '${account.name} · ${account.currencyCode}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (String? value) =>
                              setState(() => _linkedAccountId = value),
                        ),
                        if (_linkedAccountId != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.small,
                            ),
                            child: Text(
                              'This card uses the linked account balance and will not add a second asset.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                      if (!_linkedDebit) ...<Widget>[
                        const SizedBox(height: AppSpacing.medium),
                        _moneyField(
                          controller: _balanceController,
                          label: 'Initial balance',
                          signed: _allowNegativeBalance,
                        ),
                      ],
                      if (_type == 'savings' ||
                          _type == 'debit_card') ...<Widget>[
                        const SizedBox(height: AppSpacing.medium),
                        TextFormField(
                          controller: _suffixController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (String? value) {
                            if (value == null || value.isEmpty) return null;
                            return RegExp(r'^\d{4}$').hasMatch(value)
                                ? null
                                : 'Enter only the last four digits.';
                          },
                          decoration: const InputDecoration(
                            labelText: 'Last four digits (optional)',
                            helperText:
                                'Do not enter a full account or card number.',
                          ),
                        ),
                      ],
                    ],
                    if (_negativeBalanceEligible) ...<Widget>[
                      const SizedBox(height: AppSpacing.small),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _allowNegativeBalance,
                        title: const Text('Allow an overdraft balance'),
                        subtitle: const Text(
                          'Outflows can exceed this account’s current balance.',
                        ),
                        onChanged: (bool value) => setState(() {
                          _allowNegativeBalance = value;
                        }),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      'Account icon',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: AppSpacing.small,
                      children: _icons.entries
                          .map(
                            (MapEntry<String, IconData> entry) => ChoiceChip(
                              tooltip: entry.key,
                              selected: _iconKey == entry.key,
                              avatar: Icon(entry.value, size: 18),
                              label: Text(entry.key),
                              onSelected: (_) =>
                                  setState(() => _iconKey = entry.key),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      'Account color',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: AppSpacing.small,
                      children: _colors
                          .map(
                            (int color) => ChoiceChip(
                              label: Text(' '),
                              selected: _colorArgb == color,
                              avatar: CircleAvatar(
                                backgroundColor: Color(color),
                              ),
                              onSelected: (_) =>
                                  setState(() => _colorArgb = color),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.small,
                AppSpacing.medium,
                AppSpacing.medium,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Save account'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    bool requiredValue = false,
    bool positive = false,
    bool signed = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    validator: (String? value) {
      if ((value == null || value.trim().isEmpty) && !requiredValue) {
        return null;
      }
      final int? amount = value == null ? null : parseMinorUnits(value);
      if (amount == null) return 'Enter a valid amount with up to 2 decimals.';
      if (positive && amount <= 0) return 'Enter an amount greater than zero.';
      if (!signed && amount < 0) return 'Enter a balance of 0 or more.';
      return null;
    },
    decoration: InputDecoration(
      labelText: label,
      prefixText: '$_currencyCode ',
      helperText: label == 'Initial balance' && !signed
          ? 'Leave at 0 if you are starting this account now.'
          : null,
    ),
  );

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.calendar_month_outlined),
    label: Text(
      date == null ? label : '$label · ${date.month}/${date.day}/${date.year}',
    ),
  );
}
