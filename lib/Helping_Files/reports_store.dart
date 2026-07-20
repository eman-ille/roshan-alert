import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_location.dart';

/// A single crowd report, trimmed down to what Home needs to display.
class AreaReport {
  final String status; // 'out' or 'back'
  final DateTime reportedAt;

  const AreaReport({required this.status, required this.reportedAt});

  bool get isOut => status == 'out';

  Duration ageFrom(DateTime now) => now.difference(reportedAt);
}

/// Watches the most recent report for the signed-in user's saved
/// area + utility, so Home can show real crowd signal instead of only
/// the self-entered schedule. A report is only considered "current"
/// for [recentWindow] — after that we fall back to the schedule guess,
/// since a report from 4 hours ago says nothing about right now.
class ReportsStore {
  ReportsStore._();

  static const recentWindow = Duration(minutes: 60);

  /// Builds the same locationKey used when writing a report, so the
  /// write side (report_screen.dart) and read side always agree on
  /// what "this area" means without needing a 4-field composite index.
  static String locationKeyFor({
    required String? province,
    required String? city,
    required String? area,
    required String utility,
  }) => '${province ?? ''}|${city ?? ''}|${area ?? ''}|$utility';

  static Stream<AreaReport?> watchLatestForCurrentArea(String utility) {
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
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final data = snapshot.docs.first.data();
          final ts = data['createdAt'];
          if (ts is! Timestamp) {
            // createdAt hasn't been written by the server yet (the
            // FieldValue.serverTimestamp() placeholder briefly reads
            // as null on the submitting client) — skip until it has.
            return null;
          }
          return AreaReport(
            status: (data['status'] as String?) ?? '',
            reportedAt: ts.toDate(),
          );
        });
  }
}
