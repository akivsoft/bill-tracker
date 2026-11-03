import 'dart:convert';

import 'package:bill_tracker/features/transactions/domain/entities/financial_values.dart';
import 'package:bill_tracker/core/utils/money.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final class ReportFilters {
  const ReportFilters({
    required this.start,
    required this.endExclusive,
    required this.currencyCode,
    this.accountId,
    this.category,
    this.transactionType,
  });

  final DateTime start;
  final DateTime endExclusive;
  final String currencyCode;
  final String? accountId;
  final String? category;
  final String? transactionType;
}

final class ReportData {
  const ReportData({required this.filters, required this.rows});

  final ReportFilters filters;
  final List<FinancialTransactionView> rows;

  List<FinancialTransactionView> get filteredRows => rows
      .where((FinancialTransactionView row) {
        final DateTime date = row.occurredAt.toLocal();
        return row.currencyCode == filters.currencyCode &&
            !date.isBefore(filters.start) &&
            date.isBefore(filters.endExclusive) &&
            (filters.accountId == null ||
                row.sourceAccountId == filters.accountId ||
                row.destinationAccountId == filters.accountId) &&
            (filters.category == null || row.category == filters.category) &&
            (filters.transactionType == null ||
                row.type == filters.transactionType);
      })
      .toList(growable: false);

  int get incomeMinorUnits => filteredRows
      .where((row) => row.type == 'income')
      .fold<int>(0, (sum, row) => sum + row.amountMinorUnits);

  int get expenseMinorUnits => filteredRows
      .where(
        (row) => const <String>{
          'expense',
          'credit_card_purchase',
          'bill_payment',
          'loan_payment',
        }.contains(row.type),
      )
      .fold<int>(0, (sum, row) => sum + row.amountMinorUnits);

  Map<String, int> get expensesByCategory {
    final Map<String, int> totals = <String, int>{};
    for (final FinancialTransactionView row in filteredRows.where(
      (item) => const <String>{
        'expense',
        'credit_card_purchase',
        'bill_payment',
        'loan_payment',
      }.contains(item.type),
    )) {
      final String category = row.category?.trim().isNotEmpty == true
          ? row.category!.trim()
          : switch (row.type) {
              'bill_payment' => 'Bill payments',
              'loan_payment' => 'Loan repayments',
              'credit_card_purchase' => 'Credit card purchases',
              _ => 'Uncategorised',
            };
      totals.update(
        category,
        (value) => value + row.amountMinorUnits,
        ifAbsent: () => row.amountMinorUnits,
      );
    }
    return Map<String, int>.unmodifiable(totals);
  }

  String get filterDescription => <String>[
    '${DateFormat.yMMMd().format(filters.start)} – ${DateFormat.yMMMd().format(filters.endExclusive.subtract(const Duration(days: 1)))}',
    'Currency: ${filters.currencyCode}',
    if (filters.accountId != null) 'Account: ${filters.accountId}',
    if (filters.category != null) 'Category: ${filters.category}',
    if (filters.transactionType != null) 'Type: ${filters.transactionType}',
  ].join(' · ');

  List<List<String>> get tableRows => <List<String>>[
    <String>['Date', 'Type', 'Description', 'Category', 'Currency', 'Amount'],
    for (final FinancialTransactionView row in filteredRows)
      <String>[
        DateFormat('yyyy-MM-dd HH:mm').format(row.occurredAt.toLocal()),
        row.type.replaceAll('_', ' '),
        row.title,
        row.category ?? '',
        row.currencyCode,
        Money(row.amountMinorUnits, currencyCode: row.currencyCode).format(),
      ],
    <String>[
      'TOTAL INCOME',
      '',
      '',
      '',
      filters.currencyCode,
      Money(incomeMinorUnits, currencyCode: filters.currencyCode).format(),
    ],
    <String>[
      'TOTAL EXPENSES',
      '',
      '',
      '',
      filters.currencyCode,
      Money(expenseMinorUnits, currencyCode: filters.currencyCode).format(),
    ],
    <String>[
      'NET CASH FLOW',
      '',
      '',
      '',
      filters.currencyCode,
      Money(
        incomeMinorUnits - expenseMinorUnits,
        currencyCode: filters.currencyCode,
      ).format(),
    ],
    for (final MapEntry<String, int> category in expensesByCategory.entries)
      <String>[
        'CATEGORY · ${category.key}',
        '',
        '',
        '',
        filters.currencyCode,
        Money(category.value, currencyCode: filters.currencyCode).format(),
      ],
  ];
}

abstract final class ReportExporter {
  static String csv(ReportData report, {DateTime? generatedAt}) {
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    final List<List<String>> lines = <List<String>>[
      <String>['MyFinance report', report.filterDescription],
      <String>[
        'Generated',
        DateFormat.yMMMd().add_jm().format(generatedAt ?? DateTime.now()),
      ],
      ...report.tableRows,
    ];
    return lines.map((row) => row.map(cell).join(',')).join('\r\n');
  }

  static List<int> excel(ReportData report, {DateTime? generatedAt}) {
    final Excel workbook = Excel.createExcel();
    final Sheet sheet = workbook['Financial report'];
    sheet.appendRow(<CellValue?>[
      TextCellValue('MyFinance report · ${report.filterDescription}'),
    ]);
    sheet.appendRow(<CellValue?>[
      TextCellValue(
        'Generated ${DateFormat.yMMMd().add_jm().format(generatedAt ?? DateTime.now())}',
      ),
    ]);
    for (final List<String> row in report.tableRows) {
      sheet.appendRow(<CellValue?>[
        for (int index = 0; index < row.length; index++)
          index == 5 && int.tryParse(row[index]) != null
              ? IntCellValue(int.parse(row[index]))
              : TextCellValue(row[index]),
      ]);
    }
    return workbook.encode() ?? <int>[];
  }

  static Future<List<int>> pdf(ReportData report, {DateTime? generatedAt}) {
    final pw.Document document = pw.Document();
    final DateTime created = generatedAt ?? DateTime.now();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(
            'MyFinance - Financial report',
            style: pw.Theme.of(context).header2,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            report.filterDescription.replaceAll('–', '-').replaceAll('·', '-'),
          ),
          pw.Text('Generated ${DateFormat.yMMMd().add_jm().format(created)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: report.tableRows.first,
            data: report.tableRows
                .skip(1)
                .map(
                  (row) => row
                      .map(
                        (cell) =>
                            cell.replaceAll('₱', 'PHP ').replaceAll('·', '-'),
                      )
                      .toList(growable: false),
                )
                .toList(growable: false),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Actual totals only - amounts shown in ${report.filters.currencyCode}.',
          ),
        ],
      ),
    );
    return document.save();
  }

  static String jsonMetadata(ReportData report) => jsonEncode(<String, Object?>{
    'filters': report.filterDescription,
    'income_minor_units': report.incomeMinorUnits,
    'expense_minor_units': report.expenseMinorUnits,
    'net_minor_units': report.incomeMinorUnits - report.expenseMinorUnits,
  });
}
