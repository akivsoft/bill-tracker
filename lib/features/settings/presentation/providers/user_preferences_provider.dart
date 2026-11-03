import 'package:bill_tracker/features/settings/data/repositories/local_user_preferences_repository.dart';
import 'package:bill_tracker/features/settings/domain/entities/user_preferences.dart';
import 'package:bill_tracker/features/settings/domain/repositories/user_preferences_repository.dart';
import 'package:bill_tracker/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<UserPreferencesRepository> userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>(
      (Ref ref) =>
          LocalUserPreferencesRepository(ref.watch(appDatabaseProvider)),
    );

final AsyncNotifierProvider<UserPreferencesController, UserPreferences>
userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesController, UserPreferences>(
      UserPreferencesController.new,
    );

class UserPreferencesController extends AsyncNotifier<UserPreferences> {
  late UserPreferencesRepository _repository;

  @override
  Future<UserPreferences> build() {
    _repository = ref.watch(userPreferencesRepositoryProvider);
    return _repository.load();
  }

  Future<void> savePersonalPreferences({
    required String? displayName,
    required String countryCode,
    required String currencyCode,
    required int firstDayOfWeek,
    required String dateFormat,
  }) async {
    await _save(
      _repository.savePersonalPreferences(
        displayName: displayName,
        countryCode: countryCode,
        currencyCode: currencyCode,
        firstDayOfWeek: firstDayOfWeek,
        dateFormat: dateFormat,
      ),
    );
  }

  Future<void> saveIncomeFrequency(String? frequency) async =>
      _save(_repository.saveIncomeFrequency(frequency));

  Future<void> completeOnboarding() async =>
      _save(_repository.setOnboardingComplete(true));

  Future<void> resetOnboarding() async =>
      _save(_repository.setOnboardingComplete(false));

  Future<void> completeSetup() async =>
      _save(_repository.setSetupComplete(true));

  Future<void> setThemeMode(String mode) async =>
      _save(_repository.setThemeMode(mode));

  Future<void> _save(Future<UserPreferences> operation) async {
    final AsyncValue<UserPreferences> previous = state;
    try {
      state = AsyncData<UserPreferences>(await operation);
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
