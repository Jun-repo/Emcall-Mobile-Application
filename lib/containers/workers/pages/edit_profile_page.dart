import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> workerData;
  final VoidCallback onProfileUpdated;

  const EditProfilePage({
    super.key,
    required this.workerData,
    required this.onProfileUpdated,
  });

  @override
  EditProfilePageState createState() => EditProfilePageState();
}

class EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _suffixNameController;
  late TextEditingController _usernameController;
  late TextEditingController _addressController;
  late TextEditingController _birthDateController;
  late TextEditingController _statusController;
  late TextEditingController _genderController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.workerData['first_name']);
    _middleNameController =
        TextEditingController(text: widget.workerData['middle_name']);
    _lastNameController =
        TextEditingController(text: widget.workerData['last_name']);
    _suffixNameController =
        TextEditingController(text: widget.workerData['suffix_name']);
    _usernameController =
        TextEditingController(text: widget.workerData['username']);
    _addressController =
        TextEditingController(text: widget.workerData['address']);
    _birthDateController =
        TextEditingController(text: widget.workerData['birth_date']);
    _statusController =
        TextEditingController(text: widget.workerData['status']);
    _genderController =
        TextEditingController(text: widget.workerData['gender']);
    _emailController =
        TextEditingController(text: widget.workerData['personal_email']);
    _phoneController = TextEditingController(text: widget.workerData['phone']);
    _profileImageUrl = widget.workerData['profile_image'];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixNameController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    _statusController.dispose();
    _genderController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    try {
      final updates = {
        'first_name': _firstNameController.text,
        'middle_name': _middleNameController.text,
        'last_name': _lastNameController.text,
        'suffix_name': _suffixNameController.text,
        'username': _usernameController.text,
        'address': _addressController.text,
        'birth_date': _birthDateController.text,
        'status': _statusController.text,
        'gender': _genderController.text,
        'personal_email': _emailController.text,
        'phone': _phoneController.text,
        'profile_image': _profileImageUrl,
      };

      await Supabase.instance.client
          .from('workers')
          .update(updates)
          .eq('id', widget.workerData['id']);

      widget.onProfileUpdated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error updating profile. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final workerId = widget.workerData['id'].toString();
        final workerName = widget.workerData['first_name'].toString();
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

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Use Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      filled: true,
      fillColor: Colors.white70,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.black, width: 0.7),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.redAccent, width: 0.7),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.black, width: 0.7),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: _updateProfile,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _showImageSourceBottomSheet,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImageUrl != null &&
                                _profileImageUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(_profileImageUrl!)
                            : null,
                        child: _profileImageUrl == null ||
                                _profileImageUrl!.isEmpty
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _pickImage(ImageSource.camera),
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
                const SizedBox(height: 24),
                TextField(
                  controller: _firstNameController,
                  decoration: _inputDecoration('First Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _lastNameController,
                  decoration: _inputDecoration('Last Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: _inputDecoration('E mail address'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: _inputDecoration('User name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: _inputDecoration('Phone number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: _inputDecoration('Address'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _birthDateController,
                  decoration: _inputDecoration('Birth Date'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _statusController,
                  decoration: _inputDecoration('Status'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _genderController,
                  decoration: _inputDecoration('Gender'),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 80,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
