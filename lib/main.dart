import 'package:bill_tracker/app/app.dart';
import 'package:bill_tracker/app/config/supabase_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  runApp(const ProviderScope(child: MyFinanceApp()));
}
