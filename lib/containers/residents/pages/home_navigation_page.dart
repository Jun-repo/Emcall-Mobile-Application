// home_navigation_page.dart (unchanged for this fix)
import 'package:emcall/components/maps/emcall_map.dart';
import 'package:emcall/containers/residents/navigation/bottom_navigation.dart';
import 'package:emcall/containers/residents/pages/first_aid_page.dart';
import 'package:emcall/containers/residents/pages/resident_home_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeNavigationPage extends StatefulWidget {
  final int initialIndex;
  const HomeNavigationPage({super.key, required this.initialIndex});

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const EmcallMap();
      case 1:
        return FutureBuilder<Map<String, String?>>(
          future: _loadResidentData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Error loading resident data'));
            }
            final data = snapshot.data!;
            return ResidentHomePage(
              firstName: data['firstName'] ?? 'Unknown',
              middleName: data['middleName'] ?? '',
              lastName: data['lastName'] ?? 'User',
              suffix: data['suffix'] ?? '',
              address: data['address'],
            );
          },
        );
      case 2:
        return const FirstAidPage();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Future<Map<String, String?>> _loadResidentData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'firstName': prefs.getString('firstName'),
      'middleName': prefs.getString('middleName'),
      'lastName': prefs.getString('lastName'),
      'suffix': prefs.getString('suffix'),
      'address': prefs.getString('address'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
