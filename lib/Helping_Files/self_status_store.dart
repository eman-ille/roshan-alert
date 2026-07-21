import 'dart:convert';
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

  static Future<void> set(String newStatus) async {
    status = newStatus;
    setAt = DateTime.now();
    await _save();
  }

  static Future<void> clear() async {
    status = null;
    setAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Call once at app startup, same timing as AppLocation.restore().
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    status = data['status'] as String?;
    final setAtRaw = data['setAt'] as String?;
    setAt = setAtRaw != null ? DateTime.tryParse(setAtRaw) : null;
  }

  /// Drops the override once the schedule has moved past the next
  /// on/off boundary that existed at the moment it was set. Safe to
  /// call on every clock tick — it's a no-op unless actually stale.
  static Future<void> clearIfStale(DateTime now) async {
    if (setAt == null) return;
    final boundary = ScheduleStore.nextBoundaryAfter(setAt!);
    if (boundary != null && !now.isBefore(boundary)) {
      await clear();
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({'status': status, 'setAt': setAt?.toIso8601String()}),
    );
  }
}
