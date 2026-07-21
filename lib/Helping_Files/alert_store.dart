import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Single source of truth for the user's Alert & Notification Preferences.
class AlertStore {
  AlertStore._();

  static const _prefsKey = 'ra_alert_preferences';

  static final ValueNotifier<bool> masterEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> powerAlerts = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> gasAlerts = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> scheduleReminders = ValueNotifier<bool>(true);

  static void reset() {
    masterEnabled.value = true;
    powerAlerts.value = true;
    gasAlerts.value = true;
    scheduleReminders.value = true;
  }

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        masterEnabled.value = (data['masterEnabled'] as bool?) ?? true;
        powerAlerts.value = (data['powerAlerts'] as bool?) ?? true;
        gasAlerts.value = (data['gasAlerts'] as bool?) ?? true;
        scheduleReminders.value = (data['scheduleReminders'] as bool?) ?? true;
      } catch (_) {}
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final prefsData = doc.data()?['alertPreferences'] as Map<String, dynamic>?;
      if (prefsData != null) {
        masterEnabled.value = (prefsData['masterEnabled'] as bool?) ?? true;
        powerAlerts.value = (prefsData['powerAlerts'] as bool?) ?? true;
        gasAlerts.value = (prefsData['gasAlerts'] as bool?) ?? true;
        scheduleReminders.value = (prefsData['scheduleReminders'] as bool?) ?? true;
        await _saveLocal();
      }
    } catch (_) {}
  }

  static Future<void> setMaster(bool value) async {
    masterEnabled.value = value;
    await _persist();
  }

  static Future<void> setPower(bool value) async {
    powerAlerts.value = value;
    await _persist();
  }

  static Future<void> setGas(bool value) async {
    gasAlerts.value = value;
    await _persist();
  }

  static Future<void> setScheduleReminders(bool value) async {
    scheduleReminders.value = value;
    await _persist();
  }

  static Future<void> _persist() async {
    await _saveLocal();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'alertPreferences': {
          'masterEnabled': masterEnabled.value,
          'powerAlerts': powerAlerts.value,
          'gasAlerts': gasAlerts.value,
          'scheduleReminders': scheduleReminders.value,
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'masterEnabled': masterEnabled.value,
        'powerAlerts': powerAlerts.value,
        'gasAlerts': gasAlerts.value,
        'scheduleReminders': scheduleReminders.value,
      }),
    );
  }

  static bool isAlertEnabledForUtility(String utility) {
    if (!masterEnabled.value) return false;
    if (utility.toLowerCase() == 'gas') {
      return gasAlerts.value;
    }
    return powerAlerts.value;
  }
}
