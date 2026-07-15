import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared dropdown field for location sub-options (Province / City / Area).
///
/// Used by BOTH Onboarding and Settings — this used to be duplicated:
/// Settings had its own private `_SettingsDropdown` doing the exact same
/// enabled/disabled cascade-lock logic with slightly different styling.
/// That duplicate has been removed; both screens now import this one
/// widget and just pick a style via [outlined].
///
/// [enabled] lets a downstream dropdown (City, Area) be visibly greyed
/// out and unopenable until its parent selection (Province, City) has
/// been made — this is what makes a Province -> City -> Area cascade
/// clear to the user instead of silently just having an empty list.
///
/// [outlined] switches between the two visual styles already in use:
/// - `true` (default) — bold black border, larger padding. Used standalone
///   in Onboarding, where the field needs to carry its own visual weight.
/// - `false` — soft `AppColors.border` grey border, tighter padding. Used
///   in Settings, where three of these already sit inside one `AppCard`
///   that provides the outer border — a second bold border would double up.
class LocationDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? disabledHint;
  final bool outlined;

  const LocationDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.disabledHint,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUsable = enabled && items.isNotEmpty;

    final Color borderColor = outlined
        ? (isUsable ? Colors.black : Colors.black26)
        : (isUsable ? AppColors.border : AppColors.border.withOpacity(0.6));

    final Color iconColor = outlined
        ? (isUsable ? Colors.black : Colors.black26)
        : (isUsable ? AppColors.black : AppColors.grey);

    final Color hintColor = outlined
        ? (isUsable ? Colors.black54 : Colors.black38)
        : AppColors.grey;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: outlined ? 16 : 12),
      decoration: BoxDecoration(
        color: isUsable ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(outlined ? 10 : AppRadius.small),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          // Passing null value/onChanged when disabled is what actually
          // makes Flutter render the dropdown as non-interactive.
          value: isUsable ? value : null,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: iconColor),
          hint: Text(
            !enabled && disabledHint != null ? disabledHint! : label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: hintColor,
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
          onChanged: isUsable ? onChanged : null,
        ),
      ),
    );
  }
}