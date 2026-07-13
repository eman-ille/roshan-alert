import 'package:flutter/material.dart';
import 'app_theme.dart';

/// The circular black "RA" logo. Used in Home's header (small) and
/// Report's top section (large) — previously copy-pasted at two
/// hardcoded sizes. Now it's one widget with a `size` parameter.
class LogoBadge extends StatelessWidget {
  final double size;
  const LogoBadge({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'RA',
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}
