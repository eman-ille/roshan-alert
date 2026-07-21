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
  }) => '${province ?? ''}|${city ?? ''}|${area ?? ''}|$utility';

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
      'province': province,
      'city': city,
      'area': area,
      'utility': utility,
      'locationKey': locationKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// The crowd signal for the CURRENT user's area — what OTHER
  /// accounts nearby have been reporting recently, with a live count.
  /// Null once nobody else has reported anything recent, or this
  /// account has no saved area yet.
  ///
  /// NOTE: this needs a composite Firestore index on
  /// (locationKey ASC, createdAt DESC). The first time it runs,
  /// Firestore's error message includes a direct link to auto-create
  /// it in the console — just click it.
  static Stream<CrowdSignal?> watchCrowdSignal({
    required String utility,
    required String currentUid,
  }) {
    if (!AppLocation.hasSavedAddress) return Stream.value(null);

    final key = locationKeyFor(
      province: AppLocation.province,
      city: AppLocation.city,
      area: AppLocation.area,
      utility: utility,
    );
    final cutoff = DateTime.now().subtract(recentWindow);

    return FirebaseFirestore.instance
        .collection('reports')
        .where('locationKey', isEqualTo: key)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          bool hasCurrentUserReported = false;
          // Keep only each OTHER reporter's most recent row (docs are
          // already newest-first), so one chatty account can't inflate
          // the count, and current-user's own rows never count.
          final Map<String, _LatestReport> latestByUid = {};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final uid = data['reporterUid'] as String?;
            if (uid != null && uid.isNotEmpty && uid == currentUid) {
              hasCurrentUserReported = true;
            }
            if (uid == null || uid.isEmpty || uid == currentUid) continue;
            if (latestByUid.containsKey(uid)) continue;

            final ts = data['createdAt'];
            if (ts is! Timestamp) continue;

            latestByUid[uid] = _LatestReport(
              uid: uid,
              status: (data['status'] as String?) ?? '',
              at: ts.toDate(),
            );
          }
          if (latestByUid.isEmpty) return null;

          // Whichever status the most distinct reporters are
          // currently saying wins; ties go to whichever is more recent.
          final Map<String, int> counts = {};
          final Map<String, DateTime> latestPerStatus = {};
          final Map<String, Set<String>> uidsPerStatus = {};
          for (final r in latestByUid.values) {
            counts[r.status] = (counts[r.status] ?? 0) + 1;
            uidsPerStatus.putIfAbsent(r.status, () => <String>{}).add(r.uid);
            final existing = latestPerStatus[r.status];
            if (existing == null || r.at.isAfter(existing)) {
              latestPerStatus[r.status] = r.at;
            }
          }

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

          return CrowdSignal(
            status: leadingStatus,
            userCount: counts[leadingStatus]!,
            latestAt: latestPerStatus[leadingStatus]!,
            reporterUids: uidsPerStatus[leadingStatus]!,
            hasCurrentUserReported: hasCurrentUserReported,
          );
        });
  }
}
