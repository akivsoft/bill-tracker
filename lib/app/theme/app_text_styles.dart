import 'package:flutter/material.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextTheme forColorScheme(ColorScheme colors) =>
      ThemeData(useMaterial3: true, colorScheme: colors).textTheme.copyWith(
        headlineSmall: const TextStyle(fontWeight: FontWeight.w700),
        titleLarge: const TextStyle(fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      );
}
