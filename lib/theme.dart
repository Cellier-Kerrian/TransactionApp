import 'package:flutter/material.dart';
import 'user_config.dart';

ThemeData buildAppTheme() {
  final Color seed = UserConfig.APP_SEED_COLOR;
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  final fixedScheme = scheme.copyWith(primary: seed);
  final base = ThemeData(
    colorScheme: fixedScheme,
    useMaterial3: true,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: fixedScheme.primary,
      foregroundColor: fixedScheme.onPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fixedScheme.primary,
        foregroundColor: fixedScheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: fixedScheme.primary,
        foregroundColor: fixedScheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
