import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/containers/residents/pages/rate_us_page.dart';

import 'package:emcall/containers/workers/pages/video_reels_page.dart';
import 'package:emcall/containers/workers/pages/view_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuPage extends StatefulWidget {
  final String workerName;
  final int? workerId; // Add workerId parameter

  const MenuPage({super.key, required this.workerName, required this.workerId});

  @override
  MenuPageState createState() => MenuPageState();
}

class MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from bottom
      end: Offset.zero, // End at top
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // Start the animation when the page is shown
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closePage() {
    // Directly navigate back to WorkerHomePage using default pop animation
    Navigator.of(context).pop();
  }

  // Helper method for navigation with right-to-left slide animation
  void _navigateWithSlide(Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(1, 0), // From right
            end: Offset.zero, // To left
          ).chain(CurveTween(curve: Curves.easeOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

// Logout and navigate to WelcomePage with a confirmation dialog
  Future<void> _logoutAndNavigate() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to shut off and log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text(
              'Shut Off',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    // Proceed with logout only if the user confirms
    if (shouldLogout != true) {
      return; // User canceled, do nothing
    }

    try {
      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs
          .clear(); // Clears all stored data (worker_email, worker_id, etc.)

      // Navigate to WelcomePage with slide animation
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WelcomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final tween = Tween(
                begin: const Offset(1, 0), // From right
                end: Offset.zero, // To left
              ).chain(CurveTween(curve: Curves.easeOut));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error logging out. Please try again.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 68),

                      // Close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, size: 30),
                            onPressed: _closePage,
                          ),
                        ],
                      ),
                      const SizedBox(width: 48),
                      // Avatar and greeting
                      Row(
                        children: [
                          // Avatar from assets
                          Image.asset(
                            'assets/icons/emcall_avatar.jpg',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hey ${widget.workerName}!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.redAccent,
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        _navigateWithSlide(ViewProfilePage(
                                          workerName: widget.workerName,
                                          workerId: widget.workerId,
                                        ));
                                      },
                                      child: const Text(
                                        'View profile',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Menu items
                  ListTile(
                    leading:
                        const Icon(Icons.video_collection_outlined, size: 30),
                    title: const Text(
                      'Reels',
                      style: TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      _navigateWithSlide(
                          VideoReelsPage(workerId: widget.workerId));
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.help_outline, size: 30),
                    title: const Text(
                      'Rate Us',
                      style: TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      _navigateWithSlide(const RateUsPage());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.power_settings_new, size: 30),
                    title: const Text(
                      'Shut off',
                      style: TextStyle(fontSize: 18),
                    ),
                    onTap: _logoutAndNavigate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
