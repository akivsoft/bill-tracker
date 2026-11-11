import 'dart:math' as math;

import 'package:bill_tracker/app/router/route_names.dart';
import 'package:bill_tracker/app/theme/app_spacing.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:bill_tracker/features/bills/domain/services/bill_schedule_calculator.dart';
import 'package:bill_tracker/features/dashboard/domain/services/financial_analytics.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/financial_overview_providers.dart';
import 'package:bill_tracker/features/dashboard/presentation/providers/dashboard_section_state_provider.dart';
import 'package:bill_tracker/features/planner/domain/services/payday_schedule_calculator.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_records.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/features/transactions/domain/services/financial_calculator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _Period { day, week, month, quarter, year, custom }

class FinancialAnalyticsPanel extends ConsumerStatefulWidget {
  const FinancialAnalyticsPanel({required this.currencyCode, super.key});

  final String currencyCode;

  @override
  ConsumerState<FinancialAnalyticsPanel> createState() =>
      _FinancialAnalyticsPanelState();
}

class _FinancialAnalyticsPanelState
    extends ConsumerState<FinancialAnalyticsPanel> {
  _Period _period = _Period.month;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final DashboardDateWindow window = _window(
      DateTime.now(),
      widget.currencyCode,
    );
    final transactions = ref.watch(dashboardTransactionsProvider(window));
    final accounts =
        ref.watch(walletManagementAccountsProvider).asData?.value ??
        const <FinancialAccount>[];
    final incomes =
        ref.watch(incomeOverviewProvider).asData?.value ??
        const <IncomeEntry>[];
    final bills =
        ref.watch(billsOverviewProvider).asData?.value ?? const <BillEntry>[];
    final billPayments =
        ref.watch(billPaymentsOverviewProvider).asData?.value ??
        const <BillPaymentEntry>[];
    final loans =
        ref.watch(loansOverviewProvider).asData?.value ?? const <LoanEntry>[];
    final installments =
        ref.watch(installmentsOverviewProvider).asData?.value ??
        const <LoanInstallmentEntry>[];
    final loanPayments =
        ref.watch(loanPaymentsOverviewProvider).asData?.value ??
        const <LoanPaymentEntry>[];
    final goals =
        ref.watch(savingsGoalsOverviewProvider).asData?.value ??
        const <SavingsGoalEntry>[];
    final paydays =
        ref.watch(paydaySchedulesProvider).asData?.value ??
        const <PaydayScheduleEntry>[];
    final List<AllocationEntry> allocations = <AllocationEntry>[
      for (final PaydayScheduleEntry payday in paydays.where(
        (item) => item.currencyCode == widget.currencyCode,
      ))
        ...ref.watch(paydayAllocationsProvider(payday.id)).asData?.value ??
            const <AllocationEntry>[],
    ];
    final int expectedIncome = incomes
        .where(
          (IncomeEntry item) =>
              item.status == 'expected' &&
              _inRange(item.expectedDate, window.start, window.endExclusive) &&
              item.currencyCode == widget.currencyCode,
        )
        .fold<int>(
          0,
          (int sum, IncomeEntry item) => sum + item.amountMinorUnits,
        );
    final int outstandingLoans = loans
        .where(
          (LoanEntry item) =>
              item.currencyCode == widget.currencyCode &&
              item.archivedAt == null &&
              item.status != 'cancelled',
        )
        .fold<int>(
          0,
          (int sum, LoanEntry item) => sum + item.remainingBalanceMinorUnits,
        );
    final int contractualLoanTotal = loans
        .where(
          (LoanEntry item) =>
              item.currencyCode == widget.currencyCode &&
              item.archivedAt == null &&
              item.status != 'cancelled',
        )
        .fold<int>(
          0,
          (int sum, LoanEntry item) => sum + item.totalRepaymentMinorUnits,
        );
    final int repaid = loanPayments
        .where(
          (LoanPaymentEntry item) =>
              item.status == 'confirmed' &&
              loans.any((LoanEntry loan) => loan.id == item.loanId),
        )
        .fold<int>(
          0,
          (int sum, LoanPaymentEntry item) => sum + item.amountMinorUnits,
        );
    final int totalCardDebt = accounts
        .where(
          (FinancialAccount item) =>
              item.isActive &&
              item.accountType == 'credit_card' &&
              item.currencyCode == widget.currencyCode,
        )
        .fold<int>(
          0,
          (int sum, FinancialAccount item) =>
              sum + item.outstandingCreditMinorUnits,
        );
    final int totalAvailableCredit = accounts
        .where(
          (FinancialAccount item) =>
              item.isActive &&
              item.accountType == 'credit_card' &&
              item.currencyCode == widget.currencyCode,
        )
        .fold<int>(
          0,
          (int sum, FinancialAccount item) =>
              sum +
              FinancialCalculator.availableCredit(
                creditLimitMinorUnits: item.creditLimitMinorUnits,
                outstandingMinorUnits: item.outstandingCreditMinorUnits,
              ),
        );
    final int goalTotal = goals
        .where(
          (SavingsGoalEntry item) =>
              item.status == 'active' &&
              item.currencyCode == widget.currencyCode,
        )
        .fold<int>(
          0,
          (int sum, SavingsGoalEntry item) => sum + item.targetAmountMinorUnits,
        );
    final int goalSaved = goals
        .where(
          (SavingsGoalEntry item) =>
              item.status == 'active' &&
              item.currencyCode == widget.currencyCode,
        )
        .fold<int>(
          0,
          (int sum, SavingsGoalEntry item) =>
              sum + item.currentAmountMinorUnits,
        );
    final int plannedAllocations = allocations
        .where(
          (AllocationEntry item) =>
              item.status == 'planned' || item.status == 'partial',
        )
        .fold<int>(
          0,
          (int sum, AllocationEntry item) =>
              sum +
              (item.allocatedAmountMinorUnits - item.fulfilledAmountMinorUnits)
                  .clamp(0, item.allocatedAmountMinorUnits),
        );
    final List<_Obligation> upcoming = _upcomingObligations(
      bills: bills,
      billPayments: billPayments,
      loans: loans,
      installments: installments,
    );
    final String currency = widget.currencyCode;
    final DateTime now = DateTime.now();
    final DateTime horizon = DateTime(now.year, now.month + 3, now.day);
    final List<(PaydayScheduleEntry, DateTime)> nextPaydays =
        <(PaydayScheduleEntry, DateTime)>[
          for (final PaydayScheduleEntry payday in paydays.where(
            (item) => item.isActive && item.currencyCode == widget.currencyCode,
          ))
            if (_nextPayday(payday, now, horizon) case final DateTime date)
              (payday, date),
        ]..sort((a, b) => a.$2.compareTo(b.$2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.small,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Financial overview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    DropdownButton<_Period>(
                      value: _period,
                      items: const <DropdownMenuItem<_Period>>[
                        DropdownMenuItem(
                          value: _Period.day,
                          child: Text('Today'),
                        ),
                        DropdownMenuItem(
                          value: _Period.week,
                          child: Text('Week'),
                        ),
                        DropdownMenuItem(
                          value: _Period.month,
                          child: Text('Month'),
                        ),
                        DropdownMenuItem(
                          value: _Period.quarter,
                          child: Text('Quarter'),
                        ),
                        DropdownMenuItem(
                          value: _Period.year,
                          child: Text('Year'),
                        ),
                        DropdownMenuItem(
                          value: _Period.custom,
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == _Period.custom) {
                          final DateTimeRange? picked =
                              await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDateRange: _customRange,
                              );
                          if (!context.mounted || picked == null) return;
                          setState(() {
                            _customRange = picked;
                            _period = _Period.custom;
                          });
                        } else if (value != null) {
                          setState(() => _period = value);
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  _windowLabel(window),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.medium),
                transactions.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (Object error, StackTrace stack) =>
                      const Text('Financial analytics could not be loaded.'),
                  data: (List<FinancialTransactionView> rows) {
                    final FinancialAnalyticsSummary result =
                        FinancialAnalyticsCalculator.summarize(
                          transactions: rows,
                          window: window,
                        );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Wrap(
                          spacing: AppSpacing.small,
                          runSpacing: AppSpacing.small,
                          children: <Widget>[
                            _metric(
                              context,
                              'Income received',
                              result.incomeMinorUnits,
                              currency,
                              Icons.south_west,
                              onTap: () =>
                                  context.go(RouteNames.moreModule('income')),
                            ),
                            _metric(
                              context,
                              'Confirmed expenses',
                              result.expensesMinorUnits,
                              currency,
                              Icons.north_east,
                              onTap: () =>
                                  context.go(RouteNames.moreModule('expenses')),
                            ),
                            _metric(
                              context,
                              'Net cash flow',
                              result.netCashFlowMinorUnits,
                              currency,
                              Icons.swap_vert,
                            ),
                            _metric(
                              context,
                              'Expected income',
                              expectedIncome,
                              currency,
                              Icons.schedule,
                              caption: 'Not received',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.small),
                        _comparison(context, result, currency),
                        const Divider(height: AppSpacing.large),
                        _sectionTitle(context, 'Income vs expenses'),
                        const SizedBox(height: AppSpacing.small),
                        SizedBox(
                          height: 180,
                          child:
                              result.incomeMinorUnits == 0 &&
                                  result.expensesMinorUnits == 0
                              ? const _ChartEmpty(
                                  message:
                                      'No confirmed income or expenses in this period.',
                                )
                              : _incomeExpenseChart(context, result),
                        ),
                        const Divider(height: AppSpacing.large),
                        _sectionTitle(context, 'Cash flow trend'),
                        const SizedBox(height: AppSpacing.small),
                        SizedBox(
                          height: 200,
                          child: result.trend.isEmpty
                              ? const _ChartEmpty(
                                  message:
                                      'No transaction activity to chart yet.',
                                )
                              : _trendChart(context, result.trend),
                        ),
                        const Divider(height: AppSpacing.large),
                        _sectionTitle(context, 'Expense breakdown'),
                        if (result.expensesByCategory.isEmpty)
                          const _ChartEmpty(
                            message: 'No confirmed spending in this period.',
                          )
                        else ...<Widget>[
                          const SizedBox(height: AppSpacing.small),
                          SizedBox(
                            height: 210,
                            child: _expenseChart(
                              context,
                              result.expensesByCategory,
                            ),
                          ),
                          ..._topCategories(result.expensesByCategory)
                              .take(5)
                              .map(
                                (entry) => ListTile(
                                  dense: true,
                                  title: Text(entry.key),
                                  trailing: Text(
                                    Money(
                                      entry.value,
                                      currencyCode: currency,
                                    ).format(),
                                  ),
                                  onTap: () => context.go(
                                    RouteNames.moreModule('expenses'),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        _analyticsCard(
          context,
          title: 'Account balances',
          subtitle: 'Current balances · credit excluded from available cash',
          trailing: TextButton(
            onPressed: () => context.go(RouteNames.walletsPath),
            child: const Text('Wallets'),
          ),
          child: accounts.isEmpty
              ? const _ChartEmpty(message: 'Add an account to see balances.')
              : SizedBox(
                  height: 185,
                  child: _accountBalancesChart(context, accounts),
                ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = AppSpacing.small;
            final int columns = constraints.maxWidth >= 700 ? 4 : 2;
            final double tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: tileWidth / 148,
              children: <Widget>[
                _metric(
                  context,
                  'Outstanding loans',
                  outstandingLoans,
                  currency,
                  Icons.account_balance,
                  width: tileWidth,
                  onTap: () => context.go(RouteNames.loansPath),
                ),
                _metric(
                  context,
                  'Credit card debt',
                  totalCardDebt,
                  currency,
                  Icons.credit_card,
                  width: tileWidth,
                  onTap: () => context.go(RouteNames.walletsPath),
                  caption:
                      'Available credit ${Money(totalAvailableCredit, currencyCode: currency).format()}',
                ),
                _metric(
                  context,
                  'Savings goals',
                  goalSaved,
                  currency,
                  Icons.savings,
                  width: tileWidth,
                  onTap: () => context.go(RouteNames.moreModule('savings')),
                  caption:
                      'of ${Money(goalTotal, currencyCode: currency).format()}',
                ),
                _metric(
                  context,
                  'Planned allocations',
                  plannedAllocations,
                  currency,
                  Icons.event_note,
                  width: tileWidth,
                  onTap: () => context.go(RouteNames.moreModule('planner')),
                  caption: 'Forecast only',
                ),
              ],
            );
          },
        ),
        _analyticsCard(
          context,
          sectionId: 'loanRepayment',
          collapsedSummary:
              '${Money(repaid, currencyCode: currency).format()} confirmed · ${Money(outstandingLoans, currencyCode: currency).format()} outstanding',
          title: 'Loan repayment progress',
          subtitle: 'Confirmed repayments versus contractual amount',
          trailing: TextButton(
            onPressed: () => context.go(RouteNames.loansPath),
            child: const Text('Loans'),
          ),
          child: contractualLoanTotal == 0
              ? const _ChartEmpty(message: 'No active loan obligations.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LinearProgressIndicator(
                      value: (repaid / contractualLoanTotal).clamp(0.0, 1.0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Money(repaid, currencyCode: currency).format()} confirmed · ${Money(outstandingLoans, currencyCode: currency).format()} outstanding',
                    ),
                  ],
                ),
        ),
        _analyticsCard(
          context,
          sectionId: 'savingsProgress',
          collapsedSummary:
              '${Money(goalSaved, currencyCode: currency).format()} of ${Money(goalTotal, currencyCode: currency).format()} saved',
          title: 'Savings progress',
          subtitle: 'Confirmed goal balances versus targets',
          trailing: TextButton(
            onPressed: () => context.go(RouteNames.moreModule('savings')),
            child: const Text('Savings'),
          ),
          child: goalTotal == 0
              ? const _ChartEmpty(
                  message: 'Create a savings goal to track progress.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LinearProgressIndicator(
                      value: (goalSaved / goalTotal).clamp(0.0, 1.0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Money(goalSaved, currencyCode: currency).format()} saved · ${Money(goalTotal, currencyCode: currency).format()} target',
                    ),
                  ],
                ),
        ),
        _analyticsCard(
          context,
          sectionId: 'upcomingCommitments',
          collapsedSummary: upcoming.isEmpty
              ? 'No unpaid bills or installments'
              : '${upcoming.length} open bills and installments',
          title: 'Upcoming commitments',
          subtitle: 'Bills and installments keep their existing due dates',
          trailing: TextButton(
            onPressed: () => context.go(RouteNames.billsPath),
            child: const Text('Bills'),
          ),
          child: Column(
            children: <Widget>[
              if (upcoming.isEmpty)
                const _ChartEmpty(
                  message: 'No upcoming bill or loan installment found.',
                ),
              ..._groupUpcomingObligations(context, upcoming, currency),
            ],
          ),
        ),
        _analyticsCard(
          context,
          sectionId: 'nextPayday',
          collapsedSummary: nextPaydays.isEmpty
              ? 'No active payday schedule'
              : '${nextPaydays.first.$1.name} · ${DateFormat.yMMMd().format(nextPaydays.first.$2)}',
          title: 'Next payday',
          subtitle: 'Expected income and remaining planned allocations',
          trailing: TextButton(
            onPressed: () => context.go(RouteNames.moreModule('planner')),
            child: const Text('Planner'),
          ),
          child: nextPaydays.isEmpty
              ? const _ChartEmpty(message: 'No active payday schedule.')
              : Column(
                  children: nextPaydays.take(3).map((item) {
                    final PaydayScheduleEntry schedule = item.$1;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(schedule.name),
                      subtitle: Text(
                        '${DateFormat.yMMMd().format(item.$2)} · Expected, not received',
                      ),
                      trailing: Text(
                        Money(
                          schedule.expectedIncomeMinorUnits,
                          currencyCode: schedule.currencyCode,
                        ).format(),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  DashboardDateWindow _window(DateTime now, String currency) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    late DateTime start;
    late DateTime end;
    if (_period == _Period.custom && _customRange != null) {
      start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day + 1,
      );
    } else {
      switch (_period) {
        case _Period.day:
          start = today;
          end = today.add(const Duration(days: 1));
        case _Period.week:
          start = today.subtract(
            Duration(days: today.weekday - DateTime.monday),
          );
          end = start.add(const Duration(days: 7));
        case _Period.month:
          start = DateTime(today.year, today.month);
          end = DateTime(today.year, today.month + 1);
        case _Period.quarter:
          start = DateTime(today.year, ((today.month - 1) ~/ 3) * 3 + 1);
          end = DateTime(start.year, start.month + 3);
        case _Period.year:
          start = DateTime(today.year);
          end = DateTime(today.year + 1);
        case _Period.custom:
          start = DateTime(today.year, today.month);
          end = DateTime(today.year, today.month + 1);
      }
    }
    final Duration duration = end.difference(start);
    return DashboardDateWindow(
      start: start,
      endExclusive: end,
      previousStart: start.subtract(duration),
      previousEndExclusive: start,
      currencyCode: currency,
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    int amount,
    String currency,
    IconData icon, {
    VoidCallback? onTap,
    String? caption,
    double? width,
  }) {
    final Widget content = SizedBox(
      width: width ?? 158,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money(amount, currencyCode: currency).format(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (caption != null)
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );
    return onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: content,
          );
  }

  Widget _comparison(
    BuildContext context,
    FinancialAnalyticsSummary summary,
    String currency,
  ) => Wrap(
    spacing: 18,
    runSpacing: 6,
    children: <Widget>[
      Text(
        'Income ${_changeLabel(summary.incomeMinorUnits, summary.previousIncomeMinorUnits)} vs previous period',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(
        'Expenses ${_changeLabel(summary.expensesMinorUnits, summary.previousExpensesMinorUnits)} vs previous period',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(
        'Previous expenses ${Money(summary.previousExpensesMinorUnits, currencyCode: currency).format()}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  String _changeLabel(int current, int previous) {
    final int change = current - previous;
    if (previous == 0) return change == 0 ? 'unchanged' : 'new';
    final int percent = change * 100 ~/ previous.abs();
    return '${percent >= 0 ? '+' : ''}$percent%';
  }

  Widget _incomeExpenseChart(
    BuildContext context,
    FinancialAnalyticsSummary summary,
  ) {
    final Color income = Theme.of(context).colorScheme.tertiary;
    final Color expense = Theme.of(context).colorScheme.error;
    final double max = math
        .max(summary.incomeMinorUnits, summary.expensesMinorUnits)
        .toDouble();
    return BarChart(
      BarChartData(
        maxY: max == 0 ? 1 : max * 1.2,
        barGroups: <BarChartGroupData>[
          BarChartGroupData(
            x: 0,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: summary.incomeMinorUnits.toDouble(),
                color: income,
                width: 32,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: summary.expensesMinorUnits.toDouble(),
                color: expense,
                width: 32,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) =>
                  SideTitleWidget(
                    meta: meta,
                    child: Text(value == 0 ? 'Income' : 'Expenses'),
                  ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
      ),
    );
  }

  Widget _trendChart(BuildContext context, List<CashFlowTrendPoint> trend) {
    final double max = trend.fold<double>(
      0,
      (double current, CashFlowTrendPoint p) => math.max(
        current,
        math.max(p.incomeMinorUnits, p.expensesMinorUnits).toDouble(),
      ),
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: max <= 0 ? 1 : max * 1.15,
        lineBarsData: <LineChartBarData>[
          _line(context, trend, true),
          _line(context, trend, false),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: math.max(1, trend.length / 5).toDouble(),
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= trend.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat(
                      trend.length > 7 ? 'M/d' : 'EEE',
                    ).format(trend[index].date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
      ),
    );
  }

  LineChartBarData _line(
    BuildContext context,
    List<CashFlowTrendPoint> trend,
    bool income,
  ) => LineChartBarData(
    spots: <FlSpot>[
      for (int i = 0; i < trend.length; i++)
        FlSpot(
          i.toDouble(),
          (income ? trend[i].incomeMinorUnits : trend[i].expensesMinorUnits)
              .toDouble(),
        ),
    ],
    isCurved: false,
    color: income
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.error,
    barWidth: 3,
    dotData: const FlDotData(show: true),
  );

  Widget _expenseChart(BuildContext context, Map<String, int> categories) {
    final List<MapEntry<String, int>> entries = _topCategories(
      categories,
    ).take(6).toList();
    final List<Color> colors = <Color>[
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.secondary,
      Colors.amber,
      Colors.blueGrey,
    ];
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 38,
        sections: <PieChartSectionData>[
          for (int i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value.toDouble(),
              color: colors[i],
              title: entries[i].key,
              titleStyle: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white),
              radius: 80,
            ),
        ],
        pieTouchData: PieTouchData(enabled: true),
      ),
    );
  }

  Widget _accountBalancesChart(
    BuildContext context,
    List<FinancialAccount> accounts,
  ) {
    final List<FinancialAccount> eligible = accounts
        .where(
          (FinancialAccount account) =>
              account.isActive &&
              account.archivedAt == null &&
              account.accountType != 'credit_card' &&
              !(account.accountType == 'debit_card' &&
                  account.linkedAccountId != null) &&
              account.currencyCode == widget.currencyCode,
        )
        .take(8)
        .toList();
    if (eligible.isEmpty) {
      return const _ChartEmpty(
        message: 'No eligible active accounts in this currency.',
      );
    }
    final double max = eligible.fold<double>(
      0,
      (double value, FinancialAccount account) =>
          math.max(value, account.currentBalanceMinorUnits.abs().toDouble()),
    );
    return BarChart(
      BarChartData(
        maxY: max <= 0 ? 1 : max * 1.2,
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < eligible.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: eligible[i].currentBalanceMinorUnits.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                  width: 24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                return index < 0 || index >= eligible.length
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(
                          eligible[index].name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
      ),
    );
  }

  Widget _analyticsCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
    String? sectionId,
    String? collapsedSummary,
  }) {
    final bool expanded = sectionId == null
        ? true
        : ref.watch(
            dashboardSectionStateProvider.select(
              (Map<String, bool> states) => states[sectionId] ?? true,
            ),
          );
    void toggle() {
      if (sectionId != null) {
        ref.read(dashboardSectionStateProvider.notifier).toggle(sectionId);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: sectionId == null ? null : toggle,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                ?trailing,
                if (sectionId != null)
                  IconButton(
                    tooltip: expanded ? 'Collapse $title' : 'Expand $title',
                    onPressed: toggle,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: expanded
                    ? <Widget>[
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        child,
                      ]
                    : <Widget>[
                        Text(
                          collapsedSummary ?? subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);

  List<MapEntry<String, int>> _topCategories(Map<String, int> values) =>
      values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  List<_Obligation> _upcomingObligations({
    required List<BillEntry> bills,
    required List<BillPaymentEntry> billPayments,
    required List<LoanEntry> loans,
    required List<LoanInstallmentEntry> installments,
  }) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start = today.subtract(const Duration(days: 35));
    final DateTime end = today.add(const Duration(days: 120));
    final List<_Obligation> result = <_Obligation>[];
    for (final BillEntry bill in bills.where(
      (item) => item.isActive && item.currencyCode == widget.currencyCode,
    )) {
      for (final DateTime date in BillScheduleCalculator.occurrences(
        anchor: bill.dueDate,
        frequency: bill.frequency,
        start: bill.frequency == 'one_time' ? bill.dueDate : start,
        end: end,
      )) {
        final BillOccurrence occurrence = BillOccurrence(
          bill: bill,
          dueDate: date,
        );
        final BillOccurrenceStatus status = occurrence.status(
          billPayments,
          now,
        );
        if (status == BillOccurrenceStatus.paid ||
            status == BillOccurrenceStatus.skipped ||
            status == BillOccurrenceStatus.cancelled) {
          continue;
        }
        result.add(
          _Obligation(
            title: bill.name,
            date: date,
            amountMinorUnits: occurrence.remaining(billPayments),
            status: status.name,
            isLoan: false,
          ),
        );
      }
    }
    for (final LoanInstallmentEntry item in installments) {
      if (item.status == 'paid' ||
          item.status == 'settled' ||
          item.status == 'skipped' ||
          item.status == 'cancelled' ||
          item.paidMinorUnits >= item.scheduledMinorUnits) {
        continue;
      }
      if (item.dueDate.isBefore(start) || item.dueDate.isAfter(end)) continue;
      final LoanEntry? loan = loans
          .where((row) => row.id == item.loanId)
          .firstOrNull;
      if (loan == null ||
          loan.status != 'active' ||
          loan.currencyCode != widget.currencyCode) {
        continue;
      }
      result.add(
        _Obligation(
          title: loan.name,
          date: item.dueDate,
          amountMinorUnits: (item.scheduledMinorUnits - item.paidMinorUnits)
              .clamp(0, item.scheduledMinorUnits),
          status: item.dueDate.isBefore(today)
              ? 'Overdue'
              : item.status == 'partial'
              ? 'Partially paid'
              : 'Upcoming',
          isLoan: true,
        ),
      );
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Widget> _groupUpcomingObligations(
    BuildContext context,
    List<_Obligation> obligations,
    String currency,
  ) {
    final Map<DateTime, List<_Obligation>> byMonth =
        <DateTime, List<_Obligation>>{};
    for (final _Obligation obligation in obligations) {
      final DateTime month = DateTime(
        obligation.date.year,
        obligation.date.month,
      );
      byMonth.putIfAbsent(month, () => <_Obligation>[]).add(obligation);
    }
    final List<DateTime> months = byMonth.keys.toList()..sort();
    return months.map((DateTime month) {
      final List<_Obligation> items = byMonth[month]!;
      final int installmentCount = items
          .where((_Obligation item) => item.isLoan)
          .length;
      final int billCount = items.length - installmentCount;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ExpansionTile(
          title: Text(DateFormat.yMMMM().format(month)),
          subtitle: Text(
            '$installmentCount active loan installments · $billCount open bills',
          ),
          children: items
              .map(
                (_Obligation item) => ListTile(
                  dense: true,
                  leading: Icon(
                    item.isLoan
                        ? Icons.account_balance
                        : item.status == 'overdue'
                        ? Icons.warning_amber_rounded
                        : Icons.receipt_long,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(item.date)} · ${item.status}',
                  ),
                  trailing: Text(
                    Money(
                      item.amountMinorUnits,
                      currencyCode: currency,
                    ).format(),
                  ),
                  onTap: () => context.go(
                    item.isLoan ? RouteNames.loansPath : RouteNames.billsPath,
                  ),
                ),
              )
              .toList(),
        ),
      );
    }).toList();
  }

  DateTime? _nextPayday(
    PaydayScheduleEntry schedule,
    DateTime start,
    DateTime end,
  ) {
    final dates = PaydayScheduleCalculator.occurrences(
      anchor: schedule.paydayDate,
      frequency: schedule.frequency,
      start: start,
      end: end,
    );
    return dates.isEmpty ? null : dates.first;
  }

  String _windowLabel(DashboardDateWindow window) =>
      '${DateFormat.yMMMd().format(window.start)} – ${DateFormat.yMMMd().format(window.endExclusive.subtract(const Duration(days: 1)))}';

  bool _inRange(DateTime date, DateTime start, DateTime end) {
    final DateTime local = date.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}

final class _Obligation {
  const _Obligation({
    required this.title,
    required this.date,
    required this.amountMinorUnits,
    required this.status,
    required this.isLoan,
  });
  final String title;
  final DateTime date;
  final int amountMinorUnits;
  final String status;
  final bool isLoan;
}
