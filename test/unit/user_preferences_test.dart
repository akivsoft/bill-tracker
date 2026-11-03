import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/features/settings/data/repositories/local_user_preferences_repository.dart';
import 'package:bill_tracker/features/transactions/domain/entities/financial_commands.dart';
import 'package:bill_tracker/data/local/datasources/local_financial_data_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late LocalUserPreferencesRepository preferences;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    preferences = LocalUserPreferencesRepository(database);
  });

  tearDown(() async => database.close());

  test(
    'first run receives local defaults without creating financial records',
    () async {
      final value = await preferences.load();
      expect(value.onboardingComplete, isFalse);
      expect(value.setupComplete, isFalse);
      expect(value.countryCode, 'PH');
      expect(value.currencyCode, 'PHP');
      expect(value.firstDayOfWeek, DateTime.monday);
      expect(value.dateFormat, 'MM/dd/yyyy');
      expect(value.themeMode, 'system');
      expect(await database.select(database.financialAccounts).get(), isEmpty);
    },
  );

  test(
    'onboarding and setup completion persist across repository reloads',
    () async {
      await preferences.load();
      await preferences.setOnboardingComplete(true);
      await preferences.setSetupComplete(true);

      final value = await LocalUserPreferencesRepository(database).load();
      expect(value.onboardingComplete, isTrue);
      expect(value.setupComplete, isTrue);
    },
  );

  test('personal, income, and theme preferences are saved locally', () async {
    await preferences.load();
    await preferences.savePersonalPreferences(
      displayName: 'Sam',
      countryCode: 'SG',
      currencyCode: 'SGD',
      firstDayOfWeek: DateTime.sunday,
      dateFormat: 'dd/MM/yyyy',
    );
    await preferences.saveIncomeFrequency('biweekly');
    await preferences.setThemeMode('dark');

    final value = await preferences.load();
    expect(value.displayName, 'Sam');
    expect(value.countryCode, 'SG');
    expect(value.currencyCode, 'SGD');
    expect(value.firstDayOfWeek, DateTime.sunday);
    expect(value.dateFormat, 'dd/MM/yyyy');
    expect(value.incomeFrequency, 'biweekly');
    expect(value.themeMode, 'dark');
  });

  test('optional income preference can be skipped', () async {
    await preferences.load();
    final value = await preferences.saveIncomeFrequency(null);
    expect(value.incomeFrequency, isNull);
  });

  test(
    'credit card setup rejects an outstanding balance above its limit',
    () async {
      final LocalFinancialDataSource source = LocalFinancialDataSource(
        database,
      );

      await expectLater(
        source.createAccount(
          const CreateAccountInput(
            name: 'Travel card',
            accountType: 'credit_card',
            openingBalanceMinorUnits: 0,
            creditLimitMinorUnits: 100000,
            outstandingCreditMinorUnits: 120000,
          ),
        ),
        throwsArgumentError,
      );
      expect(await database.select(database.financialAccounts).get(), isEmpty);
    },
  );

  test('credit card setup requires a positive credit limit', () async {
    final LocalFinancialDataSource source = LocalFinancialDataSource(database);

    await expectLater(
      source.createAccount(
        const CreateAccountInput(
          name: 'Travel card',
          accountType: 'credit_card',
          openingBalanceMinorUnits: 0,
        ),
      ),
      throwsArgumentError,
    );
  });
}
