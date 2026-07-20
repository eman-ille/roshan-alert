import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A report the user just submitted from Report screen, waiting on
/// Home for that SAME account to confirm it's actually true before it
/// is written anywhere permanent.
class PendingReport {
  final String status; // 'out' or 'back'
  final String utility;
  final String? province;
  final String? city;
  final String? area;
  final String locationKey;
  final int secondsLeft;
  final bool resolving;

  const PendingReport({
    required this.status,
    required this.utility,
    required this.province,
    required this.city,
    required this.area,
    required this.locationKey,
    required this.secondsLeft,
    this.resolving = false,
  });

  bool get isOut => status == 'out';

  PendingReport copyWith({int? secondsLeft, bool? resolving}) {
    return PendingReport(
      status: status,
      utility: utility,
      province: province,
      city: city,
      area: area,
      locationKey: locationKey,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      resolving: resolving ?? this.resolving,
    );
  }
}

/// Global "pending self-report" store.
///
/// IMPORTANT: this owns the report, the countdown, AND the confirm/
/// revert actions itself — none of it lives inside HomeScreen's State.
/// The app's bottom nav switches tabs with pushReplacementNamed, which
/// tears down and recreates HomeScreen on every tap, so anything kept
/// in HomeScreen's own State (timers, fields) can be lost mid-preview.
/// A plain static store has no such lifecycle, so Home can just render
/// whatever's here right now via ValueListenableBuilder, no matter how
/// many times it's been rebuilt in between.
class PendingReportStore {
  PendingReportStore._();

  static const int previewSeconds = 8;

  static final ValueNotifier<PendingReport?> pending =
      ValueNotifier<PendingReport?>(null);

  static Timer? _countdown;

  /// Called from Report screen right after the user taps Submit.
  static void submit({
    required String status,
    required String utility,
    required String? province,
    required String? city,
    required String? area,
    required String locationKey,
  }) {
    _countdown?.cancel();
    pending.value = PendingReport(
      status: status,
      utility: utility,
      province: province,
      city: city,
      area: area,
      locationKey: locationKey,
      secondsLeft: previewSeconds,
    );
    _startCountdown();
  }

  static void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = pending.value;
      if (current == null || current.resolving) {
        timer.cancel();
        return;
      }
      if (current.secondsLeft <= 1) {
        timer.cancel();
        // Ran out the clock without an answer — treat as unconfirmed.
        revert();
      } else {
        pending.value = current.copyWith(secondsLeft: current.secondsLeft - 1);
      }
    });
  }

  /// "No, revert" — or the countdown running out. Discards the preview;
  /// nothing is ever written to Firestore.
  static void revert() {
    _countdown?.cancel();
    pending.value = null;
  }

  /// "Yes, it's true" — writes the report for real so other users in
  /// the area see it too. Throws on failure so the caller can show its
  /// own error message; the preview stays up so the user can retry.
  static Future<void> confirm() async {
    final report = pending.value;
    if (report == null || report.resolving) return;

    _countdown?.cancel();
    pending.value = report.copyWith(resolving: true);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'status': report.status, // 'out' or 'back'
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'province': report.province,
        'city': report.city,
        'area': report.area,
        'utility': report.utility,
        'locationKey': report.locationKey,
        'createdAt': FieldValue.serverTimestamp(),
      });
      pending.value = null;
    } catch (e) {
      pending.value = report.copyWith(resolving: false);
      rethrow;
    }
  }
}
