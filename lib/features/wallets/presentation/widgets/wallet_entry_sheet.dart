import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum WalletAction { addMoney, expense, transfer, adjustBalance, cardPayment }

class WalletEntrySheet extends ConsumerStatefulWidget {
  const WalletEntrySheet({
    required this.action,
    required this.accounts,
    required this.currencyCode,
    this.preselectedAccountId,
    super.key,
  });

  final WalletAction action;
  final List<FinancialAccount> accounts;
  final String currencyCode;
  final String? preselectedAccountId;

  @override
  ConsumerState<WalletEntrySheet> createState() => _WalletEntrySheetState();
}

class _WalletEntrySheetState extends ConsumerState<WalletEntrySheet> {
  static const Uuid _uuid = Uuid();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _feeController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  late String? _accountId;
  late String? _fromAccountId;
  late String? _toAccountId;
  late String? _cardAccountId;
  late String? _paymentAccountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  List<FinancialAccount> get _activeAccounts => widget.accounts
      .where(
        (FinancialAccount account) =>
            account.isActive &&
            account.archivedAt == null &&
            account.currencyCode == widget.currencyCode,
      )
      .toList(growable: false);

  List<FinancialAccount> get _balanceAccounts => _activeAccounts
      .where(
        (FinancialAccount account) =>
            account.accountType != 'credit_card' &&
            !(account.accountType == 'debit_card' &&
                account.linkedAccountId != null),
      )
      .toList(growable: false);

  List<FinancialAccount> get _creditCards => _activeAccounts
      .where((FinancialAccount account) => account.accountType == 'credit_card')
      .toList(growable: false);

  List<FinancialAccount> get _paymentAccounts => <FinancialAccount>[
    ..._balanceAccounts,
    ..._creditCards,
  ];

  String get _title => switch (widget.action) {
    WalletAction.addMoney => 'Add money',
    WalletAction.expense => 'Record expense',
    WalletAction.transfer => 'Transfer money',
    WalletAction.adjustBalance => 'Adjust balance',
    WalletAction.cardPayment => 'Credit card payment',
  };

  @override
  void initState() {
    super.initState();
    final String? firstBalance = _firstOrNull(_balanceAccounts)?.id;
    final List<FinancialAccount> singleAccountOptions =
        widget.action == WalletAction.expense ||
            widget.action == WalletAction.adjustBalance
        ? _paymentAccounts
        : _balanceAccounts;
    _accountId =
        _validId(singleAccountOptions, widget.preselectedAccountId) ??
        _validId(singleAccountOptions, firstBalance) ??
        _firstOrNull(singleAccountOptions)?.id;
    _fromAccountId = _accountId;
    _toAccountId = _balanceAccounts
        .where((FinancialAccount account) => account.id != _fromAccountId)
        .firstOrNull
        ?.id;
    _cardAccountId =
        _validId(_creditCards, widget.preselectedAccountId) ??
        _firstOrNull(_creditCards)?.id;
    _paymentAccountId = _accountId;
  }

  String? _validId(List<FinancialAccount> accounts, String? id) =>
      accounts.any((FinancialAccount account) => account.id == id) ? id : null;

  FinancialAccount? _firstOrNull(List<FinancialAccount> accounts) =>
      accounts.isEmpty ? null : accounts.first;

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final bool hasRequiredAccounts = switch (widget.action) {
      WalletAction.addMoney => _accountId != null,
      WalletAction.expense => _accountId != null,
      WalletAction.transfer =>
        _fromAccountId != null &&
            _toAccountId != null &&
            _fromAccountId != _toAccountId,
      WalletAction.adjustBalance => _accountId != null,
      WalletAction.cardPayment =>
        _paymentAccountId != null && _cardAccountId != null,
    };
    if (!hasRequiredAccounts) {
      _showError('Add or choose the required accounts first.');
      return;
    }
    final int amount = parseMinorUnits(_amountController.text) ?? 0;
    final int fee = parseMinorUnits(_feeController.text) ?? 0;
    final String confirmation = switch (widget.action) {
      WalletAction.addMoney =>
        'Add ${Money(amount, currencyCode: widget.currencyCode).format()} to ${_accountName(_accountId)}?',
      WalletAction.expense =>
        'Record ${Money(amount, currencyCode: widget.currencyCode).format()} spent from ${_accountName(_accountId)}?',
      WalletAction.transfer =>
        'Transfer ${Money(amount, currencyCode: widget.currencyCode).format()} from ${_accountName(_fromAccountId)} to ${_accountName(_toAccountId)}?',
      WalletAction.adjustBalance =>
        'Set ${_accountName(_accountId)} to ${Money(amount, currencyCode: widget.currencyCode).format()} and record the difference?',
      WalletAction.cardPayment =>
        'Pay ${Money(amount, currencyCode: widget.currencyCode).format()} from ${_accountName(_paymentAccountId)} to ${_accountName(_cardAccountId)}?',
    };
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(_title),
        content: Text(confirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final FinancialRepository repository = ref.read(
        financialRepositoryProvider,
      );
      switch (widget.action) {
        case WalletAction.addMoney:
          await repository.recordIncome(
            RecordIncomeInput(
              source: _sourceController.text.trim(),
              accountId: _accountId!,
              amountMinorUnits: amount,
              occurredAt: _date,
              idempotencyKey: _uuid.v4(),
              category: _optionalText(_categoryController.text),
              notes: _optionalText(_notesController.text),
            ),
          );
        case WalletAction.expense:
          await repository.recordExpense(
            RecordExpenseInput(
              title: _titleController.text.trim(),
              accountId: _accountId!,
              amountMinorUnits: amount,
              occurredAt: _date,
              idempotencyKey: _uuid.v4(),
              category: _optionalText(_categoryController.text),
              notes: _optionalText(_notesController.text),
            ),
          );
        case WalletAction.transfer:
          await repository.transfer(
            TransferInput(
              fromAccountId: _fromAccountId!,
              toAccountId: _toAccountId!,
              amountMinorUnits: amount,
              feeMinorUnits: fee,
              transferredAt: _date,
              idempotencyKey: _uuid.v4(),
              notes: _optionalText(_notesController.text),
            ),
          );
        case WalletAction.adjustBalance:
          await repository.reconcileAccount(
            ReconcileAccountInput(
              accountId: _accountId!,
              actualBalanceMinorUnits: amount,
              reconciledAt: _date,
              idempotencyKey: _uuid.v4(),
              notes: _optionalText(_notesController.text),
            ),
          );
        case WalletAction.cardPayment:
          await repository.recordCreditCardPayment(
            CreditPaymentInput(
              cashAccountId: _paymentAccountId!,
              creditAccountId: _cardAccountId!,
              amountMinorUnits: amount,
              paidAt: _date,
              idempotencyKey: _uuid.v4(),
              notes: _optionalText(_notesController.text),
            ),
          );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete this action: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _accountName(String? id) =>
      widget.accounts
          .where((FinancialAccount account) => account.id == id)
          .map((FinancialAccount account) => account.name)
          .firstOrNull ??
      'account';

  String? _optionalText(String value) =>
      value.trim().isEmpty ? null : value.trim();

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validatePositiveAmount(String? value) {
    final int? parsed = value == null ? null : parseMinorUnits(value);
    if (parsed == null || parsed <= 0) {
      return 'Enter an amount greater than zero with up to two decimals.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.88,
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
                      _title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
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
                    if (widget.action == WalletAction.addMoney) ...<Widget>[
                      TextFormField(
                        controller: _sourceController,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (String? value) =>
                            validateRequired(value, label: 'Source'),
                        decoration: const InputDecoration(
                          labelText: 'Source',
                          hintText: 'Salary, freelance, cash deposit',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _accountDropdown(
                        label: 'Receiving account',
                        accounts: _balanceAccounts,
                        value: _accountId,
                        onChanged: (String? value) =>
                            setState(() => _accountId = value),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _categoryField('Income category (optional)'),
                    ],
                    if (widget.action == WalletAction.expense) ...<Widget>[
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (String? value) =>
                            validateRequired(value, label: 'Description'),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Groceries, transport, utilities',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _accountDropdown(
                        label: 'Payment account',
                        accounts: _paymentAccounts,
                        value: _accountId,
                        onChanged: (String? value) =>
                            setState(() => _accountId = value),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _categoryField('Expense category (optional)'),
                    ],
                    if (widget.action == WalletAction.transfer) ...<Widget>[
                      _accountDropdown(
                        label: 'From account',
                        accounts: _balanceAccounts,
                        value: _fromAccountId,
                        onChanged: (String? value) => setState(() {
                          _fromAccountId = value;
                          if (_toAccountId == value) {
                            _toAccountId = _balanceAccounts
                                .where(
                                  (FinancialAccount item) => item.id != value,
                                )
                                .firstOrNull
                                ?.id;
                          }
                        }),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _accountDropdown(
                        label: 'To account',
                        accounts: _balanceAccounts
                            .where(
                              (FinancialAccount item) =>
                                  item.id != _fromAccountId &&
                                  item.currencyCode ==
                                      _accountCurrency(_fromAccountId),
                            )
                            .toList(growable: false),
                        value: _toAccountId,
                        onChanged: (String? value) =>
                            setState(() => _toAccountId = value),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (widget.action ==
                        WalletAction.adjustBalance) ...<Widget>[
                      _accountDropdown(
                        label: 'Account to reconcile',
                        accounts: _paymentAccounts,
                        value: _accountId,
                        onChanged: (String? value) =>
                            setState(() => _accountId = value),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        'Enter the actual balance. MyFinance records the difference as an adjustment.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    if (widget.action == WalletAction.cardPayment) ...<Widget>[
                      _accountDropdown(
                        label: 'Credit card account',
                        accounts: _creditCards,
                        value: _cardAccountId,
                        onChanged: (String? value) =>
                            setState(() => _cardAccountId = value),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _accountDropdown(
                        label: 'Payment source',
                        accounts: _balanceAccounts,
                        value: _paymentAccountId,
                        onChanged: (String? value) =>
                            setState(() => _paymentAccountId = value),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        'This reduces card debt and is not recorded as another expense.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                    ],
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: widget.action == WalletAction.adjustBalance
                          ? _validateBalance
                          : _validatePositiveAmount,
                      decoration: InputDecoration(
                        labelText: widget.action == WalletAction.adjustBalance
                            ? 'Actual balance'
                            : 'Amount',
                        prefixText: '${widget.currencyCode} ',
                      ),
                    ),
                    if (widget.action == WalletAction.transfer) ...<Widget>[
                      const SizedBox(height: AppSpacing.medium),
                      TextFormField(
                        controller: _feeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateFee,
                        decoration: InputDecoration(
                          labelText: 'Transfer fee (optional)',
                          prefixText: '${widget.currencyCode} ',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.medium),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text('Transaction date · ${_formatDate(_date)}'),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    _categoryField(
                      'Notes (optional)',
                      controller: _notesController,
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
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving…' : _title),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _accountDropdown({
    required String label,
    required List<FinancialAccount> accounts,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    if (accounts.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          'Add a compatible account first.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final String? selected =
        accounts.any((FinancialAccount account) => account.id == value)
        ? value
        : accounts.first.id;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      validator: (String? item) => item == null ? 'Choose an account.' : null,
      decoration: InputDecoration(labelText: label),
      items: accounts
          .map(
            (FinancialAccount account) => DropdownMenuItem<String>(
              value: account.id,
              child: Text(
                '${account.name} · ${account.provider ?? _typeLabel(account.accountType)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: _saving ? null : onChanged,
    );
  }

  Widget _categoryField(String label, {TextEditingController? controller}) =>
      TextFormField(
        controller: controller ?? _categoryController,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: label == 'Notes (optional)',
        ),
        minLines: label == 'Notes (optional)' ? 2 : 1,
        maxLines: label == 'Notes (optional)' ? 4 : 1,
        maxLength: label == 'Notes (optional)' ? 500 : 80,
      );

  String? _validateBalance(String? value) {
    final int? amount = value == null ? null : parseMinorUnits(value);
    if (amount == null) return 'Enter a valid balance with up to 2 decimals.';
    final FinancialAccount? account = widget.accounts
        .where((FinancialAccount item) => item.id == _accountId)
        .firstOrNull;
    if (amount < 0 && account?.allowNegativeBalance != true) {
      return 'This account does not allow a negative balance.';
    }
    if (account?.accountType == 'credit_card' && amount < 0) {
      return 'Outstanding credit cannot be negative.';
    }
    return null;
  }

  String? _validateFee(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final int? amount = parseMinorUnits(value);
    if (amount == null || amount < 0) {
      return 'Enter a fee of 0 or more with up to 2 decimals.';
    }
    return null;
  }

  String? _accountCurrency(String? id) => widget.accounts
      .where((FinancialAccount item) => item.id == id)
      .map((FinancialAccount item) => item.currencyCode)
      .firstOrNull;

  String _typeLabel(String type) => switch (type) {
    'cash' => 'Cash',
    'bank' => 'Bank',
    'savings' => 'Savings',
    'debit_card' => 'Debit card',
    'gcash' => 'GCash',
    'maya' => 'Maya',
    'e_wallet' => 'E-wallet',
    _ => 'Account',
  };

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}
