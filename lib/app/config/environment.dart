class AppEnvironment {
  const AppEnvironment._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'com.myfinance.billtracker://login-callback',
  );

  static bool get hasSupabaseCredentials =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
