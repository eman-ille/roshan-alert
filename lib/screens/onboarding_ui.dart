import 'package:flutter/material.dart';
import '/Helping_Files/app_location.dart';
import 'placeholder_screen.dart';   // ← added

/// Standalone onboarding content widget.
/// No main() / MaterialApp here — just drop <OnboardingScreen/> into
/// your app's navigation wherever you need it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 0 = nothing selected, 1 = option one, 2 = option two
  int _selectedOption = 0;

  // Currently picked values for each location dropdown
  String? _province;
  String? _city;
  String? _area;

  void _onContinue() async {
    // Basic guard — don't let them proceed with an incomplete address.
    if (_selectedOption == 0 || _province == null || _city == null || _area == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields before continuing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Gas isn't built yet — send them to the shared placeholder instead
    // of saving an address and continuing into Home. Using push (not
    // pushReplacement) keeps onboarding underneath, so backing out
    // lets them switch to Electricity instead of being stuck.
    if (_selectedOption == 2) {
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

    // Electricity — original flow, unchanged.
    // Updates AppLocation.current / AppLocation.utility live (so
    // LocationRow on Home/Report reflects it instantly) AND persists it
    // to local storage — no address map to build or pass through
    // Navigator arguments anywhere.
    await AppLocation.set(
      utility: 'Electricity',
      province: _province!,
      city: _city!,
      area: _area!,
    );

    if (!mounted) return;

    // pushReplacementNamed so onboarding is removed from the back stack —
    // the user should never be able to swipe/back into it again.
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ---------- LOGO ----------
              const _RALogo(),

              const SizedBox(height: 44),

              const Text(
                'Choose an option',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),

              // ---------- TWO-ITEM CHOICE ----------
              Row(
                children: [
                  Expanded(
                    child: _ChoiceCard(
                      label: 'Electricity',
                      selected: _selectedOption == 1,
                      onTap: () => setState(() => _selectedOption = 1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ChoiceCard(
                      label: 'Gas',
                      selected: _selectedOption == 2,
                      onTap: () => setState(() => _selectedOption = 2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose location by',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ---------- LOCATION DROPDOWNS ----------
              _LocationDropdown(
                label: 'Province',
                value: _province,
                items: const ['Punjab', 'Sindh', 'KPK', 'Balochistan'],
                onChanged: (v) => setState(() => _province = v),
              ),
              const SizedBox(height: 12),
              _LocationDropdown(
                label: 'City',
                value: _city,
                items: const ['Lahore', 'Karachi', 'Islamabad', 'Sialkot'],
                onChanged: (v) => setState(() => _city = v),
              ),
              const SizedBox(height: 12),
              _LocationDropdown(
                label: 'Area',
                value: _area,
                items: const ['Area 1', 'Area 2', 'Area 3'],
                onChanged: (v) => setState(() => _area = v),
              ),

              const SizedBox(height: 44),

              // ---------- CONTINUE BUTTON ----------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _onContinue,
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern "RA" logo mark — a single rounded square badge with a tight,
/// letter-spaced monogram plus a thin underline accent. No overlapping
/// shapes, kept strictly black & white.
class _RALogo extends StatelessWidget {
  const _RALogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const Text(
            'RA',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 28,
          height: 2.5,
          color: Colors.black,
        ),
      ],
    );
  }
}

/// Card used for the two main choice options.
class _ChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
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
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.black,
            width: selected ? 0 : 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

/// Dropdown field used for each location sub-option (Province / City / Area).
class _LocationDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
          hint: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          dropdownColor: Colors.white,
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