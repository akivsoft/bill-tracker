import 'package:bill_tracker/app/config/environment.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static bool isInitialized = false;

  static Future<void> initialize() async {
    if (!AppEnvironment.hasSupabaseCredentials) return;

    try {
      await Supabase.initialize(
        url: AppEnvironment.supabaseUrl,
        publishableKey: AppEnvironment.supabaseAnonKey,
      );
      isInitialized = true;
    } catch (error, stackTrace) {
      debugPrint('Supabase initialization failed; offline mode is available.');
      debugPrint('$error\n$stackTrace');
    }
  }
}
