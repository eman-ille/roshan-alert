import 'dart:async';
import 'package:flutter/material.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_banner.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/location_row.dart';
import '/Helping_Files/logo_badge.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/app_location.dart';
import '/Helping_Files/schedule_store.dart';
import '/Helping_Files/reports_store.dart';
import '/Helping_Files/pending_report.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _bannerMessage;
  Timer? _bannerTimer;

  // Ticks once a minute so "is it on right now" and the countdown stay
  // accurate without the user having to reopen the screen.
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    AppBanner.pendingMessage.addListener(_onPendingMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingMessage());
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
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

  // "Yes, it's true" — writes the report for real via the store, then
  // shows a thank-you banner. "No, revert" just clears the preview.
  Future<void> _confirmPendingReport(PendingReport report) async {
    try {
      await PendingReportStore.confirm();
      if (!mounted) return;
      _showBanner(
        report.isOut
            ? 'Thanks! You reported a power outage in your area.'
            : 'Thanks! You reported power is back in your area.',
      );
    } catch (e) {
      if (!mounted) return;
      _showBanner(
        "Couldn't submit your report — check your connection and try again.",
      );
    }
  }

  void _onPendingMessage() {
    if (!mounted) return;
    final message = AppBanner.pendingMessage.value;
    if (message != null) {
      _showBanner(message);
      AppBanner.pendingMessage.value = null;
    }
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

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<PendingReport?>(
          // Reads straight from the global store — works no matter how
          // this HomeScreen instance came to exist (fresh push, or
          // torn down and recreated by the bottom nav's
          // pushReplacementNamed on every tab switch).
          valueListenable: PendingReportStore.pending,
          builder: (context, pendingReport, _) {
            return ValueListenableBuilder<List<ScheduleBlock>>(
              valueListenable: ScheduleStore.blocks,
              builder: (context, blocks, __) {
                return ValueListenableBuilder<String>(
                  valueListenable: AppLocation.utility,
                  builder: (context, utility, ___) {
                    return StreamBuilder<AreaReport?>(
                      stream: ReportsStore.watchLatestForCurrentArea(utility),
                      builder: (context, reportSnapshot) {
                        final AreaReport? areaReport = reportSnapshot.data;
                        return Stack(
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(onBackground),
                                  const SizedBox(height: 28),
                                  _buildStatusCard(
                                    blocks,
                                    areaReport,
                                    pendingReport,
                                  ),
                                  if (pendingReport != null) ...[
                                    const SizedBox(height: 12),
                                    _buildConfirmBar(pendingReport),
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

  Widget _buildStatusCard(
    List<ScheduleBlock> blocks,
    AreaReport? areaReport,
    PendingReport? pendingReport,
  ) {
    if (blocks.isEmpty && areaReport == null && pendingReport == null) {
      return _buildNoScheduleCard();
    }

    final ScheduleBlock? active = ScheduleStore.currentBlockAt(_now);
    final ScheduleBlock? upcoming = ScheduleStore.nextBlockAfter(_now);
    final bool scheduleSaysOff = active != null;

    // A recent report is a direct observation, so it wins over the
    // schedule guess whenever the two disagree — in EITHER direction:
    // schedule says on but someone reported it out, or schedule says
    // off but someone reported it's back. Older reports are ignored
    // and we fall back to the schedule.
    final bool hasFreshReport =
        areaReport != null &&
        areaReport.ageFrom(_now) <= ReportsStore.recentWindow;

    // A report this same account just submitted, still waiting on
    // confirmation, previews as if it were already true — but isn't
    // saved anywhere yet, and reverts if not confirmed.
    final bool hasPending = pendingReport != null;
    final bool isOffNow = hasPending
        ? pendingReport.isOut
        : hasFreshReport
        ? areaReport.isOut
        : scheduleSaysOff;

    String subtitle;
    if (hasPending) {
      final int secondsLeft = pendingReport.secondsLeft;
      subtitle = isOffNow
          ? "You just reported an outage — confirm it's true below "
                "(auto-reverts in $secondsLeft s)"
          : "You just reported power is back — confirm it's true below "
                "(auto-reverts in $secondsLeft s)";
    } else if (hasFreshReport) {
      final int minsAgo = areaReport.ageFrom(_now).inMinutes;
      final String agoText = minsAgo <= 1 ? 'just now' : '$minsAgo min ago';
      subtitle = isOffNow
          ? 'Someone in your area reported an outage $agoText'
          : 'Someone in your area reported power is back $agoText';
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
    } else {
      subtitle = 'No more outages in your saved schedule for today';
    }

    final String sourceNote = hasPending
        ? "Preview only — nothing has been saved yet."
        : hasFreshReport
        ? "Based on a recent report from your area — not your saved schedule."
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
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOffNow ? Icons.flash_off_rounded : Icons.bolt_rounded,
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

  // Shown under the status card only while a self-submitted report is
  // being previewed. "Yes, it's true" saves it for real; "No, revert"
  // (or letting the countdown run out) puts Home back the way it was.
  Widget _buildConfirmBar(PendingReport pendingReport) {
    final bool resolving = pendingReport.resolving;
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Is this actually true right now?',
            style: TextStyle(
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
                  onPressed: resolving ? null : PendingReportStore.revert,
                  child: const Text('No, revert'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: resolving
                      ? null
                      : () => _confirmPendingReport(pendingReport),
                  child: resolving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(AppColors.white),
                          ),
                        )
                      : const Text("Yes, it's true"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoScheduleCard() {
    return AppCard(
      padding: const EdgeInsets.all(22),
      borderColor: AppColors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No schedule saved yet',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add the times you know your power usually goes out.',
                      style: TextStyle(fontSize: 13.5, color: AppColors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                // AppCard's background stays white in dark mode, but the
                // dark ColorScheme's default button foreground is white
                // too — that made the icon/label invisible here. Force
                // black since this button always sits on a white card.
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black, width: 1.5),
              ),
              onPressed: () => _goToSchedule(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your schedule'),
            ),
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
                child: const Icon(
                  Icons.flash_off_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Power usually OFF',
                      style: TextStyle(
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
