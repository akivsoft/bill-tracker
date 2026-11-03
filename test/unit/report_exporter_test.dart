import 'package:bill_tracker/features/reports/domain/report_exporter.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ReportData report = ReportData(
    filters: ReportFilters(
      start: DateTime(2026, 10, 1),
      endExclusive: DateTime(2026, 11, 1),
      currencyCode: 'PHP',
    ),
    rows: <FinancialTransactionView>[
      FinancialTransactionView(
        id: 'i1',
        type: 'income',
        title: 'Salary, monthly',
        amountMinorUnits: 12345,
        currencyCode: 'PHP',
        occurredAt: DateTime(2026, 10, 3),
      ),
      FinancialTransactionView(
        id: 'e1',
        type: 'expense',
        title: 'Food "market"',
        amountMinorUnits: 2345,
        currencyCode: 'PHP',
        occurredAt: DateTime(2026, 10, 4),
        category: 'Food',
      ),
      FinancialTransactionView(
        id: 'old',
        type: 'income',
        title: 'Outside period',
        amountMinorUnits: 99999,
        currencyCode: 'PHP',
        occurredAt: DateTime(2026, 9, 30),
      ),
    ],
  );

  test('filters rows and calculates report totals from actual activity', () {
    expect(report.filteredRows, hasLength(2));
    expect(report.incomeMinorUnits, 12345);
    expect(report.expenseMinorUnits, 2345);
    expect(
      ReportExporter.csv(report, generatedAt: DateTime(2026, 11, 3)),
      contains('NET CASH FLOW'),
    );
  });

  test('generates CSV, Excel, and PDF with report headings', () async {
    final String csv = ReportExporter.csv(
      report,
      generatedAt: DateTime(2026, 11, 3),
    );
    expect(csv, contains('Date'));
    expect(csv, contains('Salary, monthly'));
    expect(csv, contains('Food ""market""'));
    expect(
      ReportExporter.excel(report, generatedAt: DateTime(2026, 11, 3)),
      isNotEmpty,
    );
    final List<int> pdf = await ReportExporter.pdf(
      report,
      generatedAt: DateTime(2026, 11, 3),
    );
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
