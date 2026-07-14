import 'package:flutter/material.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/app_location.dart';
import 'placeholder_screen.dart';

/// Settings screen — lets the user change their saved location
/// (Province / City / Area) and switch between Electricity / Gas.
///
/// Picking "Gas" here doesn't have real settings built yet, so it
/// just pushes the existing PlaceholderScreen on top ("Gas — Coming
/// Soon") — same reusable placeholder already used for Schedule.
/// Picking "Electricity" keeps this screen and lets the user edit
/// province/city/area same as onboarding; Save persists via
/// AppLocation.set(...) so every screen using LocationRow updates
/// instantly, same as it does after onboarding.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _utility;
  String? _province;
  String? _city;
  String? _area;

  @override
  void initState() {
    super.initState();
    // Pre-fill from whatever was picked in onboarding / last saved,
    // so this screen never starts blank for a returning user.
    _utility = AppLocation.utility.value;
    _province = AppLocation.province;
    _city = AppLocation.city;
    _area = AppLocation.area;
  }

  void _selectUtility(String value) {
    setState(() => _utility = value);

    if (value == 'Gas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlaceholderScreen(
            title: 'Gas',
            icon: Icons.local_fire_department_rounded,
          ),
        ),
      ).then((_) {
        // Coming back shouldn't leave "Gas" visually selected if
        // nothing was actually saved for it.
        if (mounted) setState(() => _utility = AppLocation.utility.value);
      });
    }
  }

  Future<void> _saveLocation() async {
    if (_province == null || _city == null || _area == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await AppLocation.set(
      utility: _utility,
      province: _province!,
      city: _city!,
      area: _area!,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Utility',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _UtilityCard(
                      label: 'Electricity',
                      icon: Icons.bolt_rounded,
                      selected: _utility == 'Electricity',
                      onTap: () => _selectUtility('Electricity'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _UtilityCard(
                      label: 'Gas',
                      icon: Icons.local_fire_department_rounded,
                      selected: _utility == 'Gas',
                      onTap: () => _selectUtility('Gas'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _SettingsDropdown(
                      label: 'Province',
                      value: _province,
                      items: const ['Punjab', 'Sindh', 'KPK', 'Balochistan'],
                      onChanged: (v) => setState(() => _province = v),
                    ),
                    const SizedBox(height: 12),
                    _SettingsDropdown(
                      label: 'City',
                      value: _city,
                      items: const ['Lahore', 'Karachi', 'Islamabad', 'Sialkot'],
                      onChanged: (v) => setState(() => _city = v),
                    ),
                    const SizedBox(height: 12),
                    _SettingsDropdown(
                      label: 'Area',
                      value: _area,
                      items: const ['Area 1', 'Area 2', 'Area 3'],
                      onChanged: (v) => setState(() => _area = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLocation,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

/// Utility selector card — same visual language as onboarding's
/// _ChoiceCard, plus an icon since this screen has more room.
class _UtilityCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _UtilityCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: AppColors.black,
            width: selected ? 0 : 1.4,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.white : AppColors.black,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same dropdown look as onboarding's _LocationDropdown, minus its
/// own outer border — AppCard already wraps all three of these in
/// one bordered block here.
class _SettingsDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.black),
          hint: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.grey,
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
          dropdownColor: AppColors.white,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}