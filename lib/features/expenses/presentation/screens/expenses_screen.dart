import 'dart:io';

import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  static const Uuid _uuid = Uuid();
  static const List<String> _defaultCategories = <String>[
    'Food and groceries',
    'Transportation',
    'Housing and rent',
    'Electricity and water',
    'Internet and phone',
    'Healthcare',
    'Education',
    'Shopping',
    'Entertainment',
    'Insurance',
    'Subscriptions',
    'Family expenses',
    'Personal care',
    'Other',
  ];
  final TextEditingController _search = TextEditingController();
  final TextEditingController _minimumAmount = TextEditingController();
  final TextEditingController _maximumAmount = TextEditingController();
  String _status = 'all';
  String? _categoryFilter;
  String? _accountFilter;
  DateTimeRange? _dateFilter;
  bool _seedStarted = false;

  @override
  void dispose() {
    _search.dispose();
    _minimumAmount.dispose();
    _maximumAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesOverviewProvider);
    final transactions = ref.watch(recentTransactionsProvider);
    final categories = ref.watch(expenseCategoriesProvider);
    final accounts = ref.watch(walletManagementAccountsProvider);
    final List<ExpenseEntry> rows =
        expenses.asData?.value ?? const <ExpenseEntry>[];
    final List<CategoryEntry> categoryRows =
        categories.asData?.value ?? const <CategoryEntry>[];
    if (categories.hasValue && !_seedStarted) {
      _seedStarted = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _seedCategories(categoryRows),
      );
    }
    final Map<String, String> categoryNames = <String, String>{
      for (final CategoryEntry item in categoryRows) item.id: item.name,
    };
    final String q = _search.text.trim().toLowerCase();
    final int? minAmount = parseMinorUnits(_minimumAmount.text);
    final int? maxAmount = parseMinorUnits(_maximumAmount.text);
    final List<ExpenseEntry> visible = rows
        .where(
          (ExpenseEntry item) =>
              (_status == 'all' || item.status == _status) &&
              (_categoryFilter == null || item.categoryId == _categoryFilter) &&
              (_accountFilter == null ||
                  item.paymentAccountId == _accountFilter) &&
              (_dateFilter == null ||
                  (!item.occurredAt.isBefore(_dateFilter!.start) &&
                      item.occurredAt.isBefore(
                        _dateFilter!.end.add(const Duration(days: 1)),
                      ))) &&
              (minAmount == null || item.amountMinorUnits >= minAmount) &&
              (maxAmount == null || item.amountMinorUnits <= maxAmount) &&
              (q.isEmpty ||
                  item.title.toLowerCase().contains(q) ||
                  (item.description ?? '').toLowerCase().contains(q)),
        )
        .toList(growable: false);
    final int monthSpend = rows
        .where(
          (ExpenseEntry e) =>
              e.status == 'confirmed' &&
              e.occurredAt.year == DateTime.now().year &&
              e.occurredAt.month == DateTime.now().month,
        )
        .fold<int>(0, (int sum, ExpenseEntry e) => sum + e.amountMinorUnits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add category',
            onPressed: _addCategory,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: 'Add expense',
            onPressed: () => _editExpense(
              categoryRows,
              accounts.asData?.value ?? const [],
              null,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editExpense(
          categoryRows,
          accounts.asData?.value ?? const [],
          null,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            _message('Expenses could not be loaded.'),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.medium,
            AppSpacing.medium,
            AppSpacing.medium,
            100,
          ),
          children: <Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.north_east_rounded),
                title: const Text('Recorded spending this month'),
                trailing: Text(
                  Money(monthSpend, currencyCode: 'PHP').format(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search expenses',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.small),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'planned',
                        child: Text('Planned'),
                      ),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('Recorded'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (String? value) =>
                        setState(() => _status = value ?? 'all'),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryFilter,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...categoryRows.map(
                        (CategoryEntry c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (String? value) =>
                        setState(() => _categoryFilter = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _accountFilter,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All accounts'),
                      ),
                      ...(accounts.asData?.value ?? const <FinancialAccount>[])
                          .map(
                            (FinancialAccount account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(
                                account.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (String? value) =>
                        setState(() => _accountFilter = value),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final DateTimeRange? selected = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: _dateFilter,
                      );
                      if (selected != null) {
                        setState(() => _dateFilter = selected);
                      }
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _dateFilter == null
                          ? 'Any dates'
                          : '${DateFormat.Md().format(_dateFilter!.start)}–${DateFormat.Md().format(_dateFilter!.end)}',
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minimumAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Min PHP'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: TextField(
                    controller: _maximumAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Max PHP'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            if (visible.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No expenses match this view.'),
                ),
              )
            else
              ...visible.map(
                (ExpenseEntry item) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${categoryNames[item.categoryId] ?? 'Uncategorised'} · ${item.status} · ${DateFormat.yMMMd().format(item.occurredAt.toLocal())}${item.recurrenceConfiguration == null ? '' : ' · recurring template'}',
                    ),
                    trailing: Text(
                      Money(
                        item.amountMinorUnits,
                        currencyCode: item.currencyCode,
                      ).format(),
                    ),
                    onTap: () => _details(item, categoryNames),
                  ),
                ),
              ),
            ...visible
                .where((ExpenseEntry item) => item.status == 'confirmed')
                .map((ExpenseEntry expense) {
                  final FinancialTransactionView? transaction =
                      (transactions.asData?.value ??
                              const <FinancialTransactionView>[])
                          .where(
                            (FinancialTransactionView item) =>
                                <String>{
                                  'expense',
                                  'credit_card_purchase',
                                }.contains(item.type) &&
                                item.relatedRecordId == expense.id,
                          )
                          .firstOrNull;
                  if (transaction == null) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _reverseExpense(expense, transaction),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Reverse expense'),
                    ),
                  );
                }),
            ...visible
                .where((ExpenseEntry item) => item.status == 'planned')
                .map(
                  (ExpenseEntry item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.small),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.small,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _editExpense(
                            categoryRows,
                            accounts.asData?.value ?? const [],
                            item,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmExpense(
                            item,
                            accounts.asData?.value ?? const [],
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Record payment'),
                        ),
                        IconButton(
                          tooltip: 'Cancel expense',
                          onPressed: () => _cancel(item),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedCategories(List<CategoryEntry> existing) async {
    final Set<String> names = existing
        .map((CategoryEntry item) => item.name.toLowerCase())
        .toSet();
    final FinancialRepository repository = ref.read(
      financialRepositoryProvider,
    );
    for (final String name in _defaultCategories.where(
      (String name) => !names.contains(name.toLowerCase()),
    )) {
      try {
        await repository.createCategory(
          CreateCategoryInput(
            name: name,
            categoryType: 'expense',
            isDefault: true,
          ),
        );
      } catch (_) {
        /* A concurrent first launch may have seeded it. */
      }
    }
  }

  Future<void> _addCategory() async {
    final TextEditingController name = TextEditingController();
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('New expense category'),
        content: TextField(
          controller: name,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, name.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .createCategory(
              CreateCategoryInput(
                name: name.text.trim(),
                categoryType: 'expense',
              ),
            );
      } catch (error) {
        _toast('Could not add category: $error');
      }
    }
    name.dispose();
  }

  Future<void> _editExpense(
    List<CategoryEntry> categories,
    List<FinancialAccount> accounts,
    ExpenseEntry? expense,
  ) async {
    final List<FinancialAccount> eligible = accounts
        .where(
          (FinancialAccount item) => item.isActive && item.archivedAt == null,
        )
        .toList();
    final TextEditingController title = TextEditingController(
      text: expense?.title ?? '',
    );
    final TextEditingController amount = TextEditingController(
      text: expense == null
          ? ''
          : (expense.amountMinorUnits / 100).toStringAsFixed(2),
    );
    final TextEditingController notes = TextEditingController(
      text: expense?.description ?? '',
    );
    final TextEditingController recurrence = TextEditingController(
      text: expense?.recurrenceConfiguration ?? '',
    );
    DateTime date = expense?.occurredAt ?? DateTime.now();
    String? categoryId =
        expense?.categoryId ??
        (categories.isEmpty ? null : categories.first.id);
    String? accountId = expense?.paymentAccountId;
    String? attachmentReference = expense?.attachmentReference;
    final form = GlobalKey<FormState>();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: Text(
            expense == null ? 'Add planned expense' : 'Edit planned expense',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (String? value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a title.'
                          : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'PHP ',
                      ),
                      validator: (String? value) {
                        final int? n = value == null
                            ? null
                            : parseMinorUnits(value);
                        return n == null || n <= 0
                            ? 'Enter an amount greater than zero.'
                            : null;
                      },
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No category'),
                        ),
                        ...categories.map(
                          (CategoryEntry item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (String? value) =>
                          setDialogState(() => categoryId = value),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'Suggested payment account',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Choose when recording'),
                        ),
                        ...eligible.map(
                          (FinancialAccount item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.name} · ${item.accountType.replaceAll('_', ' ')}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (String? value) =>
                          setDialogState(() => accountId = value),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final DateTime? chosen = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (chosen != null) {
                          setDialogState(() => date = chosen);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(DateFormat.yMMMd().format(date)),
                    ),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(
                        labelText: 'Description / notes (optional)',
                      ),
                      maxLines: 2,
                    ),
                    TextFormField(
                      controller: recurrence,
                      decoration: const InputDecoration(
                        labelText: 'Recurring schedule (optional)',
                        hintText: 'e.g. monthly',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final String? reference = await _pickReceipt();
                        if (reference != null) {
                          setDialogState(() => attachmentReference = reference);
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        attachmentReference == null
                            ? 'Attach receipt image'
                            : 'Receipt attached',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      final FinancialRepository repository = ref.read(
        financialRepositoryProvider,
      );
      try {
        if (expense == null) {
          await repository.createExpense(
            CreateExpenseInput(
              title: title.text.trim(),
              amountMinorUnits: parseMinorUnits(amount.text)!,
              occurredAt: date,
              categoryId: categoryId,
              paymentAccountId: accountId,
              description: notes.text.trim().isEmpty ? null : notes.text.trim(),
              attachmentReference: attachmentReference,
              recurrenceConfiguration: recurrence.text.trim().isEmpty
                  ? null
                  : recurrence.text.trim(),
            ),
          );
        } else {
          await repository.updateExpense(
            UpdateExpenseInput(
              expenseId: expense.id,
              title: title.text.trim(),
              amountMinorUnits: parseMinorUnits(amount.text)!,
              occurredAt: date,
              categoryId: categoryId,
              paymentAccountId: accountId,
              description: notes.text.trim().isEmpty ? null : notes.text.trim(),
              attachmentReference: attachmentReference,
              recurrenceConfiguration: recurrence.text.trim().isEmpty
                  ? null
                  : recurrence.text.trim(),
            ),
          );
        }
      } catch (error) {
        _toast('Could not save expense: $error');
      }
    }
    title.dispose();
    amount.dispose();
    notes.dispose();
    recurrence.dispose();
  }

  Future<String?> _pickReceipt() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final Directory documents = await getApplicationDocumentsDirectory();
      final Directory receipts = Directory('${documents.path}/receipts');
      await receipts.create(recursive: true);
      final String extension = picked.name.contains('.')
          ? picked.name.substring(picked.name.lastIndexOf('.'))
          : '.jpg';
      final String destination = '${receipts.path}/${_uuid.v4()}$extension';
      await File(picked.path).copy(destination);
      return destination;
    } catch (error) {
      _toast('Could not attach receipt: $error');
      return null;
    }
  }

  Future<void> _confirmExpense(
    ExpenseEntry expense,
    List<FinancialAccount> accounts,
  ) async {
    final List<FinancialAccount> eligible = accounts
        .where(
          (FinancialAccount item) =>
              item.isActive &&
              item.archivedAt == null &&
              item.currencyCode == expense.currencyCode,
        )
        .toList();
    if (eligible.isEmpty) {
      _toast('Add an active payment account first.');
      return;
    }
    String accountId =
        eligible.any(
          (FinancialAccount item) => item.id == expense.paymentAccountId,
        )
        ? expense.paymentAccountId!
        : eligible.first.id;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Record expense payment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Record ${Money(expense.amountMinorUnits, currencyCode: expense.currencyCode).format()} for ${expense.title}?',
              ),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Payment account'),
                items: eligible
                    .map(
                      (FinancialAccount item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          '${item.name} · ${item.accountType.replaceAll('_', ' ')}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setDialogState(() => accountId = value);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (yes == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .confirmExpense(
              ConfirmExpenseInput(
                expenseId: expense.id,
                accountId: accountId,
                confirmedAt: DateTime.now(),
                idempotencyKey: _uuid.v4(),
              ),
            );
      } catch (error) {
        _toast('Could not record expense: $error');
      }
    }
  }

  Future<void> _cancel(ExpenseEntry expense) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancel planned expense?'),
        content: Text('“${expense.title}” will be kept as cancelled.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel expense'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref.read(financialRepositoryProvider).cancelExpense(expense.id);
      } catch (error) {
        _toast('Could not cancel expense: $error');
      }
    }
  }

  Future<void> _reverseExpense(
    ExpenseEntry expense,
    FinancialTransactionView transaction,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reverse this expense?'),
        content: const Text(
          'The original transaction stays in history. A reversal will restore the account balance or reduce card debt.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .reverseTransaction(
              transactionId: transaction.id,
              reversedAt: DateTime.now(),
              idempotencyKey: _uuid.v4(),
              notes: 'Expense correction: ${expense.title}',
            );
      } catch (error) {
        _toast('Could not reverse expense: $error');
      }
    }
  }

  void _details(
    ExpenseEntry item,
    Map<String, String> categories,
  ) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(item.title),
      content: Text(
        '${Money(item.amountMinorUnits, currencyCode: item.currencyCode).format()}\n${categories[item.categoryId] ?? 'Uncategorised'} · ${item.status}\n${DateFormat.yMMMd().format(item.occurredAt.toLocal())}${item.description == null ? '' : '\n\n${item.description}'}',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Widget _message(String text) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
  );
  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}
