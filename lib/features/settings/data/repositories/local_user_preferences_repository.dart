import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/database/tables/app_preferences.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:bill_tracker/features/settings/domain/repositories/user_preferences_repository.dart';
import 'package:drift/drift.dart';

class LocalUserPreferencesRepository implements UserPreferencesRepository {
  LocalUserPreferencesRepository(this._database);

  static const int _preferencesId = 1;
  final AppDatabase _database;

  @override
  Future<UserPreferences> load() async {
    final AppPreferencesRecord? existing =
        await (_database.select(_database.appPreferencesTable)..where(
              (AppPreferencesTable row) => row.id.equals(_preferencesId),
            ))
            .getSingleOrNull();
    if (existing != null) return _toDomain(existing);

    await _database
        .into(_database.appPreferencesTable)
        .insert(
          AppPreferencesTableCompanion.insert(
            id: Value<int>(_preferencesId),
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return _toDomain(
      await (_database.select(_database.appPreferencesTable)
            ..where((AppPreferencesTable row) => row.id.equals(_preferencesId)))
          .getSingle(),
    );
  }

  @override
  Future<UserPreferences> savePersonalPreferences({
    required String? displayName,
    required String countryCode,
    required String currencyCode,
    required int firstDayOfWeek,
    required String dateFormat,
  }) => _write(
    AppPreferencesTableCompanion(
      displayName: Value<String?>(
        displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      ),
      countryCode: Value<String>(countryCode),
      currencyCode: Value<String>(currencyCode),
      firstDayOfWeek: Value<int>(firstDayOfWeek),
      dateFormat: Value<String>(dateFormat),
    ),
  );

  @override
  Future<UserPreferences> saveIncomeFrequency(String? frequency) => _write(
    AppPreferencesTableCompanion(incomeFrequency: Value<String?>(frequency)),
  );

  @override
  Future<UserPreferences> setOnboardingComplete(bool complete) => _write(
    AppPreferencesTableCompanion(onboardingComplete: Value<bool>(complete)),
  );

  @override
  Future<UserPreferences> setSetupComplete(bool complete) => _write(
    AppPreferencesTableCompanion(setupComplete: Value<bool>(complete)),
  );

  @override
  Future<UserPreferences> setThemeMode(String mode) {
    if (!const <String>{'system', 'light', 'dark'}.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    return _write(AppPreferencesTableCompanion(themeMode: Value<String>(mode)));
  }

  Future<UserPreferences> _write(
    AppPreferencesTableCompanion changes,
  ) => _database.transaction(() async {
    await load();
    await (_database.update(
      _database.appPreferencesTable,
    )..where((AppPreferencesTable row) => row.id.equals(_preferencesId))).write(
      changes.copyWith(updatedAt: Value<DateTime>(DateTime.now().toUtc())),
    );
    final AppPreferencesRecord record =
        await (_database.select(_database.appPreferencesTable)..where(
              (AppPreferencesTable row) => row.id.equals(_preferencesId),
            ))
            .getSingle();
    return _toDomain(record);
  });

  UserPreferences _toDomain(AppPreferencesRecord record) => UserPreferences(
    onboardingComplete: record.onboardingComplete,
    setupComplete: record.setupComplete,
    displayName: record.displayName,
    countryCode: record.countryCode,
    currencyCode: record.currencyCode,
    firstDayOfWeek: record.firstDayOfWeek,
    dateFormat: record.dateFormat,
    incomeFrequency: record.incomeFrequency,
    themeMode: record.themeMode,
    languageCode: record.languageCode,
  );
}
