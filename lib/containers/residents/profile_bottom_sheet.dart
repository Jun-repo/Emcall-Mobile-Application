import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A widget representing the profile content in a bottom sheet.
/// This replaces the old [ProfilePage] route.
class ProfileBottomSheet extends StatelessWidget {
  final String fullName;
  final String? residentProfileImageUrl;
  final String? address;
  final double profileCompletion;

  const ProfileBottomSheet({
    super.key,
    required this.fullName,
    required this.residentProfileImageUrl,
    required this.address,
    required this.profileCompletion,
  });

  // Logout method
  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("loggedIn");
    await prefs.remove("userType");
    await prefs.remove("first_name");
    await prefs.remove("middle_name");
    await prefs.remove("last_name");
    await prefs.remove("suffix");
    await prefs.remove("personal_email");

    Navigator.pushReplacement(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
    );
  }

  // Determine the color of the circular progress based on the percentage.
  Color _progressColor(double percent) {
    if (percent >= 80) {
      return Colors.green;
    } else if (percent >= 50) {
      return Colors.orange;
    } else if (percent >= 35) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  // A helper widget to build the circular progress with percentage text and label.
  Widget _buildProgressIndicator(double percent) {
    final color = _progressColor(percent);
    // Clamp the percent to [0..100] for safety
    final clampedPercent = percent.clamp(0, 100).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stack to place the percentage text in the center of the circle.
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: clampedPercent / 100,
                strokeWidth: 5,
                color: color,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            Text(
              '${clampedPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy',
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Profile Data',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            fontFamily: 'Gilroy',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      // Using a Material so the bottom sheet can have its own styling/theme
      child: SafeArea(
        // SafeArea to avoid notches and system UI
        top: false,
        child: SingleChildScrollView(
          // For scroll if content grows
          controller: ModalScrollController.of(context),
          child: Padding(
            padding:
                const EdgeInsets.only(top: 16, bottom: 16, right: 12, left: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Card with profile details and an edit icon at the top right
                Stack(
                  children: [
                    Card(
                      elevation: 1,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 26,
                          bottom: 12,
                          left: 12,
                          right: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar, name, and address
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor:
                                        Colors.redAccent.withOpacity(0.7),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundImage:
                                          (residentProfileImageUrl != null &&
                                                  residentProfileImageUrl!
                                                      .isNotEmpty &&
                                                  residentProfileImageUrl!
                                                      .startsWith('http'))
                                              ? NetworkImage(
                                                  residentProfileImageUrl!)
                                              : null,
                                      child: (residentProfileImageUrl == null ||
                                              residentProfileImageUrl!
                                                  .isEmpty ||
                                              !residentProfileImageUrl!
                                                  .startsWith('http'))
                                          ? const Icon(Icons.person, size: 40)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.normal,
                                            fontFamily: 'RobotoMono',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (address != null &&
                                            address!.isNotEmpty)
                                          Text(
                                            address!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontFamily: 'Gilroy',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Profile completion progress bar
                            _buildProgressIndicator(profileCompletion),
                          ],
                        ),
                      ),
                    ),
                    // Edit icon positioned at the top right of the card
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Logout button
                ElevatedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
