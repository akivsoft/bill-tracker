final class UserPreferences {
  const UserPreferences({
    required this.onboardingComplete,
    required this.setupComplete,
    required this.countryCode,
    required this.currencyCode,
    required this.firstDayOfWeek,
    required this.dateFormat,
    required this.themeMode,
    required this.languageCode,
    this.displayName,
    this.incomeFrequency,
  });

  final bool onboardingComplete;
  final bool setupComplete;
  final String? displayName;
  final String countryCode;
  final String currencyCode;
  final int firstDayOfWeek;
  final String dateFormat;
  final String? incomeFrequency;
  final String themeMode;
  final String languageCode;

  UserPreferences copyWith({
    bool? onboardingComplete,
    bool? setupComplete,
    String? displayName,
    bool clearDisplayName = false,
    String? countryCode,
    String? currencyCode,
    int? firstDayOfWeek,
    String? dateFormat,
    String? incomeFrequency,
    bool clearIncomeFrequency = false,
    String? themeMode,
    String? languageCode,
  }) => UserPreferences(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    setupComplete: setupComplete ?? this.setupComplete,
    displayName: clearDisplayName ? null : displayName ?? this.displayName,
    countryCode: countryCode ?? this.countryCode,
    currencyCode: currencyCode ?? this.currencyCode,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    dateFormat: dateFormat ?? this.dateFormat,
    incomeFrequency: clearIncomeFrequency
        ? null
        : incomeFrequency ?? this.incomeFrequency,
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
  );
}
