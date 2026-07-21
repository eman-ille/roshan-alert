import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_banner.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/location_row.dart';
import '/Helping_Files/logo_badge.dart';
import '/Helping_Files/app_location.dart';
import '/Helping_Files/reports_store.dart';
import '/Helping_Files/self_status_store.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Which option the user has selected: 'out', 'back', or null.
  String? _selected;
  bool _submitting = false;

  void _selectOption(String value) {
    setState(() => _selected = value);
  }

  Future<void> _submitReport() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an option before submitting.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // This account's own Home screen updates immediately — that's
      // handled locally below and doesn't need anyone else's OK. The
      // Firestore row is what lets OTHER users nearby see "X user(s)
      // in your area say..." on their own Home screens.
      await ReportsStore.submitReport(
        status: _selected!,
        reporterUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        province: AppLocation.province,
        city: AppLocation.city,
        area: AppLocation.area,
        utility: AppLocation.utility.value,
      );
      await UserStatusOverride.set(_selected!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't submit your report — check your connection and try again.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final message = _selected == 'out'
        ? 'Thanks! Your Home screen now shows the power as OUT.'
        : 'Thanks! Your Home screen now shows the power as BACK.';

    // Queue the confirmation message globally, then leave this screen
    // in whatever way is actually possible right now.
    AppBanner.pendingMessage.value = message;

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Outage')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LogoBadge(size: 66),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                // Reactive — same LocationRow used on Home, reads
                // AppLocation.current directly.
                child: const LocationRow(fontSize: 13, color: AppColors.black),
              ),
              const Text(
                'What are you seeing right now?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildToggle(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitReport,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(AppColors.white),
                          ),
                        )
                      : const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  // Segmented pill toggle, styled after the reference image's
  // "Electricity / Gas" selector — solid black when selected,
  // outlined when not.
  Widget _buildToggle() {
    return Row(
      children: [
        Expanded(child: _toggleOption('out', 'Power is OUT')),
        const SizedBox(width: 12),
        Expanded(child: _toggleOption('back', 'Power is BACK')),
      ],
    );
  }

  Widget _toggleOption(String value, String label) {
    final bool isSelected = _selected == value;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: () => _selectOption(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.black, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}
