import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_location.dart';

/// Small reusable "pin icon + location text" row.
/// Used by both Home and Report screens so the location always looks
/// the same everywhere, and always reflects the same live value from
/// AppLocation.current — change the styling once, here, and it updates
/// on every screen that uses it.
class LocationRow extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final Color color;

  const LocationRow({
    super.key,
    this.iconSize = 14,
    this.fontSize = 13,
    this.color = AppColors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocation.current,
      builder: (context, location, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_rounded, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            location,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
