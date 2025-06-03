import 'package:cached_network_image/cached_network_image.dart';
import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/containers/residents/pages/map_settings_page.dart';
import 'package:emcall/containers/residents/pages/permissions_page.dart';
import 'package:emcall/containers/residents/pages/terms_and_policies_page.dart';
import 'package:emcall/pages/passwords/forgot_password_page.dart';
import 'package:emcall/pages/passwords/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'account_page.dart';
import 'feedback_page.dart';
import 'privacy_page.dart';
import 'rate_us_page.dart';
import 'security_page.dart';

class ResidentProfilePage extends StatefulWidget {
  const ResidentProfilePage({super.key});

  @override
  ResidentProfilePageState createState() => ResidentProfilePageState();
}

class ResidentProfilePageState extends State<ResidentProfilePage> {
  String? fullName;
  String? profileImageUrl;
  bool isLoading = true;
  int? residentId;

  @override
  void initState() {
    super.initState();
    fetchResidentIdAndData();
  }

  Future<void> fetchResidentIdAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedResidentId = prefs.getInt('resident_id');

    if (storedResidentId == null) {
      setState(() {
        isLoading = false;
        fullName = 'Error: No resident ID found';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: No resident ID found in session')),
        );
      }
      return;
    }

    setState(() {
      residentId = storedResidentId;
    });

    await fetchResidentData();
  }

  Future<void> fetchResidentData() async {
    if (residentId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('residents')
          .select('first_name, middle_name, last_name, profile_image')
          .eq('id', residentId!)
          .single();

      setState(() {
        final firstName = response['first_name'] ?? '';
        final middleName = response['middle_name'] ?? '';
        final lastName = response['last_name'] ?? '';
        fullName = [firstName, middleName, lastName]
            .where((name) => name.isNotEmpty)
            .join(' ');
        profileImageUrl = response['profile_image'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        fullName = 'Error loading name';
        profileImageUrl = null;
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging out...')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
    }
  }

  Future<void> _launchWebsite() async {
    const websiteUrl = 'https://sites.google.com/view/emcall-app/home';
    final Uri uri = Uri.parse(websiteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open website')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.redAccent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
              child: CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double appBarHeight = constraints.biggest.height;
                final double maxHeight =
                    200.0 + MediaQuery.of(context).padding.top;
                final double minHeight =
                    kToolbarHeight + MediaQuery.of(context).padding.top;
                final double scrollPercentage =
                    ((appBarHeight - minHeight) / (maxHeight - minHeight))
                        .clamp(0.0, 1.0);

                final double scale = 1.5 - (0.5 * (1.0 - scrollPercentage));
                final double leftPadding =
                    16.0 + (115.0 * (1.0 - scrollPercentage));
                final double bottomPadding = 16.0 * scrollPercentage;

                final Color textColor = Color.lerp(
                  const Color.fromARGB(255, 34, 34, 34),
                  const Color.fromARGB(255, 244, 244, 244),
                  1.0 - scrollPercentage,
                )!;

                return FlexibleSpaceBar(
                  background: Container(color: Colors.white),
                  title: Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26.0, vertical: 12.0),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  titlePadding:
                      EdgeInsets.only(left: leftPadding, bottom: bottomPadding),
                );
              },
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.only(
                    top: 8.0, left: 16.0, right: 16.0, bottom: 8.0),
                child: Row(
                  children: [
                    const Text(
                      'Account',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.redAccent,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : (profileImageUrl != null &&
                                profileImageUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: profileImageUrl!,
                                imageBuilder: (context, imageProvider) =>
                                    Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover),
                                  ),
                                ),
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person,
                                        size: 40, color: Colors.white),
                              )
                            : const Icon(Icons.person,
                                size: 40, color: Colors.white),
                  ),
                ),
                title: isLoading
                    ? const Text('Loading...')
                    : Text(fullName ?? 'No name available',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87)),
                subtitle: const Text('Personal Info',
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          AccountPage(
                        fullName: fullName ?? 'Unknown',
                        profileImageUrl: profileImageUrl,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  ).then((_) => fetchResidentData());
                },
              ),
              const Padding(
                padding: EdgeInsets.only(
                    top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Text(
                  'General',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.lock, color: Colors.white),
                ),
                title: const Text('Permissions',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const PermissionsPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.blueGrey, shape: BoxShape.circle),
                  child: const Icon(Icons.map, color: Colors.white),
                ),
                title: const Text('Map Settings',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const MapSettingsPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.only(
                    top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Text(
                  'Privacy & Security',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.teal, shape: BoxShape.circle),
                  child: const Icon(Icons.description, color: Colors.white),
                ),
                title: const Text('Terms & Policies',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const TermsAndPoliciesPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.indigo, shape: BoxShape.circle),
                  child: const Icon(Icons.key, color: Colors.white),
                ),
                title: const Text('Change Password',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  if (residentId != null) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ResetPasswordPage(
                          userType: 'resident',
                          userId: residentId!,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          var offsetAnimation = animation.drive(tween);

                          return SlideTransition(
                              position: offsetAnimation, child: child);
                        },
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Error: Resident ID not found')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.cyan, shape: BoxShape.circle),
                  child: const Icon(Icons.privacy_tip, color: Colors.white),
                ),
                title: const Text('Privacy',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const PrivacyPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.deepPurple, shape: BoxShape.circle),
                  child: const Icon(Icons.security, color: Colors.white),
                ),
                title: const Text('Security',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SecurityPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.only(
                    top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Text(
                  'Support',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.feedback, color: Colors.white),
                ),
                title: const Text('Feedback',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const FeedbackPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.orangeAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.white),
                ),
                title: const Text('Rate Us',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const RateUsPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.pink, shape: BoxShape.circle),
                  child: const Icon(Icons.help, color: Colors.white),
                ),
                title: const Text('Help',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: _launchWebsite,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.lightBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.support, color: Colors.white),
                ),
                title: const Text('Support',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: _launchWebsite,
              ),
              const Padding(
                padding: EdgeInsets.only(
                    top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Text(
                  'Session Management',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.deepOrange, shape: BoxShape.circle),
                  child: const Icon(Icons.restore, color: Colors.white),
                ),
                title: const Text('Account Recovery',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const ForgotPasswordPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.logout, color: Colors.white),
                ),
                title: const Text('Logout',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 25),
            ]),
          ),
        ],
      ),
    );
  }
}
