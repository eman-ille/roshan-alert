import 'dart:async';
import 'package:flutter/material.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_banner.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/location_row.dart';
import '/Helping_Files/logo_badge.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/app_location.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Static demo data for now — later this comes from the FastAPI backend.
  // Each entry: hour (0-23) and status ('on' or 'off').
  static const List<Map<String, dynamic>> _todaySchedule = [
    {'hour': 0, 'status': 'on'},
    {'hour': 1, 'status': 'on'},
    {'hour': 2, 'status': 'on'},
    {'hour': 3, 'status': 'on'},
    {'hour': 4, 'status': 'on'},
    {'hour': 5, 'status': 'off'},
    {'hour': 6, 'status': 'off'},
    {'hour': 7, 'status': 'on'},
    {'hour': 8, 'status': 'on'},
    {'hour': 9, 'status': 'on'},
    {'hour': 10, 'status': 'on'},
    {'hour': 11, 'status': 'on'},
    {'hour': 12, 'status': 'off'},
    {'hour': 13, 'status': 'off'},
    {'hour': 14, 'status': 'on'},
    {'hour': 15, 'status': 'on'},
    {'hour': 16, 'status': 'on'},
    {'hour': 17, 'status': 'on'},
    {'hour': 18, 'status': 'off'},
    {'hour': 19, 'status': 'off'},
    {'hour': 20, 'status': 'on'},
    {'hour': 21, 'status': 'on'},
    {'hour': 22, 'status': 'on'},
    {'hour': 23, 'status': 'on'},
  ];

  // The banner message is plain widget state — no OverlayEntry involved,
  // so it can never get orphaned or fail to reinsert.
  String? _bannerMessage;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    // Whenever any screen queues a confirmation message, show it here.
    AppBanner.pendingMessage.addListener(_onPendingMessage);

    // Also check for a message that was already queued BEFORE this
    // screen was built — happens when Report navigates here via
    // pushReplacementNamed (reached through the bottom nav tab) instead
    // of being popped back into an existing Home screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingMessage());
  }

  @override
  void dispose() {
    AppBanner.pendingMessage.removeListener(_onPendingMessage);
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _onPendingMessage() {
    if (!mounted) return;
    final message = AppBanner.pendingMessage.value;
    if (message != null) {
      _showBanner(message);
      AppBanner.pendingMessage.value = null; // consume it so it doesn't repeat
    }
  }

  // Merge consecutive same-status hours into wide continuous segments.
  List<Map<String, dynamic>> get _segments {
    final List<Map<String, dynamic>> segments = [];
    for (final entry in _todaySchedule) {
      if (segments.isNotEmpty && segments.last['status'] == entry['status']) {
        segments.last['hours'] = (segments.last['hours'] as int) + 1;
      } else {
        segments.add({'status': entry['status'], 'hours': 1});
      }
    }
    return segments;
  }

  String _formatHour(int hour) {
    final int h = hour % 24;
    final String period = h < 12 ? 'AM' : 'PM';
    int displayHour = h % 12;
    if (displayHour == 0) displayHour = 12;
    return '$displayHour $period';
  }

  void _goToReport(BuildContext context) {
    // No arguments needed — Report reads the address from AppLocation
    // directly, same as Home does.
    Navigator.pushNamed(context, '/report');
  }

  // Cancels any pending hide-timer, shows the message, and schedules
  // it to disappear after 3 seconds. Calling this again while a banner
  // is already showing simply replaces it and restarts the timer.
  void _showBanner(String message) {
    _bannerTimer?.cancel();
    setState(() => _bannerMessage = message);

    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildStatusCard(),
                  const SizedBox(height: 28),
                  const Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTimeline(),
                  const SizedBox(height: 22),
                  _buildStatsRow(),
                  const SizedBox(height: 28),
                  _buildReportButton(context),
                ],
              ),
            ),
            if (_bannerMessage != null) _buildBanner(),
          ],
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

  Widget _buildHeader() {
    return Row(
      children: [
        const LogoBadge(size: 44),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Roshan Alert',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 2),
            // Reactive — updates instantly the moment AppLocation.current
            // changes anywhere in the app (e.g. right after onboarding).
            const LocationRow(),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return AppCard(
      padding: const EdgeInsets.all(22),
      borderColor:
          AppColors.black, // this card is the "hero" — darker border on purpose
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reflects whichever utility was picked in onboarding — swaps
          // icon + heading between Electricity/Gas automatically.
          ValueListenableBuilder<String>(
            valueListenable: AppLocation.utility,
            builder: (context, utility, _) {
              final bool isElectricity = utility == 'Electricity';
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isElectricity
                          ? Icons.bolt_rounded
                          : Icons.local_fire_department_rounded,
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
                          '$utility is ON right now',
                          style: const TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Next outage in 45 min · 5:00–7:00 PM',
                          style: TextStyle(
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
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              value: 0.7,
              minHeight: 10,
              backgroundColor: AppColors.trackGrey,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final segments = _segments;
    int cursorHour = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        final bool isOn = seg['status'] == 'on';
        final int hours = seg['hours'] as int;
        final int startHour = cursorHour;
        final int endHour = cursorHour + hours;
        cursorHour = endHour;

        final String timeRange =
            '${_formatHour(startHour)} – ${_formatHour(endHour)}';
        final String durationText = hours == 1 ? '1 hour' : '$hours hours';

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOn ? AppColors.black : AppColors.white,
                  shape: BoxShape.circle,
                  border: isOn
                      ? null
                      : Border.all(color: AppColors.black, width: 1.5),
                ),
                child: Icon(
                  isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: isOn ? AppColors.white : AppColors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOn ? 'Power will be ON' : 'Power will be OFF',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeRange,
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
                  color: isOn ? AppColors.black : AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: isOn
                      ? null
                      : Border.all(color: AppColors.black, width: 1.2),
                ),
                child: Text(
                  durationText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isOn ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.timer_outlined,
            value: '6 hrs',
            label: 'Off today',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            icon: Icons.event_available_rounded,
            value: '2',
            label: 'Outages today',
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
    // No style: block here — inherits from appTheme.elevatedButtonTheme.
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