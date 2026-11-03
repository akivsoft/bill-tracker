import 'dart:async';

import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:bill_tracker/data/local/local_data_source.dart';
import 'package:bill_tracker/features/transactions/data/repositories/local_financial_repository.dart';
import 'package:bill_tracker/features/transactions/domain/repositories/financial_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_providers.g.dart';

@riverpod
AppDatabase appDatabase(Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
}

@riverpod
LocalDataSource localDataSource(Ref ref) =>
    LocalDataSource(ref.watch(appDatabaseProvider));

@riverpod
LocalFinancialDataSource localFinancialDataSource(Ref ref) =>
    LocalFinancialDataSource(ref.watch(appDatabaseProvider));

@riverpod
FinancialRepository financialRepository(Ref ref) =>
    LocalFinancialRepository(ref.watch(localFinancialDataSourceProvider));
