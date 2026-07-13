import 'package:flutter/foundation.dart';

/// Single source of truth for the user's currently selected location.
///
/// Any screen can display it with a ValueListenableBuilder (see
/// home_screen.dart's header for an example) so it updates everywhere
/// automatically the moment it changes — no passing data between screens.
///
/// When the real location-picker (in Settings, per the "Choose location
/// by Province / City / Area" flow) is built, it just does:
///   AppLocation.current.value = 'Lahore — Area 3';
/// and every screen showing the location updates on its own.
class AppLocation {
  AppLocation._();

  static final ValueNotifier<String> current = ValueNotifier<String>(
    'Lahore — DHA Phase 5',
  );
}
