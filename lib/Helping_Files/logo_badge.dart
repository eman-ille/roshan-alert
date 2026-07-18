import 'package:flutter/material.dart';
import 'app_theme.dart';

/// The circular "RA" logo badge. Used in Home's header (small) and
/// Report's top section (large).
///
/// Automatically inverts for dark mode: black-on-white in light theme,
/// white-on-black in dark theme — so it's never a near-invisible
/// black-on-near-black circle when the app is in dark mode.
class LogoBadge extends StatelessWidget {
  final double size;
  const LogoBadge({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.white : AppColors.black;
    final textColor = isDark ? AppColors.black : AppColors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        'RA',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}
