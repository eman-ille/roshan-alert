import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/location_row.dart';
import '/Helping_Files/logo_badge.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/app_location.dart';
import '/Helping_Files/schedule_store.dart';
import '/Helping_Files/reports_store.dart';
import '/Helping_Files/self_status_store.dart';
import '/Helping_Files/alert_store.dart';
import '/Helping_Files/alert_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  String? _lastAlertedCrowdKey;

  // Guards against alerting on the first snapshot of a fresh
  // subscription (which may just be old/stale reports already sitting
  // in the recent window) — we only want to alert on genuinely NEW
  // signals that arrive after we've already seen the current state.
  bool _crowdStreamPrimed = false;

  StreamSubscription<CrowdSignal?>? _crowdSub;
  String? _crowdSubKey;

  StreamSubscription<User?>? _authSub;

  void _reconnectCrowdStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return; // Wait for Firebase Auth to resolve

    final utility = AppLocation.utility.value;
    final province = AppLocation.province ?? '';
    final city = AppLocation.city ?? '';
    final area = AppLocation.area ?? '';
    final subKey = '$province|$city|$area|$utility|$uid';

    if (_crowdSubKey == subKey && _crowdSub != null) return;
    _crowdSubKey = subKey;

    // Fresh subscription (new area/utility/user) means a fresh
    // priming state — don't carry over the old key.
    _crowdStreamPrimed = false;
    _lastAlertedCrowdKey = null;

    _crowdSub?.cancel();
    _crowdSub = ReportsStore.watchCrowdSignal(utility: utility, currentUid: uid)
        .listen(
          (signal) {
            if (!mounted) return;

            final String? currentKey = (signal != null && signal.userCount > 0)
                ? '${signal.status}-'
                      '${(signal.reporterUids.toList()..sort()).join(',')}'
                : null;

            // First snapshot after (re)connecting: just record the
            // current state silently, don't alert on it. This avoids
            // popping a banner for a report that's been sitting there
            // for a while and isn't actually new news.
            if (!_crowdStreamPrimed) {
              _crowdStreamPrimed = true;
              _lastAlertedCrowdKey = currentKey;
              return;
            }

            if (signal != null &&
                signal.userCount > 0 &&
                currentKey != _lastAlertedCrowdKey) {
              _lastAlertedCrowdKey = currentKey;
              final String statusText = signal.isOut ? 'is OFF' : 'is ON';
              final String userPrefix = signal.userCount == 1
                  ? 'A user reported'
                  : '${signal.userCount} users reported';

              WidgetsBinding.instance.addPostFrameCallback((_) {
                AlertNotificationService.showAlert(
                  title: '🚨 Roshan Alert',
                  message: '$userPrefix $utility $statusText',
                  utility: utility,
                );
              });
            }
          },
          onError: (_) {
            // Guard against network/stream exception
          },
        );
  }

  @override
  void initState() {
    super.initState();

    _reconnectCrowdStream();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _reconnectCrowdStream();
    });

    AppLocation.utility.addListener(_reconnectCrowdStream);
    AppLocation.current.addListener(_reconnectCrowdStream);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await UserStatusOverride.restore(uid: uid);
      await UserStatusOverride.clearIfStale(DateTime.now(), uid: uid);
      await AlertStore.restore();
      if (mounted) setState(() {});
    });

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await UserStatusOverride.clearIfStale(DateTime.now(), uid: uid);
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    AppLocation.utility.removeListener(_reconnectCrowdStream);
    AppLocation.current.removeListener(_reconnectCrowdStream);
    _authSub?.cancel();
    _crowdSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  /// Formats a span of minutes as hours+minutes once it's over an hour
  /// (e.g. 90 -> "1h 30m", 60 -> "1h", 45 -> "45 min"), instead of ever
  /// showing a raw three-digit minute count or a decimal-hours value.
  /// Used everywhere on this screen a duration/countdown is shown.
  String _formatDurationMinutes(int minutes) {
    final int totalMinutes = minutes < 0 ? 0 : minutes;
    if (totalMinutes < 60) return '$totalMinutes min';
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  void _goToReport(BuildContext context) {
    Navigator.pushNamed(context, '/report');
  }

  void _goToSchedule(BuildContext context) {
    Navigator.pushNamed(context, '/schedule');
  }

  @override
  Widget build(BuildContext context) {
    final onBackground = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<List<ScheduleBlock>>(
          valueListenable: ScheduleStore.blocks,
          builder: (context, blocks, _) {
            return ValueListenableBuilder<String>(
              valueListenable: AppLocation.utility,
              builder: (context, utility, _) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(onBackground),
                          const SizedBox(height: 28),
                          ValueListenableBuilder<SelfStatusOverride?>(
                            valueListenable: UserStatusOverride.current,
                            builder: (context, _, __) =>
                                _buildStatusCard(blocks),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Saved Schedule',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: onBackground,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _goToSchedule(context),
                                child: Text(blocks.isEmpty ? 'Add' : 'Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildTimeline(context, blocks),
                          const SizedBox(height: 22),
                          _buildStatsRow(blocks),
                          const SizedBox(height: 28),
                          _buildReportButton(context),
                        ],
                      ),
                    ),
                    const HeadsUpAlertBanner(),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildHeader(Color onBackground) {
    return Row(
      children: [
        const LogoBadge(size: 44),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Roshan Alert',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: onBackground,
              ),
            ),
            const SizedBox(height: 2),
            const LocationRow(),
          ],
        ),
      ],
    );
  }

  /// Status card — title line ("`Utility` should be ON/OFF now"), plus
  /// a countdown subtitle ONLY when:
  ///   - it's currently OFF, AND
  ///   - that OFF is coming from the SAVED SCHEDULE (not a self-report)
  /// A self-report has no known "back on" time, so no countdown is
  /// ever shown alongside a reported outage.
  Widget _buildStatusCard(List<ScheduleBlock> blocks) {
    final bool hasOverride = UserStatusOverride.isActive;
    final ScheduleBlock? active = ScheduleStore.currentBlockAt(_now);
    final bool scheduleSaysOff = active != null;

    final bool isOffNow = hasOverride
        ? UserStatusOverride.isOut
        : scheduleSaysOff;

    String? subtitle;
    if (isOffNow && !hasOverride && active != null) {
      final int minutesNow = _now.hour * 60 + _now.minute;
      final int minsLeft = active.endMinutes - minutesNow;
      if (minsLeft > 0) {
        subtitle = _formatDurationMinutes(minsLeft);
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(22),
      borderColor: AppColors.black,
      child: ValueListenableBuilder<String>(
        valueListenable: AppLocation.utility,
        builder: (context, utility, _) {
          final IconData statusIcon = isOffNow
              ? (utility == 'Gas'
                    ? Icons.local_fire_department_rounded
                    : Icons.flash_off_rounded)
              : (utility == 'Gas'
                    ? Icons.local_fire_department_rounded
                    : Icons.bolt_rounded);

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: AppColors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOffNow
                          ? '$utility should be OFF now'
                          : '$utility should be ON now',
                      style: const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<ScheduleBlock> blocks) {
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          "You haven't saved any outage times yet.",
          style: TextStyle(
            fontSize: 13.5,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    final String utilityWord = AppLocation.utility.value == 'Gas'
        ? 'Gas'
        : 'Electricity';
    final IconData blockIcon = AppLocation.utility.value == 'Gas'
        ? Icons.local_fire_department_rounded
        : Icons.flash_off_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        final int minutes = block.endMinutes - block.startMinutes;
        final String durationText = _formatDurationMinutes(minutes);

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(blockIcon, color: AppColors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$utilityWord usually OFF',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      block.timeRangeLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  durationText,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsRow(List<ScheduleBlock> blocks) {
    final int totalMinutesOff = blocks.fold<int>(
      0,
      (sum, b) => sum + (b.endMinutes - b.startMinutes),
    );
    final String hoursLabel = _formatDurationMinutes(totalMinutesOff);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.timer_outlined,
              value: blocks.isEmpty ? '—' : hoursLabel,
              label: 'Off per day (saved)',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _statCard(
              icon: Icons.event_available_rounded,
              value: '${blocks.length}',
              label: 'Saved outage blocks',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
            child: Icon(icon, color: AppColors.black, size: 20),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => _goToReport(context),
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Report an Outage'),
      ),
    );
  }
}
