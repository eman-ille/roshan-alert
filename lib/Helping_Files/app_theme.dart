import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  AppColors._();

  static const Color black = Color(0xFF111111);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE3E3E6);
  static const Color grey = Color(0xFF767676);
  static const Color trackGrey = Color(0xFFEDEDED);
}

class AppRadius {
  AppRadius._();

  static const double small = 10;
  static const double medium = 14;
  static const double large = 18;
}

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
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.black;
      return AppColors.white;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.black.withOpacity(0.4);
      }
      return AppColors.trackGrey;
    }),
    trackOutlineColor: WidgetStateProperty.all(AppColors.grey),
  ),
);

final ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.white,
    primary: AppColors.white,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF121212),
    foregroundColor: AppColors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.white,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.black,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: AppColors.white,
    unselectedItemColor: Colors.grey.shade600,
    backgroundColor: const Color(0xFF1A1A1A),
    elevation: 10,
    type: BottomNavigationBarType.fixed,
    selectedLabelStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelStyle: const TextStyle(fontSize: 12),
  ),
  switchTheme: SwitchThemeData(
    // NOTE: AppCard renders white regardless of ThemeMode (see the
    // Settings screenshot — cards stay white even with Dark Mode on).
    // The previous colors made the selected thumb/track pure white,
    // which is invisible against a white card. Mirroring appTheme's
    // switch colors (dark thumb/track when selected) keeps the toggle
    // visible in both modes.
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.black;
      return AppColors.white;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.black.withOpacity(0.4);
      }
      return AppColors.trackGrey;
    }),
    trackOutlineColor: WidgetStateProperty.all(AppColors.grey),
  ),
);

/// Single source of truth for the app's current ThemeMode. Any widget
/// can read AppThemeController.mode with a ValueListenableBuilder to
/// react instantly when it changes — same pattern as AppLocation.
class AppThemeController {
  AppThemeController._();

  static const _key = 'ra_theme_mode';

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  /// Call once at app startup, before runApp(), same as AppLocation.restore().
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    mode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle(bool isDark) async {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }
}
