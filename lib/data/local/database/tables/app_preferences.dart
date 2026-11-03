import 'package:drift/drift.dart';

@DataClassName('AppPreferencesRecord')
class AppPreferencesTable extends Table {
  IntColumn get id => integer()();
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get setupComplete =>
      boolean().withDefault(const Constant(false))();
  TextColumn get displayName => text().nullable()();
  TextColumn get countryCode => text().withDefault(const Constant('PH'))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  IntColumn get firstDayOfWeek => integer().withDefault(const Constant(1))();
  TextColumn get dateFormat =>
      text().withDefault(const Constant('MM/dd/yyyy'))();
  TextColumn get incomeFrequency => text().nullable()();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get languageCode => text().withDefault(const Constant('en'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
