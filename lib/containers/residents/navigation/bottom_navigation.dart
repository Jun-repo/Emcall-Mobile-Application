// custom_bottom_navigation.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  Widget _buildNavIcon(
      IconData selectedIcon, IconData unselectedIcon, int index) {
    bool isSelected = selectedIndex == index;
    return isSelected
        ? Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(30.0, 30.0)),
              color: Color.fromARGB(179, 255, 139, 131),
            ),
            child: Icon(selectedIcon),
          )
        : Icon(unselectedIcon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.map_rounded, Icons.map_outlined, 0),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.phone_rounded, Icons.phone_outlined, 1),
            label: 'Emergencies',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.slow_motion_video_outlined,
                Icons.slow_motion_video_rounded, 2),
            label: 'Reels',
          ),
        ],
        currentIndex: selectedIndex,
        selectedItemColor: Colors.black,
        selectedLabelStyle: const TextStyle(
          shadows: [
            Shadow(
              blurRadius: 5.0,
              color: Colors.black54,
              offset: Offset(2.0, 2.0),
            ),
          ],
        ),
        unselectedItemColor: Colors.black,

        selectedFontSize: 12,
        unselectedFontSize: 12,
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(
          size: 23,
          color: Colors.black,
          shadows: [
            Shadow(
              blurRadius: 5.0,
              color: Colors.black54,
              offset: Offset(2.0, 2.0),
            ),
          ],
        ),
        unselectedIconTheme: const IconThemeData(size: 22, color: Colors.black),
        showUnselectedLabels: true,
        elevation: 0.0,
        onTap: onItemTapped, // Simply call the callback, no navigation here
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
