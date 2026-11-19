import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/core/utils/dialog_route.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:bill_tracker/core/widgets/app_card.dart';
import 'package:bill_tracker/core/widgets/empty_state.dart';
import 'package:bill_tracker/core/widgets/summary_card.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/loans/domain/services/loan_status_calculator.dart';
import 'package:bill_tracker/features/loans/domain/services/loan_schedule_calculator.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _NewLoanCategoryDialog extends StatefulWidget {
  const _NewLoanCategoryDialog({required this.existing, required this.onSave});

  final List<CategoryEntry> existing;
  final Future<CategoryEntry> Function(String name) onSave;

  @override
  State<_NewLoanCategoryDialog> createState() => _NewLoanCategoryDialogState();
}

class _NewLoanCategoryDialogState extends State<_NewLoanCategoryDialog> {
  final TextEditingController _name = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New loan category'),
    content: Form(
      key: _form,
      child: TextFormField(
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        controller: _name,
        autofocus: true,
        maxLength: 80,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: 'Category name',
          errorText: _saveError,
        ),
        validator: (String? value) {
          final String normalized = value?.trim() ?? '';
          if (normalized.isEmpty) return 'Please enter a category name.';
          if (widget.existing.any(
            (CategoryEntry item) =>
                item.name.trim().toLowerCase() == normalized.toLowerCase(),
          )) {
            return 'This category already exists.';
          }
          return null;
        },
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final CategoryEntry created = await widget.onSave(_name.text.trim());
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not save category. Please try again.';
        });
      }
    }
  }
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  static const Uuid _uuid = Uuid();
  static const List<String> _providers = <String>[
    'GCash',
    'BillEase',
    'Tala',
    'Atome',
    'Maya Credit',
    'Home Credit',
    'Shopee SPayLater',
    'LazPayLater',
    'Bank Loans',
    'Personal Loans',
    'Other',
  ];
  bool _loanCategorySeedStarted = false;
  String _loanFilter = 'active';
  static const List<String> _defaultLoanCategories = <String>[
    'Personal',
    'Mortgage',
    'Auto',
    'Education',
    'Business',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansOverviewProvider);
    final installmentsAsync = ref.watch(installmentsOverviewProvider);
    final accountsAsync = ref.watch(walletManagementAccountsProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final paymentsAsync = ref.watch(loanPaymentsOverviewProvider);
    final categoriesAsync = ref.watch(loanCategoriesProvider);
    final allCategoriesAsync = ref.watch(
      loanCategoriesIncludingArchivedProvider,
    );
    final List<CategoryEntry> loanCategories =
        categoriesAsync.asData?.value ?? const <CategoryEntry>[];
    final List<CategoryEntry> allLoanCategories =
        allCategoriesAsync.asData?.value ?? loanCategories;
    if (categoriesAsync.hasValue &&
        allCategoriesAsync.hasValue &&
        !_loanCategorySeedStarted) {
      _loanCategorySeedStarted = true;
      if (allLoanCategories.isEmpty) _seedLoanCategories();
    }
    final currency =
        ref.watch(userPreferencesProvider).asData?.value.currencyCode ?? 'PHP';
    final dateFormat =
        ref.watch(userPreferencesProvider).asData?.value.dateFormat ??
        'MM/dd/yyyy';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Filter loans',
            initialValue: _loanFilter,
            onSelected: (String value) => setState(() => _loanFilter = value),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem(
                    value: 'active',
                    child: Text('Active and overdue'),
                  ),
                  PopupMenuItem(value: 'paid', child: Text('Fully paid')),
                  PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  PopupMenuItem(value: 'archived', child: Text('Archived')),
                  PopupMenuItem(value: 'all', child: Text('All loans')),
                ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editLoan(
          null,
          accountsAsync.asData?.value ?? const <FinancialAccount>[],
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add loan'),
      ),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(loansOverviewProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Could not load loans. Try again.'),
          ),
        ),
        data: (List<LoanEntry> loans) {
          final installments =
              installmentsAsync.asData?.value ?? const <LoanInstallmentEntry>[];
          final accounts =
              accountsAsync.asData?.value ?? const <FinancialAccount>[];
          final transactions =
              transactionsAsync.asData?.value ??
              const <FinancialTransactionView>[];
          final loanPayments =
              paymentsAsync.asData?.value ?? const <LoanPaymentEntry>[];
          final today = DateTime.now();
          final visible = loans
              .where((LoanEntry loan) {
                final state = LoanStatusCalculator.status(
                  loan,
                  installments,
                  today,
                );
                return switch (_loanFilter) {
                  'active' =>
                    loan.archivedAt == null &&
                        state != LoanStatus.fullyPaid &&
                        state != LoanStatus.cancelled,
                  'paid' =>
                    loan.archivedAt == null && state == LoanStatus.fullyPaid,
                  'cancelled' =>
                    loan.archivedAt == null && state == LoanStatus.cancelled,
                  'archived' => loan.archivedAt != null,
                  _ => true,
                };
              })
              .toList(growable: false);
          final active = loans
              .where(
                (LoanEntry loan) =>
                    loan.archivedAt == null &&
                    loan.status != 'cancelled' &&
                    loan.remainingBalanceMinorUnits > 0,
              )
              .toList();
          final overdue = installments.where((LoanInstallmentEntry item) {
            final parent = active
                .where((LoanEntry loan) => loan.id == item.loanId)
                .firstOrNull;
            return parent != null &&
                item.status != 'settled' &&
                item.scheduledMinorUnits > item.paidMinorUnits &&
                _beforeToday(item.dueDate, today);
          }).toList();
          final upcoming =
              installments.where((LoanInstallmentEntry item) {
                final parent = active
                    .where((LoanEntry loan) => loan.id == item.loanId)
                    .firstOrNull;
                return parent != null &&
                    item.status != 'settled' &&
                    item.scheduledMinorUnits > item.paidMinorUnits &&
                    !_beforeToday(item.dueDate, today);
              }).toList()..sort(
                (LoanInstallmentEntry a, LoanInstallmentEntry b) =>
                    a.dueDate.compareTo(b.dueDate),
              );
          final Map<String, List<LoanEntry>> grouped =
              <String, List<LoanEntry>>{};
          for (final loan in loans.where(
            (LoanEntry item) => item.archivedAt == null,
          )) {
            grouped
                .putIfAbsent(loan.providerName, () => <LoanEntry>[])
                .add(loan);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              96,
            ),
            children: <Widget>[
              Text(
                'Loan overview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.small),
              const Text(
                'Existing loans are recorded as obligations only. Adding a loan never increases a wallet balance.',
              ),
              const SizedBox(height: AppSpacing.medium),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  const int columns = 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpacing.small,
                    mainAxisSpacing: AppSpacing.small,
                    childAspectRatio:
                        ((box.maxWidth - AppSpacing.small) / columns) / 132,
                    children: <Widget>[
                      SummaryCard(
                        label: 'Active loans',
                        value: active.length.toString(),
                        icon: Icons.credit_score_outlined,
                      ),
                      SummaryCard(
                        label: 'Overdue installments',
                        value: overdue.length.toString(),
                        icon: Icons.warning_amber_outlined,
                      ),
                      SummaryCard(
                        label: 'Upcoming installments',
                        value: upcoming.length.toString(),
                        icon: Icons.event_outlined,
                      ),
                      SummaryCard(
                        label: 'Fully paid',
                        value: loans
                            .where(
                              (LoanEntry loan) =>
                                  loan.remainingBalanceMinorUnits == 0,
                            )
                            .length
                            .toString(),
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.large),
              Text('Providers', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.small),
              if (grouped.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'No loans yet',
                    message:
                        'Add an existing loan to track its installments and repayments.',
                  ),
                )
              else
                ...grouped.entries.map((entry) {
                  final providerLoans = entry.value;
                  final amount = providerLoans
                      .where((LoanEntry loan) => loan.currencyCode == currency)
                      .fold<int>(
                        0,
                        (int sum, LoanEntry loan) =>
                            sum + loan.remainingBalanceMinorUnits,
                      );
                  final providerStatus =
                      providerLoans.any(
                        (LoanEntry loan) =>
                            LoanStatusCalculator.status(
                              loan,
                              installments,
                              today,
                            ) ==
                            LoanStatus.overdue,
                      )
                      ? LoanStatus.overdue
                      : providerLoans.every(
                          (LoanEntry loan) =>
                              loan.remainingBalanceMinorUnits == 0,
                        )
                      ? LoanStatus.fullyPaid
                      : providerLoans.every(
                          (LoanEntry loan) => loan.status == 'cancelled',
                        )
                      ? LoanStatus.cancelled
                      : LoanStatus.inProgress;
                  final Set<String> providerIds = providerLoans
                      .where((LoanEntry loan) => loan.currencyCode == currency)
                      .map((LoanEntry loan) => loan.id)
                      .toSet();
                  final paidAmount = loanPayments
                      .where(
                        (LoanPaymentEntry item) =>
                            providerIds.contains(item.loanId) &&
                            item.status == 'confirmed',
                      )
                      .fold<int>(
                        0,
                        (int sum, LoanPaymentEntry item) =>
                            sum + item.amountMinorUnits,
                      );
                  final remainingInstallments = installments
                      .where(
                        (LoanInstallmentEntry item) =>
                            providerLoans.any(
                              (LoanEntry loan) => loan.id == item.loanId,
                            ) &&
                            item.status != 'settled' &&
                            item.scheduledMinorUnits > item.paidMinorUnits,
                      )
                      .length;
                  final due =
                      providerLoans
                          .map((LoanEntry loan) => loan.nextDueDate)
                          .whereType<DateTime>()
                          .toList()
                        ..sort();
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                entry.key,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _StatusChip(status: _statusLabel(providerStatus)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${providerLoans.length} loans · Principal ${Money(providerLoans.fold<int>(0, (int n, LoanEntry loan) => n + loan.principalMinorUnits), currencyCode: currency).format()} · Paid ${Money(paidAmount, currencyCode: currency).format()}',
                        ),
                        Text(
                          'Outstanding ${Money(amount, currencyCode: currency).format()} · $remainingInstallments installments remaining${due.isEmpty ? '' : ' · Next due ${DateFormat(dateFormat).format(due.first)}'}',
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.large),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _loanFilter == 'active'
                          ? 'Loans'
                          : '${_loanFilter[0].toUpperCase()}${_loanFilter.substring(1)} loans',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (installmentsAsync.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
              if (visible.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing to show',
                    message: 'Add a loan or choose another loan filter.',
                  ),
                )
              else
                ...visible.map((LoanEntry loan) {
                  final status = LoanStatusCalculator.status(
                    loan,
                    installments,
                    today,
                  );
                  final rows = installments
                      .where(
                        (LoanInstallmentEntry item) => item.loanId == loan.id,
                      )
                      .toList();
                  final complete = rows
                      .where(
                        (LoanInstallmentEntry item) =>
                            item.status == 'paid' || item.status == 'settled',
                      )
                      .length;
                  final total = rows.length;
                  final String? categoryName = allLoanCategories
                      .where((CategoryEntry item) => item.id == loan.categoryId)
                      .map((CategoryEntry item) => item.name)
                      .firstOrNull;
                  return Card(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          onTap: () => _showDetails(
                            loan,
                            rows,
                            accounts,
                            transactions,
                            loanPayments,
                            dateFormat,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              loan.providerName.characters.first.toUpperCase(),
                            ),
                          ),
                          title: Text(
                            loan.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${loan.providerName}${categoryName == null ? '' : ' · $categoryName'} · ${total == 0 ? 'No installments' : '$complete of $total installments paid'}${loan.nextDueDate == null ? '' : ' · Next ${DateFormat(dateFormat).format(loan.nextDueDate!)}'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Loan actions',
                            onSelected: (String action) =>
                                _loanAction(action, loan, accounts),
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  if (loan.archivedAt == null)
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit loan'),
                                    ),
                                  if (loan.archivedAt == null)
                                    const PopupMenuItem(
                                      value: 'disbursement',
                                      child: Text('Record funds received'),
                                    ),
                                  if (loan.archivedAt == null &&
                                      loan.status != 'cancelled')
                                    const PopupMenuItem(
                                      value: 'adjust',
                                      child: Text('Adjust lender balance'),
                                    ),
                                  if (loan.archivedAt == null &&
                                      loan.status != 'cancelled' &&
                                      loan.remainingBalanceMinorUnits > 0)
                                    const PopupMenuItem(
                                      value: 'cancel',
                                      child: Text('Cancel loan'),
                                    ),
                                  if (loan.archivedAt == null)
                                    const PopupMenuItem(
                                      value: 'archive',
                                      child: Text('Archive'),
                                    ),
                                  if (loan.archivedAt != null)
                                    const PopupMenuItem(
                                      value: 'reopen',
                                      child: Text('Reopen'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove loan'),
                                  ),
                                ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.medium,
                            0,
                            AppSpacing.medium,
                            AppSpacing.small,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Expanded(child: Text('Remaining balance')),
                              Flexible(
                                child: Text(
                                  Money(
                                    loan.remainingBalanceMinorUnits,
                                    currencyCode: loan.currencyCode,
                                  ).format(),
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xSmall),
                              _StatusChip(status: _statusLabel(status)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  bool _beforeToday(DateTime value, DateTime today) => DateTime(
    value.year,
    value.month,
    value.day,
  ).isBefore(DateTime(today.year, today.month, today.day));

  String _statusLabel(LoanStatus status) => switch (status) {
    LoanStatus.notStarted => 'Not started',
    LoanStatus.inProgress => 'In progress',
    LoanStatus.overdue => 'Overdue',
    LoanStatus.fullyPaid => 'Fully paid',
    LoanStatus.cancelled => 'Cancelled',
  };

  Future<T?> _showDialogAndWaitForExit<T>(WidgetBuilder builder) =>
      showDialogAndWaitForExit<T>(context: context, builder: builder);

  Future<void> _seedLoanCategories() async {
    final repository = ref.read(financialRepositoryProvider);
    try {
      for (final String name in _defaultLoanCategories) {
        await repository.createCategory(
          CreateCategoryInput(
            name: name,
            categoryType: 'loan',
            isDefault: true,
          ),
        );
      }
    } catch (error) {
      _toast('Could not load default loan categories: $error');
    }
  }

  Stream<List<CategoryEntry>> _loanCategoryStream() => ref
      .read(financialRepositoryProvider)
      .watchCategories(categoryType: 'loan');

  Future<CategoryEntry?> _createLoanCategory(List<CategoryEntry> existing) =>
      showDialog<CategoryEntry>(
        context: context,
        builder: (BuildContext context) => _NewLoanCategoryDialog(
          existing: existing,
          onSave: (String name) async {
            final String id = await ref
                .read(financialRepositoryProvider)
                .createCategory(
                  CreateCategoryInput(name: name, categoryType: 'loan'),
                );
            ref.invalidate(loanCategoriesProvider);
            ref.invalidate(loanCategoriesIncludingArchivedProvider);
            return CategoryEntry(
              id: id,
              name: name,
              categoryType: 'loan',
              isDefault: false,
            );
          },
        ),
      );

  Future<bool> _removeLoanCategory(CategoryEntry category) async {
    if (category.isDefault) return false;
    final List<LoanEntry> loans =
        ref.read(loansOverviewProvider).asData?.value ?? const <LoanEntry>[];
    final bool used = loans.any(
      (LoanEntry loan) => loan.categoryId == category.id,
    );
    final bool? confirmed = await _showDialogAndWaitForExit<bool>(
      (BuildContext context) => AlertDialog(
        title: const Text('Remove custom category?'),
        content: Text(
          used
              ? 'Loans already using "${category.name}" will keep this category in their history. It will no longer be available for new loans.'
              : 'Remove "${category.name}" from your loan categories?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    try {
      await ref.read(financialRepositoryProvider).archiveCategory(category.id);
      ref.invalidate(loanCategoriesProvider);
      ref.invalidate(loanCategoriesIncludingArchivedProvider);
      return true;
    } catch (error) {
      _toast('Could not remove category: $error');
      return false;
    }
  }

  Future<void> _editLoan(
    LoanEntry? loan,
    List<FinancialAccount> accounts,
  ) async {
    final repository = ref.read(financialRepositoryProvider);
    final List<CategoryEntry> categories =
        ref.read(loanCategoriesProvider).asData?.value ??
        const <CategoryEntry>[];
    final List<CategoryEntry> existingCategories =
        ref.read(loanCategoriesIncludingArchivedProvider).asData?.value ??
        categories;
    final name = TextEditingController(text: loan?.name ?? '');
    final provider = TextEditingController(text: loan?.providerName ?? '');
    final principal = TextEditingController(
      text: loan == null
          ? ''
          : (loan.principalMinorUnits / 100).toStringAsFixed(2),
    );
    final interest = TextEditingController(
      text: loan == null
          ? ''
          : (loan.totalInterestMinorUnits / 100).toStringAsFixed(2),
    );
    final repaymentAmount = TextEditingController(
      text: loan == null
          ? ''
          : (loan.totalRepaymentMinorUnits / 100).toStringAsFixed(2),
    );
    final rate = TextEditingController(
      text: loan == null
          ? '0'
          : (loan.interestRateBasisPoints / 100).toStringAsFixed(2),
    );
    final installment = TextEditingController(
      text: loan == null
          ? ''
          : (loan.installmentAmountMinorUnits / 100).toStringAsFixed(2),
    );
    final count = TextEditingController(
      text: loan?.totalInstallments.toString() ?? '12',
    );
    final duration = TextEditingController(
      text: loan?.durationMonths?.toString() ?? '12',
    );
    final customDays = TextEditingController(
      text: loan?.paymentFrequency.startsWith('custom:') == true
          ? loan!.paymentFrequency.substring(7)
          : '30',
    );
    final notes = TextEditingController(text: loan?.notes ?? '');
    String frequency = loan?.paymentFrequency.startsWith('custom:') == true
        ? 'custom'
        : loan?.paymentFrequency ?? 'monthly';
    String? accountId = loan?.paymentAccountId;
    String? categoryId = loan?.categoryId;
    final List<CategoryEntry> formCategories = <CategoryEntry>[
      ...existingCategories,
    ];
    if (categoryId != null &&
        !formCategories.any((CategoryEntry item) => item.id == categoryId)) {
      formCategories.add(
        CategoryEntry(
          id: categoryId,
          name: 'Existing category',
          categoryType: 'loan',
          isDefault: true,
          isArchived: true,
        ),
      );
    }
    final Set<String> removedCategoryIds = <String>{};
    final Map<String, CategoryEntry> createdInForm = <String, CategoryEntry>{};

    Future<void> selectLoanCategory(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final Stream<List<CategoryEntry>> categoriesStream =
          _loanCategoryStream();
      final String? selected = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        builder: (BuildContext pickerContext) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setPickerState) =>
              AlertDialog(
                title: const Text('Choose loan category'),
                content: SizedBox(
                  width: 400,
                  height: MediaQuery.sizeOf(context).height * 0.45,
                  child: StreamBuilder<List<CategoryEntry>>(
                    stream: categoriesStream,
                    builder: (BuildContext context, snapshot) {
                      final Map<String, CategoryEntry> byId =
                          <String, CategoryEntry>{
                            for (final CategoryEntry item
                                in (snapshot.data ?? formCategories))
                              if (!item.isArchived &&
                                  !removedCategoryIds.contains(item.id))
                                item.id: item,
                            for (final CategoryEntry item
                                in createdInForm.values)
                              if (!removedCategoryIds.contains(item.id))
                                item.id: item,
                          };
                      final List<CategoryEntry> available = byId.values.toList()
                        ..sort((CategoryEntry a, CategoryEntry b) {
                          if (a.isDefault != b.isDefault) {
                            return a.isDefault ? 1 : -1;
                          }
                          return a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          );
                        });
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          available.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView(
                        children: <Widget>[
                          ListTile(
                            title: const Text('No category'),
                            selected: categoryId == null,
                            onTap: () => Navigator.pop(pickerContext, ''),
                          ),
                          if (available.isEmpty)
                            const ListTile(
                              title: Text('No loan categories available.'),
                            ),
                          ...available.map((CategoryEntry item) {
                            final bool isSelected = categoryId == item.id;
                            return ListTile(
                              title: Text(item.name),
                              selected: isSelected,
                              trailing: item.isDefault
                                  ? null
                                  : IconButton(
                                      tooltip: 'Remove ${item.name}',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () async {
                                        final bool removed =
                                            await _removeLoanCategory(item);
                                        if (!removed ||
                                            !pickerContext.mounted) {
                                          return;
                                        }
                                        removedCategoryIds.add(item.id);
                                        createdInForm.remove(item.id);
                                        if (loan?.categoryId == item.id) {
                                          final int index = formCategories
                                              .indexWhere(
                                                (CategoryEntry category) =>
                                                    category.id == item.id,
                                              );
                                          if (index >= 0) {
                                            final CategoryEntry old =
                                                formCategories[index];
                                            formCategories[index] =
                                                CategoryEntry(
                                                  id: old.id,
                                                  name: old.name,
                                                  categoryType:
                                                      old.categoryType,
                                                  isDefault: old.isDefault,
                                                  isArchived: true,
                                                );
                                          }
                                        } else {
                                          formCategories.removeWhere(
                                            (CategoryEntry category) =>
                                                category.id == item.id,
                                          );
                                          if (categoryId == item.id) {
                                            setDialogState(
                                              () => categoryId = null,
                                            );
                                          }
                                        }
                                        setPickerState(() {});
                                      },
                                    ),
                              onTap: () =>
                                  Navigator.pop(pickerContext, item.id),
                            );
                          }),
                          const Divider(),
                          ListTile(
                            title: const Text('Add other category'),
                            onTap: () async {
                              final List<CategoryEntry>
                              existing = <CategoryEntry>{
                                ...available,
                                ...ref
                                        .read(
                                          loanCategoriesIncludingArchivedProvider,
                                        )
                                        .asData
                                        ?.value ??
                                    const <CategoryEntry>[],
                              }.toList();
                              final CategoryEntry? created =
                                  await _createLoanCategory(existing);
                              if (created == null || !pickerContext.mounted) {
                                return;
                              }
                              createdInForm[created.id] = created;
                              if (!formCategories.any(
                                (CategoryEntry item) => item.id == created.id,
                              )) {
                                formCategories.add(created);
                              }
                              setPickerState(() {});
                              Navigator.pop(pickerContext, created.id);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(pickerContext),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        ),
      );
      if (selected != null && dialogContext.mounted) {
        setDialogState(() => categoryId = selected.isEmpty ? null : selected);
      }
    }

    DateTime opened = loan?.openedAt ?? DateTime.now();
    DateTime firstDue =
        loan?.nextDueDate ?? DateTime.now().add(const Duration(days: 30));
    final form = GlobalKey<FormState>();
    final bool? save = await _showDialogAndWaitForExit<bool>(
      (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateDialog) => AlertDialog(
          title: Text(loan == null ? 'Add loan' : 'Edit loan'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.small,
                  children: <Widget>[
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Loan name'),
                      validator: _required,
                    ),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: provider.text),
                      optionsBuilder: (TextEditingValue value) =>
                          _providers.where(
                            (String item) => item.toLowerCase().contains(
                              value.text.toLowerCase(),
                            ),
                          ),
                      onSelected: (String value) => provider.text = value,
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController controller,
                            FocusNode focus,
                            VoidCallback submit,
                          ) {
                            return TextFormField(
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              controller: controller,
                              focusNode: focus,
                              onChanged: (String value) =>
                                  provider.text = value,
                              decoration: const InputDecoration(
                                labelText: 'Provider (choose or enter custom)',
                              ),
                              validator: _required,
                            );
                          },
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          selectLoanCategory(dialogContext, setStateDialog),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Loan category',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  formCategories
                                          .where(
                                            (CategoryEntry item) =>
                                                item.id == categoryId,
                                          )
                                          .map(
                                            (CategoryEntry item) => item.name,
                                          )
                                          .firstOrNull ??
                                      'No category',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: principal,
                      enabled: loan == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Original principal (PHP)',
                      ),
                      validator: _moneyRequired,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: interest,
                      enabled: loan == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total interest (PHP, optional)',
                      ),
                      validator: _moneyOptional,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: repaymentAmount,
                      enabled: loan == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total repayment amount (PHP)',
                        helperText:
                            'Leave blank to use principal plus interest.',
                      ),
                      validator: _repaymentValidator,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: rate,
                      enabled: loan == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Interest rate (% per year, optional)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      validator: _decimalOptional,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: installment,
                      enabled: loan == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Installment amount (PHP)',
                      ),
                      validator: _moneyOptional,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: count,
                      enabled: loan == null,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of installments',
                      ),
                      validator: _positiveInt,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: duration,
                      enabled: loan == null,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration in months (optional)',
                      ),
                      validator: _intOptional,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      isExpanded: true,
                      // Editing an existing schedule is handled installment by installment.
                      onChanged: loan == null
                          ? (String? value) => setStateDialog(
                              () => frequency = value ?? frequency,
                            )
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Payment frequency',
                      ),
                      items:
                          const <String>[
                                'weekly',
                                'biweekly',
                                'monthly',
                                'quarterly',
                                'custom',
                              ]
                              .map(
                                (String item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item == 'biweekly'
                                        ? 'Biweekly'
                                        : '${item[0].toUpperCase()}${item.substring(1)}',
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    if (frequency == 'custom' && loan == null)
                      TextFormField(
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        controller: customDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Custom interval (days)',
                        ),
                        validator: _positiveInt,
                      ),
                    if (loan == null) ...<Widget>[
                      _dateButton(
                        context,
                        'Loan start date',
                        opened,
                        (DateTime value) =>
                            setStateDialog(() => opened = value),
                      ),
                      _dateButton(
                        context,
                        'Due date',
                        firstDue,
                        (DateTime value) =>
                            setStateDialog(() => firstDue = value),
                      ),
                    ],
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Default payment account',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Choose when paying'),
                        ),
                        ...accounts
                            .where(
                              (FinancialAccount a) =>
                                  a.isActive &&
                                  a.archivedAt == null &&
                                  a.accountType != 'credit_card',
                            )
                            .map(
                              (FinancialAccount a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
                      ],
                      onChanged: (String? value) => accountId = value,
                    ),
                    TextFormField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                    if (loan != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Financial terms and schedule settings stay fixed when editing a loan. Update unpaid installments from the loan details.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        final principalMinor = _parse(principal.text);
        final interestMinor = interest.text.trim().isEmpty
            ? 0
            : _parse(interest.text);
        final repayment = repaymentAmount.text.trim().isEmpty
            ? principalMinor + interestMinor
            : _parse(repaymentAmount.text);
        final installmentsCount = int.parse(count.text);
        if (repayment < installmentsCount) {
          throw StateError(
            'Repayment total must provide at least one centavo per installment.',
          );
        }
        final String frequencyValue = frequency == 'custom'
            ? 'custom:${int.parse(customDays.text)}'
            : frequency;
        final perInstallment = installment.text.trim().isEmpty
            ? repayment ~/ installmentsCount
            : _parse(installment.text);
        final List<LoanInstallmentPlan> schedule =
            LoanScheduleCalculator.generate(
              firstDueDate: firstDue,
              frequency: frequencyValue,
              count: installmentsCount,
              totalMinorUnits: repayment,
              installmentAmountMinorUnits: perInstallment,
            );
        final paid = loan == null
            ? 0
            : loan.totalRepaymentMinorUnits - loan.remainingBalanceMinorUnits;
        final dueRemaining = loan == null
            ? repayment
            : (repayment - paid).clamp(0, repayment);
        final bps = ((double.tryParse(rate.text) ?? 0) * 100).round();
        if (loan == null) {
          final id = await repository.createLoan(
            CreateLoanInput(
              name: name.text.trim(),
              providerName: provider.text.trim(),
              principalMinorUnits: principalMinor,
              remainingBalanceMinorUnits: repayment,
              totalRepaymentMinorUnits: repayment,
              interestRateBasisPoints: bps,
              totalInterestMinorUnits: interestMinor,
              openedAt: opened,
              endDate: schedule.last.dueDate,
              durationMonths: int.tryParse(duration.text),
              paymentFrequency: frequencyValue,
              installmentAmountMinorUnits: perInstallment,
              totalInstallments: installmentsCount,
              paymentAccountId: accountId,
              categoryId: categoryId,
              notes: notes.text.trim(),
            ),
          );
          for (final LoanInstallmentPlan plan in schedule) {
            await repository.createInstallment(
              CreateInstallmentInput(
                loanId: id,
                installmentNumber: plan.number,
                dueDate: plan.dueDate,
                scheduledAmountMinorUnits: plan.amountMinorUnits,
                paymentAccountId: accountId,
              ),
            );
          }
        } else {
          await repository.updateLoan(
            UpdateLoanInput(
              loanId: loan.id,
              name: name.text.trim(),
              providerName: provider.text.trim(),
              principalMinorUnits: principalMinor,
              remainingBalanceMinorUnits: dueRemaining,
              totalRepaymentMinorUnits: repayment,
              interestRateBasisPoints: bps,
              totalInterestMinorUnits: interestMinor,
              openedAt: opened,
              endDate: loan.endDate,
              durationMonths: int.tryParse(duration.text),
              paymentFrequency: frequencyValue,
              installmentAmountMinorUnits: perInstallment,
              totalInstallments: installmentsCount,
              paymentAccountId: accountId,
              categoryId: categoryId,
              notes: notes.text.trim(),
            ),
          );
        }
      } catch (error) {
        _toast('Could not save loan: $error');
      }
    }
    for (final controller in <TextEditingController>[
      name,
      provider,
      principal,
      interest,
      repaymentAmount,
      rate,
      installment,
      count,
      duration,
      customDays,
      notes,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _showDetails(
    LoanEntry loan,
    List<LoanInstallmentEntry> installments,
    List<FinancialAccount> accounts,
    List<FinancialTransactionView> transactions,
    List<LoanPaymentEntry> loanPayments,
    String dateFormat,
  ) async {
    String filter = 'all';
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final today = DateTime.now();
          final visible = installments.where((LoanInstallmentEntry item) {
            final bool overdue =
                item.status != 'settled' &&
                item.scheduledMinorUnits > item.paidMinorUnits &&
                _beforeToday(item.dueDate, today);
            return switch (filter) {
              'upcoming' =>
                !overdue &&
                    item.paidMinorUnits == 0 &&
                    !_beforeToday(item.dueDate, today),
              'unpaid' => item.paidMinorUnits == 0 && item.status != 'settled',
              'partial' => item.paidMinorUnits > 0 && item.status == 'partial',
              'overdue' => overdue,
              'paid' => item.status == 'paid' || item.status == 'settled',
              _ => true,
            };
          }).toList();
          final paidCount = installments
              .where(
                (LoanInstallmentEntry item) =>
                    item.status == 'paid' || item.status == 'settled',
              )
              .length;
          final totalPaid = installments.fold<int>(
            0,
            (int n, LoanInstallmentEntry item) => n + item.paidMinorUnits,
          );
          final history =
              loanPayments
                  .where((LoanPaymentEntry item) => item.loanId == loan.id)
                  .toList()
                ..sort(
                  (LoanPaymentEntry a, LoanPaymentEntry b) =>
                      b.paidAt.compareTo(a.paidAt),
                );
          return AlertDialog(
            title: Text(loan.name),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${loan.providerName} · ${_statusLabel(LoanStatusCalculator.status(loan, installments, today))}',
                  ),
                  if (loan.notes != null && loan.notes!.isNotEmpty)
                    Text('Notes and balance adjustments: ${loan.notes}'),
                  Text(
                    'Principal ${Money(loan.principalMinorUnits, currencyCode: loan.currencyCode).format()} · Repayment ${Money(loan.totalRepaymentMinorUnits, currencyCode: loan.currencyCode).format()}',
                  ),
                  Text(
                    'Paid ${Money(totalPaid, currencyCode: loan.currencyCode).format()} · Outstanding ${Money(loan.remainingBalanceMinorUnits, currencyCode: loan.currencyCode).format()}',
                  ),
                  LinearProgressIndicator(
                    value: installments.isEmpty
                        ? 0
                        : paidCount / installments.length,
                  ),
                  Text(
                    '$paidCount of ${installments.length} installments completed',
                  ),
                  DropdownButton<String>(
                    value: filter,
                    items:
                        const <String>[
                              'all',
                              'upcoming',
                              'unpaid',
                              'partial',
                              'overdue',
                              'paid',
                            ]
                            .map(
                              (String v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  v == 'partial'
                                      ? 'Partially paid'
                                      : '${v[0].toUpperCase()}${v.substring(1)}',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (String? v) =>
                        setDialogState(() => filter = v ?? 'all'),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        ...visible.map(
                          (LoanInstallmentEntry item) => _InstallmentTile(
                            loan: loan,
                            installment: item,
                            accounts: accounts,
                            dateFormat: dateFormat,
                            onPay: () => _recordPayment(loan, item, accounts),
                            onEdit: () =>
                                _editInstallment(loan, item, accounts),
                            onRemove: () => _removeInstallment(item),
                          ),
                        ),
                        if (history.isNotEmpty) ...<Widget>[
                          const Divider(),
                          Text(
                            'Payment history',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ...history.map((LoanPaymentEntry item) {
                            final FinancialTransactionView? transaction =
                                item.transactionId == null
                                ? null
                                : transactions
                                      .where(
                                        (FinancialTransactionView row) =>
                                            row.id == item.transactionId,
                                      )
                                      .firstOrNull;
                            final LoanInstallmentEntry? installment =
                                item.installmentId == null
                                ? null
                                : installments
                                      .where(
                                        (LoanInstallmentEntry row) =>
                                            row.id == item.installmentId,
                                      )
                                      .firstOrNull;
                            final FinancialAccount? account =
                                item.accountId == null
                                ? null
                                : accounts
                                      .where(
                                        (FinancialAccount row) =>
                                            row.id == item.accountId,
                                      )
                                      .firstOrNull;
                            return ListTile(
                              dense: true,
                              title: Text(
                                'Installment ${installment?.installmentNumber ?? '—'} · ${Money(item.amountMinorUnits, currencyCode: loan.currencyCode).format()} · ${item.status == 'confirmed' ? 'Recorded' : 'Reversed'}',
                              ),
                              subtitle: Text(
                                '${DateFormat(dateFormat).format(item.paidAt)} · ${account?.name ?? 'No wallet deduction'}${item.notes == null ? '' : ' · ${item.notes}'}',
                              ),
                              trailing: item.status == 'confirmed'
                                  ? IconButton(
                                      tooltip: 'Reverse payment',
                                      icon: const Icon(Icons.undo),
                                      onPressed: () => transaction == null
                                          ? _reverseUnaccountedPayment(item)
                                          : _reversePayment(transaction),
                                    )
                                  : null,
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () => _addInstallment(loan, installments, accounts),
                icon: const Icon(Icons.add),
                label: const Text('Add installment'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _recordPayment(
    LoanEntry loan,
    LoanInstallmentEntry installment,
    List<FinancialAccount> accounts,
  ) async {
    final amount = TextEditingController(
      text:
          ((installment.scheduledMinorUnits - installment.paidMinorUnits) / 100)
              .toStringAsFixed(2),
    );
    final notes = TextEditingController();
    final available = accounts
        .where(
          (FinancialAccount a) =>
              a.isActive &&
              a.archivedAt == null &&
              a.accountType != 'credit_card' &&
              a.currencyCode == loan.currencyCode,
        )
        .toList();
    String? accountId =
        installment.paymentAccountId ??
        loan.paymentAccountId ??
        (available.isEmpty ? null : available.first.id);
    DateTime date = DateTime.now();
    final form = GlobalKey<FormState>();
    final bool? save = await _showDialogAndWaitForExit<bool>(
      (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: const Text('Confirm installment payment'),
          scrollable: true,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${loan.name} · Installment ${installment.installmentNumber}',
                ),
                Text(
                  'Scheduled ${Money(installment.scheduledMinorUnits, currencyCode: loan.currencyCode).format()} · Remaining ${Money(installment.scheduledMinorUnits - installment.paidMinorUnits, currencyCode: loan.currencyCode).format()}',
                ),
                TextFormField(
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Actual amount paid (PHP)',
                  ),
                  validator: _moneyRequired,
                ),
                DropdownButtonFormField<String?>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Wallet treatment',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Record payment only · no wallet deduction'),
                    ),
                    ...available.map(
                      (FinancialAccount a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} · ${Money(a.currentBalanceMinorUnits, currencyCode: a.currencyCode).format()}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (String? value) => accountId = value,
                ),
                _dateButton(
                  context,
                  'Payment date',
                  date,
                  (DateTime value) => update(() => date = value),
                ),
                TextFormField(
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                Text(
                  accountId == null
                      ? 'This records repayment without changing any wallet balance.'
                      : 'Confirming deducts the actual payment from the selected wallet account.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Confirm payment'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .confirmLoanPayment(
              LoanPaymentInput(
                loanId: loan.id,
                installmentId: installment.id,
                accountId: accountId,
                amountMinorUnits: _parse(amount.text),
                paidAt: date,
                idempotencyKey: _uuid.v4(),
                notes: notes.text.trim(),
              ),
            );
      } catch (error) {
        _toast('Could not record payment: $error');
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Future<void> _reversePayment(FinancialTransactionView transaction) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reverse this payment?'),
        content: Text(
          'This preserves the original record, adds a reversal, and restores ${Money(transaction.amountMinorUnits, currencyCode: transaction.currencyCode).format()} to the wallet account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep payment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse payment'),
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
              notes: 'Loan payment correction',
            );
      } catch (error) {
        _toast('Could not reverse payment: $error');
      }
    }
  }

  Future<void> _reverseUnaccountedPayment(LoanPaymentEntry payment) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reverse recorded payment?'),
        content: const Text(
          'This preserves the payment history and restores the unpaid installment amount. No wallet balance changes because this payment was recorded without a wallet deduction.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep payment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse payment'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .reverseUnaccountedLoanPayment(payment.id);
      } catch (error) {
        _toast('Could not reverse payment: $error');
      }
    }
  }

  Future<void> _addInstallment(
    LoanEntry loan,
    List<LoanInstallmentEntry> installments,
    List<FinancialAccount> accounts,
  ) async {
    final nextNumber =
        installments.fold<int>(
          0,
          (int max, LoanInstallmentEntry item) =>
              item.installmentNumber > max ? item.installmentNumber : max,
        ) +
        1;
    await _installmentForm(loan, null, nextNumber, accounts);
  }

  Future<void> _editInstallment(
    LoanEntry loan,
    LoanInstallmentEntry item,
    List<FinancialAccount> accounts,
  ) => _installmentForm(loan, item, item.installmentNumber, accounts);

  Future<void> _installmentForm(
    LoanEntry loan,
    LoanInstallmentEntry? item,
    int number,
    List<FinancialAccount> accounts,
  ) async {
    final amount = TextEditingController(
      text: item == null
          ? ''
          : (item.scheduledMinorUnits / 100).toStringAsFixed(2),
    );
    final notes = TextEditingController(text: item?.notes ?? '');
    DateTime date = item?.dueDate ?? loan.nextDueDate ?? DateTime.now();
    String? accountId = item?.paymentAccountId ?? loan.paymentAccountId;
    final form = GlobalKey<FormState>();
    final bool? save = await _showDialogAndWaitForExit<bool>(
      (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: Text(
            item == null
                ? 'Add installment $number'
                : 'Edit installment ${item.installmentNumber}',
          ),
          scrollable: true,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Scheduled amount (PHP)',
                  ),
                  validator: _moneyRequired,
                ),
                _dateButton(
                  context,
                  'Due date',
                  date,
                  (DateTime value) => update(() => date = value),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Preferred account',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Choose when paying'),
                    ),
                    ...accounts
                        .where(
                          (FinancialAccount a) =>
                              a.isActive &&
                              a.archivedAt == null &&
                              a.accountType != 'credit_card',
                        )
                        .map(
                          (FinancialAccount a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                  ],
                  onChanged: (String? value) => accountId = value,
                ),
                TextFormField(
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
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
    if (save == true) {
      try {
        final repo = ref.read(financialRepositoryProvider);
        if (item == null) {
          await repo.createInstallment(
            CreateInstallmentInput(
              loanId: loan.id,
              installmentNumber: number,
              dueDate: date,
              scheduledAmountMinorUnits: _parse(amount.text),
              paymentAccountId: accountId,
              notes: notes.text.trim(),
            ),
          );
        } else {
          await repo.updateInstallment(
            UpdateInstallmentInput(
              installmentId: item.id,
              dueDate: date,
              scheduledAmountMinorUnits: _parse(amount.text),
              paymentAccountId: accountId,
              notes: notes.text.trim(),
            ),
          );
        }
      } catch (error) {
        _toast('Could not save installment: $error');
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Future<void> _removeInstallment(LoanInstallmentEntry item) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove unpaid installment?'),
        content: const Text(
          'Only installments with no recorded payments can be removed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ref.read(financialRepositoryProvider).deleteInstallment(item.id);
      } catch (error) {
        _toast('Could not remove installment: $error');
      }
    }
  }

  Future<void> _loanAction(
    String action,
    LoanEntry loan,
    List<FinancialAccount> accounts,
  ) async {
    final repo = ref.read(financialRepositoryProvider);
    try {
      switch (action) {
        case 'edit':
          await _editLoan(loan, accounts);
        case 'disbursement':
          await _recordDisbursement(loan, accounts);
        case 'adjust':
          await _adjustLoanBalance(loan);
        case 'cancel':
          final yes = await _confirm(
            'Cancel this loan?',
            'The loan and its payment history will remain available.',
          );
          if (yes) await repo.setLoanStatus(loan.id, 'cancelled');
        case 'archive':
          final yes = await _confirm(
            'Archive this loan?',
            'Installments and payment history will be preserved.',
          );
          if (yes) await repo.archiveLoan(loan.id);
        case 'reopen':
          await repo.reopenLoan(loan.id);
        case 'remove':
          final yes = await _confirm(
            'Remove this loan?',
            'Loans with payment history cannot be removed.',
          );
          if (yes) await repo.deleteLoan(loan.id);
      }
    } catch (error) {
      _toast('Could not $action loan: $error');
    }
  }

  Future<void> _recordDisbursement(
    LoanEntry loan,
    List<FinancialAccount> accounts,
  ) async {
    final available = accounts
        .where(
          (FinancialAccount item) =>
              item.isActive &&
              item.archivedAt == null &&
              item.accountType != 'credit_card' &&
              item.currencyCode == loan.currencyCode,
        )
        .toList();
    final amount = TextEditingController();
    final notes = TextEditingController();
    String? accountId = available.isEmpty ? null : available.first.id;
    DateTime receivedAt = DateTime.now();
    final form = GlobalKey<FormState>();
    final bool? confirmed = await _showDialogAndWaitForExit<bool>(
      (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: const Text('Record loan funds received'),
          scrollable: true,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(loan.name),
                TextFormField(
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount received (PHP)',
                  ),
                  validator: _moneyRequired,
                ),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Deposit account',
                  ),
                  items: available
                      .map(
                        (FinancialAccount item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) => accountId = value,
                  validator: (String? value) =>
                      value == null ? 'Choose an account' : null,
                ),
                _dateButton(
                  context,
                  'Date received',
                  receivedAt,
                  (DateTime value) => update(() => receivedAt = value),
                ),
                TextFormField(
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const Text(
                  'This credits the wallet account and is recorded separately from income and the loan obligation.',
                ),
              ],
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
              child: const Text('Record funds'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && accountId != null) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .recordLoanDisbursement(
              LoanDisbursementInput(
                loanId: loan.id,
                accountId: accountId!,
                amountMinorUnits: _parse(amount.text),
                receivedAt: receivedAt,
                idempotencyKey: _uuid.v4(),
                notes: notes.text.trim(),
              ),
            );
      } catch (error) {
        _toast('Could not record funds: $error');
      }
    }
    amount.dispose();
    notes.dispose();
  }

  Future<void> _adjustLoanBalance(LoanEntry loan) async {
    final amount = TextEditingController(
      text: (loan.remainingBalanceMinorUnits / 100).toStringAsFixed(2),
    );
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final bool? confirmed = await _showDialogAndWaitForExit<bool>(
      (BuildContext dialogContext) => AlertDialog(
        title: const Text('Adjust lender balance'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Recorded obligation: ${Money(loan.remainingBalanceMinorUnits, currencyCode: loan.currencyCode).format()}',
              ),
              TextFormField(
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Actual remaining balance (PHP)',
                ),
                validator: _moneyNonNegativeRequired,
              ),
              TextFormField(
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                ),
                validator: _required,
              ),
              const Text(
                'This stores a balance adjustment and audit note. It does not move wallet money or create a repayment transaction.',
              ),
            ],
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
            child: const Text('Save adjustment'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(financialRepositoryProvider)
            .adjustLoanBalance(
              AdjustLoanBalanceInput(
                loanId: loan.id,
                remainingBalanceMinorUnits: _parse(amount.text),
                adjustedAt: DateTime.now(),
                reason: reason.text.trim(),
              ),
            );
      } catch (error) {
        _toast('Could not adjust lender balance: $error');
      }
    }
    amount.dispose();
    reason.dispose();
  }

  Future<bool> _confirm(String title, String message) async =>
      await _showDialogAndWaitForExit<bool>(
        (BuildContext context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Widget _dateButton(
    BuildContext context,
    String label,
    DateTime date,
    ValueChanged<DateTime> onChanged,
  ) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(DateFormat.yMMMd().format(date)),
    trailing: const Icon(Icons.calendar_today_outlined),
    onTap: () async {
      final DateTime? value = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (value != null && context.mounted) onChanged(value);
    },
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  int _parse(String value) => parseMinorUnits(value)!;

  String? _moneyRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final int? amount = parseMinorUnits(value);
    if (amount == null) return 'Enter a valid PHP amount';
    if (amount <= 0) return 'Enter an amount greater than zero';
    return null;
  }

  String? _moneyOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final int? amount = parseMinorUnits(value);
    if (amount == null) return 'Enter a valid PHP amount';
    if (amount < 0) return 'Cannot be negative';
    return null;
  }

  String? _repaymentValidator(String? value) =>
      value == null || value.trim().isEmpty ? null : _moneyRequired(value);

  String? _moneyNonNegativeRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final int? amount = parseMinorUnits(value);
    if (amount == null) return 'Enter a valid PHP amount';
    if (amount < 0) return 'Cannot be negative';
    return null;
  }

  String? _decimalOptional(String? value) =>
      value == null ||
          value.trim().isEmpty ||
          (double.tryParse(value) != null && double.parse(value) >= 0)
      ? null
      : 'Enter a valid rate';
  String? _positiveInt(String? value) =>
      int.tryParse(value ?? '') == null || int.parse(value!) < 1
      ? 'Enter at least 1'
      : null;
  String? _intOptional(String? value) =>
      value == null ||
          value.trim().isEmpty ||
          (int.tryParse(value) != null && int.parse(value) > 0)
      ? null
      : 'Enter a positive number';
  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({
    required this.loan,
    required this.installment,
    required this.accounts,
    required this.dateFormat,
    required this.onPay,
    required this.onEdit,
    required this.onRemove,
  });
  final LoanEntry loan;
  final LoanInstallmentEntry installment;
  final List<FinancialAccount> accounts;
  final String dateFormat;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final remaining = installment.status == 'settled'
        ? 0
        : installment.scheduledMinorUnits - installment.paidMinorUnits;
    final bool overdue =
        remaining > 0 &&
        installment.status != 'settled' &&
        DateTime(
          installment.dueDate.year,
          installment.dueDate.month,
          installment.dueDate.day,
        ).isBefore(
          DateTime.now().copyWith(
            hour: 0,
            minute: 0,
            second: 0,
            millisecond: 0,
            microsecond: 0,
          ),
        );
    return Card(
      child: ListTile(
        title: Text(
          'Installment ${installment.installmentNumber} · ${Money(remaining, currencyCode: loan.currencyCode).format()} remaining',
        ),
        subtitle: Text(
          'Scheduled ${Money(installment.scheduledMinorUnits, currencyCode: loan.currencyCode).format()} · Due ${DateFormat(dateFormat).format(installment.dueDate)} · ${overdue ? 'Overdue' : installment.status}${installment.paidMinorUnits > 0 ? ' · Paid ${Money(installment.paidMinorUnits, currencyCode: loan.currencyCode).format()}' : ''}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 0,
          children: <Widget>[
            if (remaining > 0 &&
                loan.status != 'cancelled' &&
                installment.status != 'settled')
              IconButton(
                tooltip: 'Record payment',
                onPressed: onPay,
                icon: const Icon(Icons.payments_outlined),
              ),
            if (installment.paidMinorUnits == 0 &&
                installment.status != 'settled')
              PopupMenuButton<String>(
                onSelected: (String value) =>
                    value == 'edit' ? onEdit() : onRemove(),
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(status, style: const TextStyle(fontSize: 11)),
  );
}
