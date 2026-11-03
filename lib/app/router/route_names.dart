class RouteNames {
  const RouteNames._();

  static const String home = 'home';
  static const String bills = 'bills';
  static const String wallets = 'wallets';
  static const String loans = 'loans';
  static const String more = 'more';
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String setup = 'setup';
  static const String authentication = 'authentication';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';
  static const String startupError = 'startup-error';

  static const String homePath = '/home';
  static const String billsPath = '/bills';
  static const String walletsPath = '/wallets';
  static const String loansPath = '/loans';
  static const String morePath = '/more';
  static const String splashPath = '/splash';
  static const String onboardingPath = '/onboarding';
  static const String setupPath = '/setup';
  static const String authenticationPath = '/auth';
  static const String forgotPasswordPath = '/auth/forgot-password';
  static const String resetPasswordPath = '/auth/reset-password';
  static const String authCallbackPath = '/login-callback';
  static const String startupErrorPath = '/startup-error';

  static String moreModule(String slug) => '$morePath/$slug';

  static String walletAccount(String accountId) => '$walletsPath/$accountId';
}
