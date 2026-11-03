import 'dart:io';

import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/features/dashboard/domain/services/financial_analytics.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/reports/domain/report_exporter.dart';
import 'package:bill_tracker/features/settings/presentation/providers/user_preferences_provider.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/wallets/domain/services/wallet_calculator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _ReportPeriod { day, week, month, quarter, year, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportPeriod _period = _ReportPeriod.month;
  DateTimeRange? _customRange;
  String? _accountId;
  String? _category;
  String? _type;

  @override
  Widget build(BuildContext context) {
    final DateTimeRange range = _range(DateTime.now());
    final String currency =
        ref.watch(userPreferencesProvider).asData?.value.currencyCode ?? 'PHP';
    final DashboardDateWindow queryWindow = DashboardDateWindow(
      start: range.start,
      endExclusive: range.end,
      previousStart: range.start,
      previousEndExclusive: range.start,
      currencyCode: currency,
    );
    final AsyncValue<List<FinancialTransactionView>> rowsValue = ref.watch(
      dashboardTransactionsProvider(queryWindow),
    );
    final List<FinancialAccount> accounts =
        ref.watch(walletManagementAccountsProvider).asData?.value ??
        const <FinancialAccount>[];
    final AsyncValue<List<FinancialTransactionView>> balanceHistoryRows =
        _accountId == null
        ? const AsyncData<List<FinancialTransactionView>>(
            <FinancialTransactionView>[],
          )
        : ref.watch(accountTransactionsProvider(_accountId!));
    final Set<String> categories = <String>{
      for (final CategoryEntry category
          in ref.watch(expenseCategoriesProvider).asData?.value ??
              const <CategoryEntry>[])
        category.name,
      for (final CategoryEntry category
          in ref.watch(incomeCategoriesProvider).asData?.value ??
              const <CategoryEntry>[])
        category.name,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Financial reports')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: <Widget>[
                Text(
                  'Confirmed activity only',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Expected income, projected balances, and planned allocations are excluded from actual totals.',
                ),
                const SizedBox(height: AppSpacing.medium),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Column(
                      children: <Widget>[
                        DropdownButtonFormField<_ReportPeriod>(
                          initialValue: _period,
                          decoration: const InputDecoration(
                            labelText: 'Period',
                          ),
                          items: const <DropdownMenuItem<_ReportPeriod>>[
                            DropdownMenuItem(
                              value: _ReportPeriod.day,
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: _ReportPeriod.week,
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: _ReportPeriod.month,
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: _ReportPeriod.quarter,
                              child: Text('Quarterly'),
                            ),
                            DropdownMenuItem(
                              value: _ReportPeriod.year,
                              child: Text('Yearly'),
                            ),
                            DropdownMenuItem(
                              value: _ReportPeriod.custom,
                              child: Text('Custom date range'),
                            ),
                          ],
                          onChanged: _changePeriod,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end.subtract(const Duration(days: 1)))}',
                        ),
                        const SizedBox(height: AppSpacing.small),
                        DropdownButtonFormField<String?>(
                          initialValue: _accountId,
                          decoration: const InputDecoration(
                            labelText: 'Account',
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All accounts'),
                            ),
                            for (final FinancialAccount account in accounts)
                              DropdownMenuItem(
                                value: account.id,
                                child: Text(account.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _accountId = value),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        DropdownButtonFormField<String?>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All categories'),
                            ),
                            for (final String value
                                in categories.toList()..sort())
                              DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _category = value),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        DropdownButtonFormField<String?>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Transaction type',
                          ),
                          items: const <DropdownMenuItem<String?>>[
                            DropdownMenuItem(
                              value: null,
                              child: Text('All activity'),
                            ),
                            DropdownMenuItem(
                              value: 'income',
                              child: Text('Income'),
                            ),
                            DropdownMenuItem(
                              value: 'expense',
                              child: Text('Expense'),
                            ),
                            DropdownMenuItem(
                              value: 'bill_payment',
                              child: Text('Bill payment'),
                            ),
                            DropdownMenuItem(
                              value: 'loan_payment',
                              child: Text('Loan repayment'),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card_purchase',
                              child: Text('Credit card purchase'),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card_payment',
                              child: Text('Credit card payment'),
                            ),
                            DropdownMenuItem(
                              value: 'savings_contribution',
                              child: Text('Savings contribution'),
                            ),
                            DropdownMenuItem(
                              value: 'transfer',
                              child: Text('Transfer'),
                            ),
                          ],
                          onChanged: (value) => setState(() => _type = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                rowsValue.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Text('Report could not be loaded: $error'),
                  data: (rows) {
                    final ReportData report = ReportData(
                      filters: ReportFilters(
                        start: range.start,
                        endExclusive: range.end,
                        currencyCode: currency,
                        accountId: _accountId,
                        category: _category,
                        transactionType: _type,
                      ),
                      rows: rows,
                    );
                    final List<FinancialTransactionView> filtered =
                        report.filteredRows;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.medium),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Income vs expenses',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.small),
                                SizedBox(
                                  height: 150,
                                  child: BarChart(
                                    BarChartData(
                                      maxY:
                                          <int>[
                                                report.incomeMinorUnits,
                                                report.expenseMinorUnits,
                                              ]
                                              .reduce((a, b) => a > b ? a : b)
                                              .toDouble()
                                              .clamp(1, double.infinity),
                                      barGroups: <BarChartGroupData>[
                                        BarChartGroupData(
                                          x: 0,
                                          barRods: <BarChartRodData>[
                                            BarChartRodData(
                                              toY: report.incomeMinorUnits
                                                  .toDouble(),
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                        BarChartGroupData(
                                          x: 1,
                                          barRods: <BarChartRodData>[
                                            BarChartRodData(
                                              toY: report.expenseMinorUnits
                                                  .toDouble(),
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ],
                                        ),
                                      ],
                                      titlesData: const FlTitlesData(
                                        show: false,
                                      ),
                                      borderData: FlBorderData(show: false),
                                      gridData: const FlGridData(show: false),
                                    ),
                                  ),
                                ),
                                _total(
                                  'Income',
                                  report.incomeMinorUnits,
                                  currency,
                                ),
                                _total(
                                  'Expenses',
                                  report.expenseMinorUnits,
                                  currency,
                                ),
                                _total(
                                  'Net cash flow',
                                  report.incomeMinorUnits -
                                      report.expenseMinorUnits,
                                  currency,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (report.expensesByCategory.isNotEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.medium),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Spending by category',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  SizedBox(
                                    height: 190,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 35,
                                        sections: <PieChartSectionData>[
                                          for (final MapEntry<String, int> entry
                                              in report
                                                  .expensesByCategory
                                                  .entries)
                                            PieChartSectionData(
                                              value: entry.value.toDouble(),
                                              title: entry.key,
                                              radius: 70,
                                              titleStyle: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  for (final MapEntry<String, int> entry
                                      in report.expensesByCategory.entries)
                                    _total(entry.key, entry.value, currency),
                                ],
                              ),
                            ),
                          ),
                        if (_accountId != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.small),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.medium),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Account balance history',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  balanceHistoryRows.when(
                                    loading: () =>
                                        const LinearProgressIndicator(),
                                    error: (error, _) => Text(
                                      'Balance history unavailable: $error',
                                    ),
                                    data: (historyRows) {
                                      final FinancialAccount? account = accounts
                                          .where(
                                            (item) => item.id == _accountId,
                                          )
                                          .firstOrNull;
                                      if (account == null) {
                                        return const Text(
                                          'Choose an active account to view its ledger history.',
                                        );
                                      }
                                      final List<BalanceHistoryPoint> points =
                                          WalletCalculator.balanceHistory(
                                            account,
                                            historyRows,
                                            range: BalanceHistoryRange.custom,
                                            now: range.end.subtract(
                                              const Duration(days: 1),
                                            ),
                                            customStart: range.start,
                                            customEnd: range.end.subtract(
                                              const Duration(days: 1),
                                            ),
                                          );
                                      if (points.isEmpty) {
                                        return const Text(
                                          'No account activity in this period.',
                                        );
                                      }
                                      return Column(
                                        children: <Widget>[
                                          for (final BalanceHistoryPoint point
                                              in points)
                                            ListTile(
                                              dense: true,
                                              title: Text(
                                                DateFormat.yMMMd().format(
                                                  point.date,
                                                ),
                                              ),
                                              trailing: Text(
                                                Money(
                                                  point.balanceMinorUnits,
                                                  currencyCode:
                                                      account.currencyCode,
                                                ).format(),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.small),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: () => _export(report, 'csv'),
                              icon: const Icon(Icons.table_rows_outlined),
                              label: const Text('CSV'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _export(report, 'xlsx'),
                              icon: const Icon(Icons.grid_on_outlined),
                              label: const Text('Excel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _export(report, 'pdf'),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('PDF'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.small),
                        if (filtered.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No activity matches these filters.',
                                ),
                              ),
                            ),
                          )
                        else
                          Card(
                            child: Column(
                              children: <Widget>[
                                for (final FinancialTransactionView row
                                    in filtered.take(100))
                                  ListTile(
                                    dense: true,
                                    title: Text(row.title),
                                    subtitle: Text(
                                      '${row.type.replaceAll('_', ' ')} · ${DateFormat.yMMMd().format(row.occurredAt.toLocal())}${row.category == null ? '' : ' · ${row.category}'}',
                                    ),
                                    trailing: Text(
                                      Money(
                                        row.amountMinorUnits,
                                        currencyCode: row.currencyCode,
                                      ).format(),
                                    ),
                                  ),
                                if (filtered.length > 100)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'Showing the first 100 rows. Exports include all matches.',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DateTimeRange _range(DateTime today) {
    final DateTime startToday = DateTime(today.year, today.month, today.day);
    if (_period == _ReportPeriod.custom && _customRange != null) {
      return DateTimeRange(
        start: _customRange!.start,
        end: _customRange!.end.add(const Duration(days: 1)),
      );
    }
    final DateTime start = switch (_period) {
      _ReportPeriod.day => startToday,
      _ReportPeriod.week => startToday.subtract(
        Duration(days: today.weekday - 1),
      ),
      _ReportPeriod.quarter => DateTime(
        today.year,
        ((today.month - 1) ~/ 3) * 3 + 1,
      ),
      _ReportPeriod.year => DateTime(today.year),
      _ => DateTime(today.year, today.month),
    };
    return DateTimeRange(
      start: start,
      end: startToday.add(const Duration(days: 1)),
    );
  }

  Future<void> _changePeriod(_ReportPeriod? period) async {
    if (period == null) return;
    if (period == _ReportPeriod.custom) {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _customRange,
      );
      if (!mounted || picked == null) return;
      setState(() {
        _customRange = picked;
        _period = period;
      });
    } else {
      setState(() => _period = period);
    }
  }

  Widget _total(String label, int amount, String currency) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(Money(amount, currencyCode: currency).format()),
      ],
    ),
  );

  Future<void> _export(ReportData report, String format) async {
    try {
      final Directory directory = await getTemporaryDirectory();
      final String timestamp = DateFormat(
        'yyyyMMdd_HHmmss',
      ).format(DateTime.now());
      final String path =
          '${directory.path}/myfinance_report_$timestamp.$format';
      final File file = File(path);
      if (format == 'csv') {
        await file.writeAsString(ReportExporter.csv(report), flush: true);
      } else if (format == 'xlsx') {
        await file.writeAsBytes(ReportExporter.excel(report), flush: true);
      } else {
        await file.writeAsBytes(await ReportExporter.pdf(report), flush: true);
      }
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path)],
          text: 'MyFinance report · ${report.filters.currencyCode}',
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report export failed: $error')));
      }
    }
  }
}
