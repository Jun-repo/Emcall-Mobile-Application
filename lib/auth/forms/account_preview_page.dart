import 'package:cached_network_image/cached_network_image.dart';
import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enums.dart';
import 'utils.dart';
import 'package:emcall/containers/residents/pages/home_navigation_page.dart';
import 'package:emcall/containers/workers/pages/worker_home_page.dart';
import 'package:emcall/containers/organizations/pages/organization_home_page.dart';

class AccountPreviewPage extends StatelessWidget {
  final UserType userType;
  final Map<String, dynamic> userData;

  const AccountPreviewPage({
    super.key,
    required this.userType,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    String displayName;
    String profileImage = '';
    if (userType == UserType.resident || userType == UserType.worker) {
      displayName = getFullName(
        firstName: userData['firstName'],
        middleName: userData['middleName'],
        lastName: userData['lastName'],
        suffix: userData['suffix'],
      );
      profileImage = userData['profileImage'] ?? '';
    } else {
      displayName = userData['orgName'];
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: 1.00, // Step 3 of 3
                backgroundColor: Colors.grey[300],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomePage()),
                (Route<dynamic> route) => false, // Clear the navigation stack
              );
            },
            child: const Text('Skip',
                style: TextStyle(color: Colors.black54, fontFamily: 'Gilroy')),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: const Color.fromARGB(40, 244, 67, 54),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: profileImage.isNotEmpty
                    ? CachedNetworkImageProvider(profileImage)
                    : null,
                child: profileImage.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(displayName, style: const TextStyle(fontSize: 24)),
            if (userType == UserType.organization)
              Text(userData['orgAddress'],
                  style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    if (userType == UserType.resident) {
                      await prefs.setBool("loggedIn", true);
                      await prefs.setString("userType", "resident");
                      await prefs.setString("username", userData['username']);
                      await prefs.setInt("resident_id", userData['id']);
                      await prefs.setString("firstName", userData['firstName']);
                      await prefs.setString(
                          "middleName", userData['middleName']);
                      await prefs.setString("lastName", userData['lastName']);
                      await prefs.setString("suffix", userData['suffix']);
                      await prefs.setString(
                          "personal_email", userData['email']);
                      await prefs.setString("address", userData['address']);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const HomeNavigationPage(initialIndex: 1),
                        ),
                      );
                    } else if (userType == UserType.worker) {
                      await prefs.setBool("loggedIn", true);
                      await prefs.setString("userType", "worker");
                      await prefs.setString("username", userData['username']);
                      await prefs.setInt("worker_id", userData['id']);
                      await prefs.setString("firstName", userData['firstName']);
                      await prefs.setString(
                          "middleName", userData['middleName']);
                      await prefs.setString("lastName", userData['lastName']);
                      await prefs.setString("suffix", userData['suffix']);
                      await prefs.setString("worker_email", userData['email']);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkerHomePage(),
                        ),
                      );
                    } else if (userType == UserType.organization) {
                      final orgId = prefs.getInt('orgId');
                      final orgType = prefs.getString('orgType');
                      if (kDebugMode) {
                        print(
                            'AccountPreviewPage: orgId=$orgId, orgType=$orgType');
                      }
                      if (orgId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Organization ID not found. Please log in again.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const WelcomePage()),
                          (Route<dynamic> route) => false,
                        );
                        return;
                      }
                      await prefs.setBool("loggedIn", true);
                      await prefs.setString("userType", "organization");
                      await prefs.setString("orgName", userData['orgName']);
                      await prefs.setString(
                          "orgAddress", userData['orgAddress']);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrganizationHomePage(
                            orgName: userData['orgName'],
                            orgAddress: userData['orgAddress'],
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
