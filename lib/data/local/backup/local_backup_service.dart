import 'dart:convert';

import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:drift/drift.dart';

final class BackupValidation {
  const BackupValidation({required this.tables, required this.recordCount});
  final List<String> tables;
  final int recordCount;
}

final class LocalBackupService {
  LocalBackupService(this._database);

  final AppDatabase _database;
  static const int currentVersion = 1;
  static const List<String> tableNames = <String>[
    'app_preferences_table',
    'categories',
    'financial_accounts',
    'bills',
    'loan_providers',
    'loans',
    'transactions',
    'loan_installments',
    'bill_payments',
    'income_sources',
    'income_records',
    'expenses',
    'loan_payments',
    'savings_goals',
    'savings_contributions',
    'account_transfers',
    'payday_schedules',
    'financial_allocations',
    'sync_queue',
  ];

  Future<String> createBackup() async {
    final Map<String, Object?> tables = <String, Object?>{};
    for (final String table in tableNames) {
      final List<QueryRow> rows = await _database
          .customSelect('SELECT * FROM "$table"')
          .get();
      tables[table] = rows.map((row) => row.data).toList(growable: false);
    }
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'format': 'myfinance-local-backup',
      'version': currentVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    });
  }

  BackupValidation validate(String contents) {
    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      throw const FormatException('The backup is not valid JSON.');
    }
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != 'myfinance-local-backup' ||
        decoded['version'] != currentVersion ||
        decoded['tables'] is! Map<String, Object?>) {
      throw const FormatException('Unsupported or malformed backup file.');
    }
    final Map<String, Object?> tables =
        decoded['tables']! as Map<String, Object?>;
    if (tables.keys.toSet().difference(tableNames.toSet()).isNotEmpty ||
        tableNames.any((String name) => tables[name] is! List<Object?>)) {
      throw const FormatException(
        'Backup tables do not match this app version.',
      );
    }
    int count = 0;
    for (final String name in tableNames) {
      final List<Object?> rows = tables[name]! as List<Object?>;
      count += rows.length;
      for (final Object? row in rows) {
        if (row is! Map<String, Object?> ||
            row.values.any((value) => value is Map || value is List)) {
          throw FormatException('Invalid row data in $name.');
        }
      }
    }
    return BackupValidation(
      tables: List<String>.unmodifiable(tableNames),
      recordCount: count,
    );
  }

  Future<BackupValidation> restoreReplacing(String contents) async {
    final BackupValidation validation = validate(contents);
    final Map<String, Object?> decoded =
        jsonDecode(contents) as Map<String, Object?>;
    final Map<String, Object?> tables =
        decoded['tables']! as Map<String, Object?>;
    await _database.transaction(() async {
      for (final String table in tableNames.reversed) {
        await _database.customStatement('DELETE FROM "$table"');
      }
      for (final String table in tableNames) {
        final List<Object?> rows = tables[table]! as List<Object?>;
        for (final Object? rowValue in rows) {
          final Map<String, Object?> row = rowValue! as Map<String, Object?>;
          if (row.isEmpty) continue;
          final List<String> columns = row.keys.toList(growable: false);
          if (columns.any(
            (column) => !RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(column),
          )) {
            throw FormatException('Invalid column name in $table.');
          }
          final String placeholders = List<String>.filled(
            columns.length,
            '?',
          ).join(', ');
          final String names = columns.map((column) => '"$column"').join(', ');
          await _database.customStatement(
            'INSERT INTO "$table" ($names) VALUES ($placeholders)',
            columns.map((column) => row[column]).toList(),
          );
        }
      }
      await _database.customSelect('PRAGMA foreign_key_check').get().then((
        rows,
      ) {
        if (rows.isNotEmpty) {
          throw const FormatException(
            'Backup contains broken financial record links.',
          );
        }
      });
    });
    return validation;
  }
}
