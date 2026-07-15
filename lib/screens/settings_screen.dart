import 'package:flutter/material.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/app_location.dart';
import '/Helping_Files/location_data.dart';
import '/Helping_Files/location_dropdown.dart';
import 'placeholder_screen.dart';

/// Settings screen — lets the user change their saved location
/// (Province / City / Area) and switch between Electricity / Gas.
///
/// Tapping the Gas card only highlights it — it does NOT navigate.
/// Gas doesn't have real settings built yet, so once the user taps
/// "Save Changes" with Gas selected, the location is saved as normal
/// (via AppLocation.set) and only then does the app push the existing
/// PlaceholderScreen on top ("Gas — Coming Soon"), same reusable
/// placeholder already used for Schedule. Saving with Electricity
/// selected just persists and shows a "Settings saved." confirmation,
/// same as before.
///
/// Province/City/Area options come from Helping_Files/location_data.dart
/// — the same shared, real Pakistan location data Onboarding uses, so
/// this screen and Onboarding never drift out of sync with each other.
///
/// The three dropdowns below use the shared LocationDropdown widget from
/// Helping_Files/location_dropdown.dart (with `outlined: false` for the
/// softer in-card look) instead of a private copy — this screen used to
/// have its own near-identical `_SettingsDropdown` class, which has been
/// removed to avoid maintaining two copies of the same cascade-lock logic.
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

  // City/Area option lists depend on whatever Province/City are
  // currently selected — same cascade rule as OnboardingScreen.
  List<String> get _citiesForProvince => LocationData.citiesFor(_province);
  List<String> get _areasForCity => LocationData.areasFor(_city);

  void _selectUtility(String value) {
    // Just select the card visually — no navigation here. Gas only
    // routes to the "Coming Soon" placeholder once the user actually
    // saves, in _saveLocation() below.
    setState(() => _utility = value);
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

    // Gas doesn't have real settings built yet. The location/utility is
    // still saved above (so it's correctly persisted and reflected
    // everywhere via AppLocation), but only NOW — after Save was
    // actually pressed — do we send the user to the "Coming Soon"
    // placeholder, instead of doing it the instant the card is tapped.
    if (_utility == 'Gas') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlaceholderScreen(
            title: 'Gas',
            icon: Icons.local_fire_department_rounded,
          ),
        ),
      );
      return;
    }

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
                    LocationDropdown(
                      label: 'Province',
                      value: _province,
                      items: LocationData.provinces,
                      outlined: false,
                      onChanged: (v) => setState(() {
                        _province = v;
                        // A new province invalidates whatever city/area
                        // was picked before — they belonged to the old list.
                        _city = null;
                        _area = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    LocationDropdown(
                      label: 'City',
                      value: _city,
                      items: _citiesForProvince,
                      enabled: _province != null,
                      disabledHint: 'Select province first',
                      outlined: false,
                      onChanged: (v) => setState(() {
                        _city = v;
                        _area = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    LocationDropdown(
                      label: 'Area',
                      value: _area,
                      items: _areasForCity,
                      enabled: _city != null,
                      disabledHint: 'Select city first',
                      outlined: false,
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