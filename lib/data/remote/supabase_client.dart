import 'package:bill_tracker/app/config/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient? get configuredSupabaseClient =>
    SupabaseBootstrap.isInitialized ? Supabase.instance.client : null;
