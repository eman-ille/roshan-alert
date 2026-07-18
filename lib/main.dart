import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'Helping_Files/app_theme.dart';
import 'Helping_Files/app_location.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/onboarding_ui.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppLocation.restore();
  await AppThemeController.restore();

  // Ask Firebase whether a session is already saved on this device.
  final User? currentUser = await FirebaseAuth.instance
      .authStateChanges()
      .first;

  String initialRoute;
  if (currentUser == null || !currentUser.emailVerified) {
    initialRoute = '/login';
  } else if (!AppLocation.hasSavedAddress) {
    initialRoute = '/onboarding';
  } else {
    initialRoute = '/home';
  }

  runApp(RoshanAlertApp(initialRoute: initialRoute));
}

class RoshanAlertApp extends StatelessWidget {
  final String initialRoute;
  const RoshanAlertApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Roshan Alert',
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          darkTheme: appDarkTheme,
          themeMode: themeMode,
          initialRoute: initialRoute,
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/report': (context) => const ReportScreen(),
            '/schedule': (context) => const PlaceholderScreen(
              title: 'Schedule',
              icon: Icons.calendar_month_rounded,
            ),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
