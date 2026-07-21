import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule_store.dart';

/// The signed-in user's OWN self-reported status.
///
/// Set the instant they submit a report on Report screen, or tap
/// "True" on someone else's crowd card. Purely local to this account —
/// it changes THIS user's Home screen immediately and never affects
/// anyone else's, and nobody else's report ever changes it for them
/// without their own true/false tap.
///
/// Persists until the next scheduled outage boundary after it was
/// set — at that point the saved schedule takes back over, since the
/// override is only ever a claim about "right now", not a permanent
/// replacement for the schedule.
class UserStatusOverride {
  UserStatusOverride._();

  static const _key = 'ra_self_status_override';

  static String? status; // 'out' | 'back' | null
  static DateTime? setAt;

  static bool get isActive => status != null;

  static bool get isOut => status == 'out';

  static Future<void> set(String newStatus, {String uid = ''}) async {
    status = newStatus;
    setAt = DateTime.now();
    await _save(uid: uid);

    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'statusOverride': {
            'status': status,
            'setAt': setAt?.toIso8601String(),
          },
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static Future<void> clear({String uid = ''}) async {
    status = null;
    setAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);

    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'statusOverride': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Restores the override from local storage and syncs with Firestore
  /// so it persists across logouts, different devices, and tab refreshes.
  static Future<void> restore({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedUid = data['uid'] as String?;
        if (savedUid == uid) {
          status = data['status'] as String?;
          final setAtRaw = data['setAt'] as String?;
          setAt = setAtRaw != null ? DateTime.tryParse(setAtRaw) : null;
        } else {
          status = null;
          setAt = null;
        }
      } catch (_) {}
    }

    if (uid.isNotEmpty) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final remoteData =
            doc.data()?['statusOverride'] as Map<String, dynamic>?;
        if (remoteData != null) {
          final remoteStatus = remoteData['status'] as String?;
          final remoteSetAtRaw = remoteData['setAt'] as String?;
          final remoteSetAt =
              remoteSetAtRaw != null ? DateTime.tryParse(remoteSetAtRaw) : null;

          if (remoteSetAt != null) {
            if (setAt == null || remoteSetAt.isAfter(setAt!)) {
              status = remoteStatus;
              setAt = remoteSetAt;
              await _save(uid: uid);
            }
          }
        }
      } catch (_) {}
    }
  }

  /// Drops the override once the schedule has moved past the next
  /// on/off boundary that existed at the moment it was set. Safe to
  /// call on every clock tick — it's a no-op unless actually stale.
  static Future<void> clearIfStale(DateTime now, {String uid = ''}) async {
    if (setAt == null) return;
    final boundary = ScheduleStore.nextBoundaryAfter(setAt!);
    if (boundary != null && !now.isBefore(boundary)) {
      await clear(uid: uid);
    }
  }

  static Future<void> _save({String uid = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'uid': uid,
        'status': status,
        'setAt': setAt?.toIso8601String(),
      }),
    );
  }
}
