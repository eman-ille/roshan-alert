import 'package:flutter/material.dart';

/// Single source of truth for every tab in the app.
/// To add/rename/reorder a tab, edit ONLY this list.
class NavItem {
  final IconData icon;
  final String label;
  final String route;
  const NavItem({required this.icon, required this.label, required this.route});
}

const List<NavItem> navItems = [
  NavItem(icon: Icons.home_rounded, label: 'Home', route: '/home'),
  NavItem(
    icon: Icons.calendar_month_rounded,
    label: 'Schedule',
    route: '/schedule',
  ),
  NavItem(icon: Icons.campaign_rounded, label: 'Report', route: '/report'),
  NavItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
];

/// Shared bottom navigation bar.
///
/// Figures out which tab is "active" by matching the CURRENT ROUTE
/// NAME against navItems — not by each screen passing in a hardcoded
/// index. That means there is no number for any screen to get wrong:
/// reordering navItems, or adding/removing a tab, can never desync a
/// screen's highlighted tab from reality, because nothing hardcodes it.
///
/// Usage on any screen: bottomNavigationBar: const AppBottomNav()
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  int _currentIndex(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    final index = navItems.indexWhere((item) => item.route == routeName);
    return index == -1 ? 0 : index;
  }

  void _onTap(BuildContext context, int index) {
    final routeName = ModalRoute.of(context)?.settings.name;
    if (navItems[index].route == routeName) return; // already on this tab
    Navigator.pushReplacementNamed(context, navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    // No colors/styles set here — this inherits everything from
    // appTheme.bottomNavigationBarTheme (app_theme.dart).
    return BottomNavigationBar(
      currentIndex: _currentIndex(context),
      onTap: (index) => _onTap(context, index),
      items: navItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}
