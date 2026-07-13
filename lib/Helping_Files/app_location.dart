import 'package:flutter/foundation.dart';
import 'address_store.dart';

/// Single source of truth for the user's currently selected location
/// AND utility type (Electricity / Gas), picked once during onboarding.
///
/// Any screen displays it with a ValueListenableBuilder — LocationRow
/// already does this for `current` — so it updates everywhere the
/// moment it changes. No passing data between screens via Navigator
/// arguments anywhere in the app.
///
/// Backed by AddressStore so the value survives a page refresh (web)
/// or app restart (mobile). Call AppLocation.restore() once at app
/// startup, before runApp(), to load any previously saved address.
class AppLocation {
  AppLocation._();

  static final ValueNotifier<String> current = ValueNotifier<String>(
    'Lahore — DHA Phase 5', // placeholder shown only before onboarding/restore
  );

  static final ValueNotifier<String> utility = ValueNotifier<String>(
    'Electricity',
  );

  // Raw components, kept individually in case a screen needs them later
  // (e.g. pre-filling the onboarding dropdowns if you add an "edit
  // address" flow in Settings).
  static String? province;
  static String? city;
  static String? area;

  static bool get hasSavedAddress =>
      province != null && city != null && area != null;

  /// Called once, from onboarding, after the user finishes picking
  /// their address. Updates the live notifiers (so every screen using
  /// LocationRow updates instantly) AND persists to local storage.
  static Future<void> set({
    required String utility,
    required String province,
    required String city,
    required String area,
  }) async {
    AppLocation.province = province;
    AppLocation.city = city;
    AppLocation.area = area;
    AppLocation.utility.value = utility;
    AppLocation.current.value = '$area, $city';

    await AddressStore.save({
      'utility': utility,
      'province': province,
      'city': city,
      'area': area,
    });
  }

  /// Called once at app startup (before runApp) to restore a
  /// previously saved address, so a page refresh on web — or a fresh
  /// app launch on mobile — shows the right location immediately
  /// instead of falling back to the placeholder above.
  static Future<void> restore() async {
    final saved = await AddressStore.load();
    if (saved == null) return;

    province = saved['province'] as String?;
    city = saved['city'] as String?;
    area = saved['area'] as String?;
    utility.value = (saved['utility'] as String?) ?? 'Electricity';

    if (area != null && city != null) {
      current.value = '$area, $city';
    }
  }
}