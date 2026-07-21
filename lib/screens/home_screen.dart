import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_banner.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/location_row.dart';
import '/Helping_Files/logo_badge.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/app_location.dart';
import '/Helping_Files/schedule_store.dart';
import '/Helping_Files/reports_store.dart';
import '/Helping_Files/self_status_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _bannerMessage;
  Timer? _bannerTimer;

  // Ticks once a minute so "is it on right now" stays accurate, and so
  // a self-reported override gets dropped right as the schedule
  // crosses its next boundary, without the user having to reopen the
  // screen.
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Which crowd-card the user already answered (true or false) this
  // session, so it doesn't keep reappearing for the exact same report
  // batch. A NEW report from a different area neighbor changes the
  // key, so it reappears with the updated count.
  String? _respondedCrowdKey;
  bool _confirmingCrowd = false;

  // IMPORTANT: cached so the Firestore query isn't torn down and
  // resubscribed on every rebuild (banner auto-hide, the once-a-minute
  // clock tick, etc). StreamBuilder treats a new Stream instance as a
  // brand new stream — for a split second while it reconnects, its
  // data is null, which was making the crowd card flash/vanish even
  // though nobody tapped anything. Only rebuilt if the utility (the
  // one thing the query actually depends on) changes.
  Stream<CrowdSignal?>? _crowdStream;
  String? _crowdStreamCacheKey;

  CrowdSignal? _cachedCrowdSignal;

  Stream<CrowdSignal?> _crowdStreamFor(String utility, String currentUid) {
    if (currentUid.isEmpty) return Stream.value(null);
    final cacheKey =
        '${AppLocation.province}|${AppLocation.city}|${AppLocation.area}|'
        '$utility|$currentUid';
    if (_crowdStream == null || _crowdStreamCacheKey != cacheKey) {
      _crowdStreamCacheKey = cacheKey;
      _crowdStream = ReportsStore.watchCrowdSignal(
        utility: utility,
        currentUid: currentUid,
      );
    }
    return _crowdStream!;
  }

  @override
  void initState() {
    super.initState();
    AppBanner.pendingMessage.addListener(_onPendingMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPendingMessage();
      UserStatusOverride.clearIfStale(DateTime.now());
    });
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await UserStatusOverride.clearIfStale(DateTime.now());
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    AppBanner.pendingMessage.removeListener(_onPendingMessage);
    _bannerTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onPendingMessage() {
    if (!mounted) return;
    final message = AppBanner.pendingMessage.value;
    if (message != null) {
      _showBanner(message);
      AppBanner.pendingMessage.value = null;
    }
  }

  // "True" on a crowd card — this account is now ALSO saying it's
  // seeing this, so it (a) becomes another row for future neighbors'
  // counts, and (b) updates only THIS account's own Home status.
  Future<void> _confirmCrowdSignal(CrowdSignal crowd, String key) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String utilityWord =
        AppLocation.utility.value == 'Gas' ? 'Gas' : 'the power';
    setState(() => _confirmingCrowd = true);
    try {
      await ReportsStore.submitReport(
        status: crowd.status,
        reporterUid: uid,
        province: AppLocation.province,
        city: AppLocation.city,
        area: AppLocation.area,
        utility: AppLocation.utility.value,
      );
      await UserStatusOverride.set(crowd.status);
      if (!mounted) return;
      _showBanner(
        crowd.isOut
            ? 'Thanks — your Home screen now shows $utilityWord as OUT.'
            : 'Thanks — your Home screen now shows $utilityWord as BACK.',
      );
    } catch (e) {
      if (!mounted) return;
      _showBanner("Couldn't confirm — check your connection and try again.");
    } finally {
      if (mounted) {
        setState(() {
          _confirmingCrowd = false;
          _respondedCrowdKey = key;
        });
      }
    }
  }

  // "False" — leaves this account's own status exactly as it was.
  void _declineCrowdSignal(String key) {
    setState(() => _respondedCrowdKey = key);
  }

  String _formatMinutes(int minutes) {
    final int h = (minutes ~/ 60) % 24;
    final int m = minutes % 60;
    final String period = h < 12 ? 'AM' : 'PM';
    int displayHour = h % 12;
    if (displayHour == 0) displayHour = 12;
    final String mm = m.toString().padLeft(2, '0');
    return '$displayHour:$mm $period';
  }

  void _goToReport(BuildContext context) {
    Navigator.pushNamed(context, '/report');
  }

  void _goToSchedule(BuildContext context) {
    Navigator.pushNamed(context, '/schedule');
  }

  void _showBanner(String message) {
    _bannerTimer?.cancel();
    setState(() => _bannerMessage = message);

    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reads the current theme once per build — used to keep text that
    // sits directly on the Scaffold background readable in both light
    // and dark mode. Text inside AppCard doesn't need this, since
    // AppCard keeps a fixed white background regardless of theme.
    final onBackground = Theme.of(context).colorScheme.onSurface;
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<List<ScheduleBlock>>(
          valueListenable: ScheduleStore.blocks,
          builder: (context, blocks, _) {
            return ValueListenableBuilder<String>(
              valueListenable: AppLocation.utility,
              builder: (context, utility, _) {
                return StreamBuilder<CrowdSignal?>(
                  stream: _crowdStreamFor(utility, currentUid),
                  builder: (context, crowdSnapshot) {
                    if (crowdSnapshot.hasData) {
                      _cachedCrowdSignal = crowdSnapshot.data;
                    }
                    final CrowdSignal? crowd =
                        crowdSnapshot.data ?? _cachedCrowdSignal;

                    // Belt-and-suspenders: even though the query
                    // already excludes the current account, never
                    // trust a single layer for "don't show my own
                    // report back to me" — double-check here too.
                    final bool crowdIsSomeoneElse =
                        crowd != null &&
                        currentUid.isNotEmpty &&
                        !crowd.includesAccount(currentUid);
                    final bool crowdMatchesMyOwnStatus =
                        crowd != null &&
                        UserStatusOverride.isActive &&
                        UserStatusOverride.status == crowd.status;
                    final String? crowdKey = crowd == null
                        ? null
                        : '${crowd.status}-${crowd.userCount}-'
                              '${crowd.latestAt.millisecondsSinceEpoch}';
                    final bool showCrowdCard =
                        crowdIsSomeoneElse &&
                        !crowd.hasCurrentUserReported &&
                        !crowdMatchesMyOwnStatus &&
                        crowdKey != _respondedCrowdKey;

                    return Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(onBackground),
                              const SizedBox(height: 28),
                              _buildStatusCard(blocks),
                              if (showCrowdCard && crowd != null) ...[
                                const SizedBox(height: 12),
                                _buildCrowdCard(crowd, crowdKey!),
                              ],
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                    child: Text(
                                      blocks.isEmpty ? 'Add' : 'Edit',
                                    ),
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
                        if (_bannerMessage != null) _buildBanner(),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildBanner() {
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(_bannerMessage),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _bannerMessage ?? '',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildStatusCard(List<ScheduleBlock> blocks) {
    final bool hasOverride = UserStatusOverride.isActive;
    final ScheduleBlock? active = ScheduleStore.currentBlockAt(_now);
    final ScheduleBlock? upcoming = ScheduleStore.nextBlockAfter(_now);
    final bool scheduleSaysOff = active != null;

    final bool isOffNow = hasOverride
        ? UserStatusOverride.isOut
        : scheduleSaysOff;

    String subtitle;
    if (hasOverride) {
      subtitle = "Based on what you reported — not your saved schedule.";
    } else if (isOffNow && active != null) {
      final int minutesNow = _now.hour * 60 + _now.minute;
      final int minsLeft = active.endMinutes - minutesNow;
      subtitle =
          'Back on around ${_formatMinutes(active.endMinutes)} '
          '(~$minsLeft min left), based on your schedule';
    } else if (upcoming != null) {
      final int minutesNow = _now.hour * 60 + _now.minute;
      final int minsUntil = upcoming.startMinutes - minutesNow;
      subtitle =
          'Next scheduled outage in ~$minsUntil min · ${upcoming.timeRangeLabel}';
    } else if (blocks.isEmpty) {
      subtitle = 'No outage schedule saved for your area';
    } else {
      subtitle = 'No more outages in your saved schedule for today';
    }

    final String sourceNote = hasOverride
        ? "This reflects what YOU reported — it'll switch back to your "
              "saved schedule at the next scheduled change."
        : "Based on the schedule you saved — not a live reading. "
              "If it looks wrong, report it below.";

    return AppCard(
      padding: const EdgeInsets.all(22),
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<String>(
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
                    child: Icon(
                      statusIcon,
                      color: AppColors.white,
                      size: 28,
                    ),
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
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            sourceNote,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // "X user(s) in your area say power/gas is back/out" — shown to everyone
  // in the area EXCEPT whoever reported it (that's excluded upstream
  // in ReportsStore.watchCrowdSignal). Tapping True updates only this
  // account's own status; False (or ignoring it) leaves it unchanged.
  Widget _buildCrowdCard(CrowdSignal crowd, String key) {
    final String utilityWord =
        AppLocation.utility.value == 'Gas' ? 'Gas' : 'the power';
    final String peopleLabel = crowd.userCount == 1
        ? '1 user'
        : '${crowd.userCount} users';
    final String message = crowd.isOut
        ? '$peopleLabel in your area say $utilityWord is OUT — is that true for you too?'
        : '$peopleLabel in your area say $utilityWord is BACK — is that true for you too?';

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.black,
                    side: const BorderSide(color: AppColors.black, width: 1.5),
                  ),
                  onPressed: _confirmingCrowd
                      ? null
                      : () => _declineCrowdSignal(key),
                  child: const Text('False'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: _confirmingCrowd
                      ? null
                      : () => _confirmCrowdSignal(crowd, key),
                  child: _confirmingCrowd
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(AppColors.white),
                          ),
                        )
                      : const Text('True'),
                ),
              ),
            ],
          ),
        ],
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

    final String utilityWord =
        AppLocation.utility.value == 'Gas' ? 'Gas' : 'Power';
    final IconData blockIcon = AppLocation.utility.value == 'Gas'
        ? Icons.local_fire_department_rounded
        : Icons.flash_off_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        final int minutes = block.endMinutes - block.startMinutes;
        final double hours = minutes / 60;
        final String durationText = hours == hours.roundToDouble()
            ? '${hours.round()} ${hours == 1 ? 'hour' : 'hours'}'
            : '${hours.toStringAsFixed(1)} hours';

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
                child: Icon(
                  blockIcon,
                  color: AppColors.white,
                  size: 20,
                ),
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
    final double totalHoursOff = totalMinutesOff / 60;
    final String hoursLabel = totalHoursOff == totalHoursOff.roundToDouble()
        ? '${totalHoursOff.round()} hrs'
        : '${totalHoursOff.toStringAsFixed(1)} hrs';

    return Row(
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
