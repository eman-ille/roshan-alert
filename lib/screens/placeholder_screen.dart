import 'package:flutter/material.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/bottom_nav.dart';

/// Temporary stand-in for screens that haven't been built yet
/// (Schedule, Settings). Keeps the bottom nav fully working today.
/// When the real screen is ready: create its own file, then change
/// ONE line in main.dart's route map to point at it instead of this.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(icon, size: 34, color: AppColors.black),
            ),
            const SizedBox(height: 16),
            Text(
              '$title — Coming Soon',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This screen will be built next.',
              style: TextStyle(fontSize: 13.5, color: AppColors.grey),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
