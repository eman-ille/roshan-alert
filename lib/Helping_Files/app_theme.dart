import 'package:flutter/material.dart';

/// Single source of truth for colors used across the whole app.
/// Change a color here once, and every screen that uses it updates —
/// no more hunting through each screen file individually.
class AppColors {
  AppColors._(); // not meant to be instantiated

  static const Color black = Color(0xFF111111);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE3E3E6);
  static const Color grey = Color(0xFF767676);
  static const Color trackGrey = Color(0xFFEDEDED);
}

/// Named corner-radius tiers, so every rounded corner in the app picks
/// from the same 3 sizes instead of each widget inventing its own
/// number (10, 12, 16, 18, 20, 22...). Small = badges/pills, medium =
/// buttons/toggles, large = full content cards.
class AppRadius {
  AppRadius._();

  static const double small = 10;
  static const double medium = 14;
  static const double large = 18;
}

/// Single source of truth for the app's ThemeData, used by MaterialApp
/// in main.dart. Keeping it here (instead of inline in main.dart) means
/// button styles, AppBar styles, etc. can be tweaked without touching
/// routing or app setup code.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.black,
    primary: AppColors.black,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.white,
    foregroundColor: AppColors.black,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.black,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: AppColors.black,
    unselectedItemColor: Colors.grey.shade400,
    backgroundColor: AppColors.white,
    elevation: 10,
    type: BottomNavigationBarType.fixed,
    selectedLabelStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelStyle: const TextStyle(fontSize: 12),
  ),
);
