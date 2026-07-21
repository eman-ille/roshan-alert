import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_location.dart';

/// One recurring daily outage block, e.g. 5:00 PM – 7:00 PM.
/// Times are stored as "minutes since midnight" (0–1440) so comparing
/// against "now" is a plain integer comparison, no DateTime parsing.
class ScheduleBlock {
  final String id;
  final int startMinutes;
  final int endMinutes;

  const ScheduleBlock({
    required this.id,
    required this.startMinutes,
    required this.endMinutes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': startMinutes,
    'end': endMinutes,
  };

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) => ScheduleBlock(
    id: json['id'] as String,
    startMinutes: json['start'] as int,
    endMinutes: json['end'] as int,
  );

  String get timeRangeLabel =>
      '${_formatMinutes(startMinutes)} – ${_formatMinutes(endMinutes)}';

  static String _formatMinutes(int minutes) {
    final int h = (minutes ~/ 60) % 24;
    final int m = minutes % 60;
    final String period = h < 12 ? 'AM' : 'PM';
    int displayHour = h % 12;
    if (displayHour == 0) displayHour = 12;
    final String mm = m.toString().padLeft(2, '0');
    return '$displayHour:$mm $period';
  }
}

/// Single source of truth for the user's self-entered daily outage
/// schedule — this is data the USER provides (from experience or their
/// DISCO's notice), not anything the app claims to detect live.
///
/// Same shape as AppLocation: a ValueNotifier every screen can listen
/// to, backed by SharedPreferences for instant local persistence
/// (works offline, survives a web refresh), and mirrored to Firestore
/// under users/{uid} so it's not lost if the user switches devices.
class ScheduleStore {
  ScheduleStore._();

  static String _currentUtility() =>
      AppLocation.utility.value.isNotEmpty
          ? AppLocation.utility.value
          : 'Electricity';

  // Location slug used in Firestore field names so each area has its
  // own schedule. e.g. punjab_lahore_model_town
  static String _locationSlug() {
    final parts = [
      AppLocation.province ?? '',
      AppLocation.city ?? '',
      AppLocation.area ?? '',
    ].map((s) => s.toLowerCase().replaceAll(' ', '_')).join('_');
    return parts.isNotEmpty ? parts : 'default';
  }

  static String _firestoreField(String utility) =>
      'scheduleBlocks_${utility.toLowerCase()}_${_locationSlug()}';

  static String _prefsKey(String? uid, [String? utility]) {
    final utilKey = (utility ?? _currentUtility()).toLowerCase();
    final locSlug = _locationSlug();
    return uid != null && uid.isNotEmpty
        ? 'ra_schedule_blocks_${uid}_${locSlug}_$utilKey'
        : 'ra_schedule_blocks_${locSlug}_$utilKey';
  }

  static final ValueNotifier<List<ScheduleBlock>> blocks =
      ValueNotifier<List<ScheduleBlock>>(const []);

  static void reset() {
    blocks.value = const [];
  }

  /// Call once at app startup or after login or utility switch.
  static Future<void> restore([String? utility]) async {
    final activeUtility = utility ?? _currentUtility();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      blocks.value = const [];
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(uid, activeUtility));
    List<ScheduleBlock> localBlocks = [];
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw) as List;
        localBlocks = decoded
            .map((e) => ScheduleBlock.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      } catch (_) {}
    }

    // Set initial value from local cache immediately
    blocks.value = localBlocks;

    // Firestore is the cross-device source of truth when signed in.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final locField = _firestoreField(activeUtility);
      final remote = doc.data()?[locField] as List?;

      if (remote != null) {
        blocks.value =
            remote
                .map(
                  (e) => ScheduleBlock.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
              ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        await _saveLocal(uid, activeUtility);
      } else if (localBlocks.isNotEmpty) {
        // Sync local schedule to Firestore if remote doesn't have it yet
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          locField: localBlocks.map((b) => b.toJson()).toList(),
        }, SetOptions(merge: true));
      } else {
        blocks.value = const [];
        await _saveLocal(uid, activeUtility);
      }
    } catch (_) {
      // Offline: keep localBlocks
    }
  }

  static Future<void> addBlock(int startMinutes, int endMinutes) async {
    final updated = List<ScheduleBlock>.from(blocks.value)
      ..add(
        ScheduleBlock(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          startMinutes: startMinutes,
          endMinutes: endMinutes,
        ),
      )
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    blocks.value = updated;
    await _persist();
  }

  static Future<void> removeBlock(String id) async {
    blocks.value = blocks.value.where((b) => b.id != id).toList();
    await _persist();
  }

  static Future<void> _persist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final activeUtility = _currentUtility();
    await _saveLocal(uid, activeUtility);
    if (uid == null || uid.isEmpty) return;
    try {
      // Save under location-specific field so each area has its own
      // schedule in Firestore.
      final field = _firestoreField(activeUtility);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        field: blocks.value.map((b) => b.toJson()).toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Offline write failed
    }
  }

  static Future<void> _saveLocal(String? uid, String utility) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey(uid, utility),
      jsonEncode(blocks.value.map((b) => b.toJson()).toList()),
    );
  }

  // ---- Derived "now" state, computed from the user's own data ----
  // Deliberately named so callers can't mistake this for a live feed.

  static ScheduleBlock? currentBlockAt(DateTime time) {
    final int minutesNow = time.hour * 60 + time.minute;
    for (final block in blocks.value) {
      if (minutesNow >= block.startMinutes && minutesNow < block.endMinutes) {
        return block;
      }
    }
    return null;
  }

  static ScheduleBlock? nextBlockAfter(DateTime time) {
    final int minutesNow = time.hour * 60 + time.minute;
    final upcoming = blocks.value
        .where((b) => b.startMinutes > minutesNow)
        .toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return upcoming.first;
  }

  /// The next moment (as an absolute DateTime) at which any saved
  /// block starts or ends, coming strictly after [from]. Used to know
  /// when a self-reported status override has gone stale and the
  /// schedule should take back over. Returns null if there's no saved
  /// schedule at all.
  static DateTime? nextBoundaryAfter(DateTime from) {
    if (blocks.value.isEmpty) return null;

    final int fromMinutes = from.hour * 60 + from.minute;
    final Set<int> boundaryMinutes = {};
    for (final b in blocks.value) {
      boundaryMinutes.add(b.startMinutes % 1440);
      boundaryMinutes.add(b.endMinutes % 1440);
    }

    final sorted = boundaryMinutes.toList()..sort();
    final todayMidnight = DateTime(from.year, from.month, from.day);

    for (final m in sorted) {
      if (m > fromMinutes) {
        return todayMidnight.add(Duration(minutes: m));
      }
    }
    // Nothing left today — wrap to the earliest boundary tomorrow.
    return todayMidnight.add(Duration(days: 1, minutes: sorted.first));
  }
}
