import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'Helping_Files/app_theme.dart';
import 'Helping_Files/app_location.dart';
import 'Helping_Files/schedule_store.dart';
import 'Helping_Files/self_status_store.dart';
import 'Helping_Files/alert_store.dart';
import 'Helping_Files/alert_notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/onboarding_ui.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AlertNotificationService.initLocalNotifications();
  await AppLocation.restore();
  await AppThemeController.restore();
  await ScheduleStore.restore();
  await AlertStore.restore();

  // Wait for Firebase to fully resolve auth state from storage.
  final User? currentUser = await FirebaseAuth.instance
      .authStateChanges()
      .first;

  String initialRoute;
  if (currentUser == null || !currentUser.emailVerified) {
    initialRoute = '/login';
  } else {
    // Always restore the override for the logged-in user.
    await UserStatusOverride.restore(uid: currentUser.uid);

    // Local cache came up empty — could just mean a new device or a
    // reinstall, not a first-ever login. Check whether this ACCOUNT
    // already has an address saved in Firestore before sending them
    // to onboarding again.
    if (!AppLocation.hasSavedAddress) {
      await AppLocation.restoreFromCloudIfNeeded(currentUser.uid);
      await ScheduleStore.restore();
    }
    initialRoute = AppLocation.hasSavedAddress ? '/home' : '/onboarding';
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
            '/schedule': (context) => const ScheduleScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
