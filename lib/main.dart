import 'package:flutter/material.dart';
import 'Helping_Files/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/placeholder_screen.dart';

void main() {
  runApp(const RoshanAlertApp());
}

class RoshanAlertApp extends StatelessWidget {
  const RoshanAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roshan Alert',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // defined once in app_theme.dart
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomeScreen(),
        '/report': (context) => const ReportScreen(),

        // Not built yet — swap these two lines for the real screens
        // (e.g. ScheduleScreen(), SettingsScreen()) when ready.
        // Nothing else in the app needs to change — the bottom nav
        // figures out which tab is active from the route itself.
        '/schedule': (context) => const PlaceholderScreen(
          title: 'Schedule',
          icon: Icons.calendar_month_rounded,
        ),
        '/settings': (context) => const PlaceholderScreen(
          title: 'Settings',
          icon: Icons.settings_rounded,
        ),
      },
    );
  }
}
