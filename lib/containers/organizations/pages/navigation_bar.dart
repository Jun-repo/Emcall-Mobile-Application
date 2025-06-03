import 'package:flutter/material.dart';

class NavigationBar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavItemTapped;

  const NavigationBar({
    super.key,
    required this.currentPage,
    required this.onNavItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _getCurrentIndex(),
      onTap: (index) {
        switch (index) {
          case 0:
            onNavItemTapped('Overview');
            break;
          case 1:
            onNavItemTapped('Employees');
            break;
          case 2:
            onNavItemTapped('Analytics');
            break;
          case 3:
            onNavItemTapped('Downloads');
            break;
          case 4:
            onNavItemTapped('GeoTracker');
            break;
        }
      },
      selectedItemColor: Colors.redAccent,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/icons/overview.png',
            width: 24,
            height: 24,
          ),
          activeIcon: Image.asset(
            'assets/icons/overview_filled.png',
            width: 24,
            height: 24,
          ),
          label: 'Overview',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/icons/candidates.png',
            width: 24,
            height: 24,
          ),
          activeIcon: Image.asset(
            'assets/icons/candidates_filled.png',
            width: 24,
            height: 24,
          ),
          label: 'Employees',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/icons/analytics.png',
            width: 24,
            height: 24,
          ),
          activeIcon: Image.asset(
            'assets/icons/analytics_filled.png',
            width: 24,
            height: 24,
          ),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/icons/inbox.png',
            width: 24,
            height: 24,
          ),
          activeIcon: Image.asset(
            'assets/icons/inbox_filled.png',
            width: 24,
            height: 24,
          ),
          label: 'Downloads',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/icons/geo_tracker.png',
            width: 24,
            height: 24,
          ),
          activeIcon: Image.asset(
            'assets/icons/geo_tracker_filled.png',
            width: 24,
            height: 24,
          ),
          label: 'GeoTracker',
        ),
      ],
    );
  }

  int _getCurrentIndex() {
    switch (currentPage) {
      case 'Overview':
        return 0;
      case 'Employees':
        return 1;
      case 'Analytics':
        return 2;
      case 'Downloads':
        return 3;
      case 'GeoTracker':
        return 4;
      default:
        return 0;
    }
  }
}
