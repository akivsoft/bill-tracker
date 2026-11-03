import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';

abstract interface class UserPreferencesRepository {
  Future<UserPreferences> load();

  Future<UserPreferences> savePersonalPreferences({
    required String? displayName,
    required String countryCode,
    required String currencyCode,
    required int firstDayOfWeek,
    required String dateFormat,
  });

  Future<UserPreferences> saveIncomeFrequency(String? frequency);
  Future<UserPreferences> setOnboardingComplete(bool complete);
  Future<UserPreferences> setSetupComplete(bool complete);
  Future<UserPreferences> setThemeMode(String mode);
}
