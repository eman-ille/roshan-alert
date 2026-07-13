import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared white bordered card — used for the status card, each schedule
/// row, and the stat cards on Home. Previously each one repeated the
/// same `color: AppColors.white` + `Border.all(...)` BoxDecoration by
/// hand. Change the shared card look (fill, default border) here once.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color borderColor;
  final double borderWidth;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = AppRadius.large,
    this.borderColor = AppColors.border,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );
  }
}
