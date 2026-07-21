import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_store.dart';

/// Single source of truth for the user's currently selected location
/// AND utility type (Electricity / Gas), picked once during onboarding.
///
/// Any screen displays it with a ValueListenableBuilder — LocationRow
/// already does this for `current` — so it updates everywhere the
/// moment it changes. No passing data between screens via Navigator
/// arguments anywhere in the app.
///
/// Backed by AddressStore for instant local persistence (survives a
/// page refresh on web or an app restart on mobile), AND mirrored to
/// Firestore under users/{uid} — same pattern as ScheduleStore — so a
/// returning user never sees onboarding again just because they're on
/// a new device or reinstalled the app: their saved address follows
/// their account, not just the device.
class AppLocation {
  AppLocation._();

  static final ValueNotifier<String> current = ValueNotifier<String>(
    'Lahore — DHA Phase 5', // placeholder shown only before onboarding/restore
  );

  static final ValueNotifier<String> utility = ValueNotifier<String>(
    'Electricity',
  );

  static String? province;
  static String? city;
  static String? area;

  static bool get hasSavedAddress =>
      province != null && city != null && area != null;

  static void reset() {
    province = null;
    city = null;
    area = null;
    current.value = 'Lahore — DHA Phase 5';
    utility.value = 'Electricity';
  }

  /// Called from onboarding (first time) OR Settings (to switch area
  /// later — this is a deliberate account action, never onboarding).
  /// Updates the live notifiers (so every screen using LocationRow
  /// updates instantly), persists locally, AND syncs to Firestore so
  /// it's tied to the account, not just this device.
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'address': {
          'utility': utility,
          'province': province,
          'city': city,
          'area': area,
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline — local copy above already saved, nothing lost. It'll
      // sync next time restoreFromCloudIfNeeded/set runs and Firestore
      // is reachable.
    }
  }

  /// Called once at app startup (before runApp) to restore a
  /// previously saved address from THIS device's local cache, so a
  /// page refresh on web — or a fresh app launch on mobile — shows the
  /// right location immediately instead of falling back to the
  /// placeholder above.
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

  /// Called at startup right after sign-in is confirmed, ONLY if the
  /// local cache above came up empty (new device, reinstall, cleared
  /// storage). Falls back to whatever address is saved under this
  /// account in Firestore, so a returning user is never sent to
  /// onboarding a second time just because of the device they're on.
  static Future<void> restoreFromCloudIfNeeded(String uid) async {
    if (hasSavedAddress) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final address = doc.data()?['address'] as Map<String, dynamic>?;
      if (address == null) return;

      final savedUtility = address['utility'] as String?;
      final savedProvince = address['province'] as String?;
      final savedCity = address['city'] as String?;
      final savedArea = address['area'] as String?;
      if (savedProvince == null || savedCity == null || savedArea == null) {
        return;
      }

      await set(
        utility: savedUtility ?? 'Electricity',
        province: savedProvince,
        city: savedCity,
        area: savedArea,
      );
    } catch (_) {
      // Offline or some other error — fall back to onboarding rather
      // than blocking app startup; nothing is lost, this just re-runs
      // next launch.
    }
  }
}
