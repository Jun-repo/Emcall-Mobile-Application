import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emcall/pages/passwords/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_page.dart';

class ViewProfilePage extends StatefulWidget {
  final String workerName;
  final int? workerId;

  const ViewProfilePage(
      {super.key, required this.workerName, required this.workerId});

  @override
  ViewProfilePageState createState() => ViewProfilePageState();
}

class ViewProfilePageState extends State<ViewProfilePage> {
  Map<String, dynamic>? workerData;
  bool isLoading = true;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  Future<void> _loadWorkerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('worker_email');

      if (email == null) {
        _showErrorSnackBar('worker authentication');
        return;
      }

      final response = await Supabase.instance.client
          .from('workers')
          .select()
          .eq('personal_email', email)
          .single();

      setState(() {
        workerData = response;
        _profileImageUrl = workerData!['profile_image'];
        isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('worker profile');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String component) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Error loading $component. Please try again.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final workerId = workerData!['id'].toString();
        final workerName = workerData!['first_name'].toString();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'profile_image/$workerId/$workerName/$fileName';

        // Upload the image to Supabase storage
        await Supabase.instance.client.storage
            .from('workersuploadprofile')
            .upload(path, file);

        // Get the public URL of the uploaded image
        final newImageUrl = Supabase.instance.client.storage
            .from('workersuploadprofile')
            .getPublicUrl(path);

        // Update the worker's profile image URL in the database
        await Supabase.instance.client
            .from('workers')
            .update({'profile_image': newImageUrl}).eq('id', workerData!['id']);

        setState(() {
          _profileImageUrl = newImageUrl;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error uploading image.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _navigateToEditProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditProfilePage(
          workerData: workerData!,
          onProfileUpdated: _loadWorkerProfile,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 0;
    final birth = DateTime.parse(birthDate);
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality here if needed
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : workerData == null
              ? const Center(child: Text('Failed to load profile'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        _profileImageUrl!)
                                    : null,
                                child: _profileImageUrl == null ||
                                        _profileImageUrl!.isEmpty
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickImageFromCamera,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${workerData!['first_name']} ${workerData!['last_name']}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${workerData!['username']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _navigateToEditProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  child: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                        children: [
                          _buildGridCard(
                            icon: Icons.person,
                            title: 'Status',
                            value: workerData!['status'] ?? 'N/A',
                          ),
                          _buildGridCard(
                            icon: Icons.wc,
                            title: 'Gender',
                            value: workerData!['gender'] ?? 'N/A',
                          ),
                          _buildGridCard(
                            icon: Icons.cake,
                            title: 'Age',
                            value: _calculateAge(workerData!['birth_date'])
                                .toString(),
                          ),
                          _buildGridCard(
                            icon: Icons.business,
                            title: 'Org Type',
                            value: workerData!['organization_type'] ?? 'N/A',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildActionButton(
                        icon: Icons.lock,
                        title: 'Change Password',
                        onTap: _navigateToForgotPassword,
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.location_on,
                        title: 'Address',
                        value: workerData!['address'] ?? 'N/A',
                        onTap: () {},
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.email,
                        title: 'Email',
                        value: workerData!['personal_email'] ?? 'N/A',
                        onTap: () {},
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        icon: Icons.phone,
                        title: 'Phone',
                        value: workerData!['phone'] ?? 'N/A',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.grey, width: 0.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    String? value,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: value != null
            ? Text(
                value,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
