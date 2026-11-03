// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'9149e488dcac550fc8dc003207480aa2b73abca4';

@ProviderFor(localDataSource)
final localDataSourceProvider = LocalDataSourceProvider._();

final class LocalDataSourceProvider
    extends
        $FunctionalProvider<LocalDataSource, LocalDataSource, LocalDataSource>
    with $Provider<LocalDataSource> {
  LocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localDataSourceHash();

  @$internal
  @override
  $ProviderElement<LocalDataSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalDataSource create(Ref ref) {
    return localDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalDataSource>(value),
    );
  }
}

String _$localDataSourceHash() => r'22dc4b6b561dcdb1efbeecf4a10979ef968a81e3';

@ProviderFor(localFinancialDataSource)
final localFinancialDataSourceProvider = LocalFinancialDataSourceProvider._();

final class LocalFinancialDataSourceProvider
    extends
        $FunctionalProvider<
          LocalFinancialDataSource,
          LocalFinancialDataSource,
          LocalFinancialDataSource
        >
    with $Provider<LocalFinancialDataSource> {
  LocalFinancialDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localFinancialDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localFinancialDataSourceHash();

  @$internal
  @override
  $ProviderElement<LocalFinancialDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalFinancialDataSource create(Ref ref) {
    return localFinancialDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalFinancialDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalFinancialDataSource>(value),
    );
  }
}

String _$localFinancialDataSourceHash() =>
    r'6edd5738d405c23a12887cc0208d0395c83a69b3';

@ProviderFor(financialRepository)
final financialRepositoryProvider = FinancialRepositoryProvider._();

final class FinancialRepositoryProvider
    extends
        $FunctionalProvider<
          FinancialRepository,
          FinancialRepository,
          FinancialRepository
        >
    with $Provider<FinancialRepository> {
  FinancialRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financialRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financialRepositoryHash();

  @$internal
  @override
  $ProviderElement<FinancialRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinancialRepository create(Ref ref) {
    return financialRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinancialRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinancialRepository>(value),
    );
  }
}

String _$financialRepositoryHash() =>
    r'e7071aa8bd089726d49c7aa65c8632e159125ba5';
