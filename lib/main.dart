import 'package:flutter/material.dart';
import 'Helping_Files/app_theme.dart';
import 'Helping_Files/app_location.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/onboarding_ui.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore any previously saved address BEFORE the first frame builds.
  // This is what makes a page refresh (web) or a fresh app launch show
  // the real address immediately, instead of the onboarding flow or a
  // hardcoded placeholder flashing first.
  await AppLocation.restore();

  runApp(RoshanAlertApp(hasSavedAddress: AppLocation.hasSavedAddress));
}

class RoshanAlertApp extends StatelessWidget {
  final bool hasSavedAddress;
  const RoshanAlertApp({super.key, required this.hasSavedAddress});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roshan Alert',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // defined once in app_theme.dart
      // Skip onboarding for anyone who already has a saved address —
      // a returning user, or simply a page refresh on Home/Report.
      initialRoute: hasSavedAddress ? '/home' : '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
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
        '/settings': (context) => const SettingsScreen(
          
          
        ),
      },
    );
  }
}