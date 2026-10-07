import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lavender,
    surface: AppColors.cream,
  ).copyWith(
    primary: AppColors.lavender,
    onPrimary: AppColors.white,
    onSurface: AppColors.navy,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.bengaliFallback,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: TextTheme(
      displayLarge: AppType.celebrate72,
      displayMedium: AppType.hero50,
      displaySmall: AppType.display36,
      headlineMedium: AppType.title24,
      titleLarge: AppType.heading20,
      bodyLarge: AppType.body16,
      bodyMedium: AppType.label14,
      bodySmall: AppType.micro12,
      labelSmall: AppType.micro11,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.cream,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.cream,
    ),
  );
}
