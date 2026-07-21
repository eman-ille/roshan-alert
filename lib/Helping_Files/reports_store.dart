import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_location.dart';

class _LatestReport {
  final String uid;
  final String status;
  final DateTime at;
  const _LatestReport({
    required this.uid,
    required this.status,
    required this.at,
  });
}

/// How many OTHER users in the area recently reported a given status,
/// and which status that is. Shown to everyone else as "X user(s) in
/// your area say power is back/out", with a true/false toggle.
class CrowdSignal {
  final String status; // 'out' or 'back'
  final int userCount; // distinct OTHER accounts reporting this status
  final DateTime latestAt;
  // Exactly which accounts make up userCount — lets the UI do its own
  // independent "is this actually someone else?" check right before
  // rendering, instead of trusting the query filter alone.
  final Set<String> reporterUids;
  final bool hasCurrentUserReported;

  const CrowdSignal({
    required this.status,
    required this.userCount,
    required this.latestAt,
    required this.reporterUids,
    required this.hasCurrentUserReported,
  });

  bool get isOut => status == 'out';

  bool includesAccount(String uid) => reporterUids.contains(uid);
}

/// Reads/writes crowd reports for the signed-in user's saved area +
/// utility.
///
/// Every report is just a row: who reported what, when, where. There's
/// no separate "confirmed" flag on a report — a user's OWN status is
/// always theirs alone, set instantly the moment they report on
/// Report screen, or the moment they tap "True" on someone else's
/// crowd card (which itself just submits another row under their own
/// uid — see UserStatusOverride for where that gets displayed). Other
/// users only ever see a live count of how many distinct people
/// nearby reported the same thing recently; that count IS the "area-
/// based user counts and verification responses" data model — each
/// true-tap adds a new row, which is itself a verification response.
class ReportsStore {
  ReportsStore._();

  /// How far back a report still counts toward the crowd signal.
  static const recentWindow = Duration(minutes: 90);

  static String locationKeyFor({
    required String? province,
    required String? city,
    required String? area,
    required String utility,
  }) {
    final p = (province == null || province.trim().isEmpty)
        ? 'punjab'
        : province.trim().toLowerCase();
    final c = (city == null || city.trim().isEmpty)
        ? 'lahore'
        : city.trim().toLowerCase();
    final a = (area == null || area.trim().isEmpty)
        ? 'dha phase 5'
        : area.trim().toLowerCase();
    final u = utility.trim().isEmpty
        ? 'electricity'
        : utility.trim().toLowerCase();
    return '$p|$c|$a|$u';
  }

  /// Writes one report row. Used both for the Report screen's Submit
  /// button AND for a "True" tap on someone else's crowd card — either
  /// way, it's this account saying "I'm seeing this too".
  static Future<void> submitReport({
    required String status,
    required String reporterUid,
    required String? province,
    required String? city,
    required String? area,
    required String utility,
  }) async {
    final locationKey = locationKeyFor(
      province: province,
      city: city,
      area: area,
      utility: utility,
    );

    await FirebaseFirestore.instance.collection('reports').add({
      'status': status, // 'out' or 'back'
      'reporterUid': reporterUid,
      'province': province ?? 'Punjab',
      'city': city ?? 'Lahore',
      'area': area ?? 'DHA Phase 5',
      'utility': utility,
      'locationKey': locationKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// The crowd signal for the CURRENT user's area — what OTHER
  /// accounts nearby have been reporting recently, with a live count.
  /// Null once nobody else has reported anything recent, or this
  /// account has no saved area yet.
  static Stream<CrowdSignal?> watchCrowdSignal({
    required String utility,
    required String currentUid,
  }) {
    final key = locationKeyFor(
      province: AppLocation.province,
      city: AppLocation.city,
      area: AppLocation.area,
      utility: utility,
    );

    return FirebaseFirestore.instance
        .collection('reports')
        .where('locationKey', isEqualTo: key)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final cutoff = DateTime.now().subtract(recentWindow);
          final Map<String, _LatestReport> latestByUid = {};
          final Set<String> currentUserReportedStatuses = {};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final uid = data['reporterUid'] as String?;
            final ts = data['createdAt'];
            final DateTime at =
                (ts is Timestamp) ? ts.toDate() : DateTime.now();

            if (at.isBefore(cutoff)) continue;
            if (uid == null || uid.isEmpty) continue;

            final docStatus = (data['status'] as String?) ?? '';
            if (docStatus.isEmpty) continue;

            if (currentUid.isNotEmpty && uid == currentUid) {
              currentUserReportedStatuses.add(docStatus);
              continue; // don't count self in crowd totals
            }

            final existing = latestByUid[uid];
            if (existing == null || at.isAfter(existing.at)) {
              latestByUid[uid] = _LatestReport(
                uid: uid,
                status: docStatus,
                at: at,
              );
            }
          }
          if (latestByUid.isEmpty) return null;

          final Map<String, int> counts = {};
          final Map<String, DateTime> latestPerStatus = {};
          final Map<String, Set<String>> uidsPerStatus = {};
          for (final r in latestByUid.values) {
            if (r.status.isEmpty) continue;
            counts[r.status] = (counts[r.status] ?? 0) + 1;
            uidsPerStatus.putIfAbsent(r.status, () => <String>{}).add(r.uid);
            final existing = latestPerStatus[r.status];
            if (existing == null || r.at.isAfter(existing)) {
              latestPerStatus[r.status] = r.at;
            }
          }
          if (counts.isEmpty) return null;

          String leadingStatus = counts.keys.first;
          for (final candidate in counts.keys) {
            final candidateCount = counts[candidate]!;
            final leadingCount = counts[leadingStatus]!;
            final candidateNewer = latestPerStatus[candidate]!.isAfter(
              latestPerStatus[leadingStatus]!,
            );
            if (candidateCount > leadingCount ||
                (candidateCount == leadingCount && candidateNewer)) {
              leadingStatus = candidate;
            }
          }

          final DateTime signalTime = latestPerStatus[leadingStatus]!;
          final bool hasCurrentUserReported =
              currentUserReportedStatuses.contains(leadingStatus);

          return CrowdSignal(
            status: leadingStatus,
            userCount: counts[leadingStatus]!,
            latestAt: signalTime,
            reporterUids: uidsPerStatus[leadingStatus]!,
            hasCurrentUserReported: hasCurrentUserReported,
          );
        });
  }
}
