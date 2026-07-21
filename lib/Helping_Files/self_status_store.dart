import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_location.dart';
import 'schedule_store.dart';

/// A single self-reported status, tied to the moment it was set.
class SelfStatusOverride {
  final String status; // 'out' | 'back'
  final DateTime setAt;

  const SelfStatusOverride({required this.status, required this.setAt});
}

/// The signed-in user's OWN self-reported status — scoped to a
/// specific (area, utility) pair, exactly the way ScheduleStore scopes
/// saved schedules.
///
/// This scoping is what makes "no saved schedule in this area → show
/// ON until I explicitly report" actually work: an override you
/// reported for Area A's Electricity must never leak into Area B's
/// Gas, or even Area B's Electricity. Switching area or utility always
/// reloads (or correctly finds nothing and clears) this from scratch
/// for the new context.
///
/// Exposed as a ValueNotifier — same pattern as ScheduleStore.blocks —
/// so any screen listening to it repaints automatically the moment
/// the context switch finishes loading, with no manual setState timing
/// required.
class UserStatusOverride {
  UserStatusOverride._();

  static String _locationSlug() {
    final parts = [
      AppLocation.province ?? '',
      AppLocation.city ?? '',
      AppLocation.area ?? '',
    ].map((s) => s.toLowerCase().replaceAll(' ', '_')).join('_');
    return parts.isNotEmpty ? parts : 'default';
  }

  static String _currentUtility() => AppLocation.utility.value.isNotEmpty
      ? AppLocation.utility.value
      : 'Electricity';

  static String _prefsKey(String uid, String utility) {
    final locSlug = _locationSlug();
    final utilKey = utility.toLowerCase();
    return uid.isNotEmpty
        ? 'ra_self_status_override_${uid}_${locSlug}_$utilKey'
        : 'ra_self_status_override_${locSlug}_$utilKey';
  }

  static String _firestoreField(String utility) =>
      'statusOverride_${utility.toLowerCase()}_${_locationSlug()}';

  /// The override for whatever (area, utility) is CURRENTLY active.
  /// Null means "no override — fall back to the saved schedule, or ON
  /// if there isn't one".
  static final ValueNotifier<SelfStatusOverride?> current =
      ValueNotifier<SelfStatusOverride?>(null);

  static bool get isActive => current.value != null;
  static bool get isOut => current.value?.status == 'out';

  static void reset() {
    current.value = null;
  }

  static Future<void> set(String newStatus, {String uid = ''}) async {
    final utility = _currentUtility();
    final entry = SelfStatusOverride(status: newStatus, setAt: DateTime.now());
    current.value = entry;
    await _save(uid: uid, utility: utility, entry: entry);

    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          _firestoreField(utility): {
            'status': entry.status,
            'setAt': entry.setAt.toIso8601String(),
          },
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static Future<void> clear({String uid = ''}) async {
    final utility = _currentUtility();
    current.value = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(uid, utility));

    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          _firestoreField(utility): FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Loads the override for whatever (area, utility) is currently
  /// active in AppLocation. Call at startup, AND any time area or
  /// utility changes (see `switchContext`, called from
  /// AppLocation.set()).
  static Future<void> restore({required String uid}) async {
    final utility = _currentUtility();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(uid, utility));

    SelfStatusOverride? loaded;
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final localStatus = data['status'] as String?;
        final setAtRaw = data['setAt'] as String?;
        final localSetAt = setAtRaw != null
            ? DateTime.tryParse(setAtRaw)
            : null;
        if (localStatus != null && localSetAt != null) {
          loaded = SelfStatusOverride(status: localStatus, setAt: localSetAt);
        }
      } catch (_) {}
    }

    current.value = loaded;

    if (uid.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final remoteData =
            doc.data()?[_firestoreField(utility)] as Map<String, dynamic>?;
        if (remoteData != null) {
          final remoteStatus = remoteData['status'] as String?;
          final remoteSetAtRaw = remoteData['setAt'] as String?;
          final remoteSetAt = remoteSetAtRaw != null
              ? DateTime.tryParse(remoteSetAtRaw)
              : null;

          if (remoteStatus != null &&
              remoteSetAt != null &&
              (loaded == null || remoteSetAt.isAfter(loaded.setAt))) {
            final entry = SelfStatusOverride(
              status: remoteStatus,
              setAt: remoteSetAt,
            );
            current.value = entry;
            await _save(uid: uid, utility: utility, entry: entry);
          }
        }
      } catch (_) {}
    }
  }

  /// Call whenever AppLocation's area or utility changes. Clears the
  /// in-memory override immediately — so there's no one-frame flash of
  /// the OLD area's status — then reloads whatever is actually saved
  /// for the NEW (area, utility) context. Usually that's nothing,
  /// which correctly falls back to ON / the saved schedule for the new
  /// area, instead of carrying over an unrelated area's report.
  static Future<void> switchContext({required String uid}) async {
    current.value = null;
    await restore(uid: uid);
  }

  /// Drops the override once the schedule has moved past the next
  /// on/off boundary that existed at the moment it was set. Safe to
  /// call on every clock tick — it's a no-op unless actually stale.
  static Future<void> clearIfStale(DateTime now, {String uid = ''}) async {
    final entry = current.value;
    if (entry == null) return;
    final boundary = ScheduleStore.nextBoundaryAfter(entry.setAt);
    if (boundary != null && !now.isBefore(boundary)) {
      await clear(uid: uid);
    }
  }

  static Future<void> _save({
    required String uid,
    required String utility,
    required SelfStatusOverride entry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey(uid, utility),
      jsonEncode({
        'status': entry.status,
        'setAt': entry.setAt.toIso8601String(),
      }),
    );
  }
}
