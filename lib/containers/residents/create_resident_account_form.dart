// CreateResidentAccountForm.dart
// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/containers/residents/complete_resident_account_form.dart';
import 'package:emcall/containers/residents/pages/home_navigation_page.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateResidentAccountForm extends StatefulWidget {
  const CreateResidentAccountForm({super.key});

  @override
  _CreateResidentAccountFormState createState() =>
      _CreateResidentAccountFormState();
}

class _CreateResidentAccountFormState extends State<CreateResidentAccountForm> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? selectedSuffix;
  File? _profileImage;
  bool _isLoading = false;
  bool _isButtonPressed = false;

  final List<String> suffixes = ['', 'Jr.', 'Sr.', 'II', 'III', 'IV'];
  final _formKey = GlobalKey<FormState>();

  // Design constants
  static const _inputBorderRadius = 12.0;
  static const _buttonBorderRadius = 15.0;
  static const _animationDuration = Duration(milliseconds: 200);
  static const _primaryColor = Color(0xFF2962FF);
  static const _errorColor = Color(0xFFD32F2F);

  InputDecoration _inputDecoration(String label, {bool isRequired = true}) {
    return InputDecoration(
      labelText: '$label${isRequired ? ' *' : ''}',
      labelStyle: const TextStyle(color: _primaryColor),
      floatingLabelStyle: const TextStyle(color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputBorderRadius),
          borderSide: const BorderSide(color: _errorColor)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputBorderRadius),
          borderSide: const BorderSide(color: _errorColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(color: _errorColor),
    );
  }

  // Open the gallery after showing the warning.
  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // Show warning dialog before opening the gallery.
  Future<void> _showGalleryWarningDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info, size: 60, color: Colors.orange),
            SizedBox(height: 20),
            Text("Stay humble, profile loads more time."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openGallery();
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    try {
      final firstName = firstNameController.text.trim();
      final middleName = middleNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final suffix = selectedSuffix?.isEmpty ?? true ? null : selectedSuffix;
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final username = usernameController.text.trim();
      final password = passwordController.text.trim();

      // Check username uniqueness
      final usernameCheck = await supabase
          .from('residents')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (usernameCheck != null) {
        throw 'Username is already taken.';
      }

      String? profileImageUrl;
      // If image is provided, upload and get the URL
      if (_profileImage != null) {
        final fullNameForImage = '${firstName}_$lastName'.replaceAll(' ', '_');
        final formattedDate =
            DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
        final fileName = 'profile_${fullNameForImage}_$formattedDate.jpg';
        final filePath =
            'id/$username/$fileName'; // using username as a unique folder

        // Upload the image
        await supabase.storage
            .from('profileimages')
            .upload(filePath, _profileImage!);
        profileImageUrl =
            supabase.storage.from('profileimages').getPublicUrl(filePath);
      }

      // Insert all user data in one operation
      final insertedData = await supabase
          .from('residents')
          .insert({
            'first_name': firstName,
            'middle_name': middleName.isEmpty ? null : middleName,
            'last_name': lastName,
            'suffix_name': suffix,
            'personal_email': email,
            'phone': phone,
            'username': username,
            'password_hash': BCrypt.hashpw(password, BCrypt.gensalt()),
            'profile_image': profileImageUrl, // will be null if no image
          })
          .select('id')
          .single();

      final int residentId = insertedData['id'];

      // Save user session
      await prefs.setBool("loggedIn", true);
      await prefs.setString("userType", "resident");
      await prefs.setString("username", username);
      await prefs.setInt("resident_id", residentId);
      await prefs.setString("personal_email", email);

      await _showCompletionDialog(context, residentId);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('username is already taken')) {
        await _showUsernameTakenDialog(context);
      } else if (errorStr.contains('socketexception') ||
          errorStr.contains('no internet')) {
        await _showNoNetworkWarningDialog(context);
      } else if (errorStr.contains('timeout') || errorStr.contains('slow')) {
        await _showSlowNetworkWarningDialog(context);
      } else {
        _showErrorDialog('Registration Failed', 'SERVER ERROR!!!');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCompletionDialog(
      BuildContext context, int residentId) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              const Text('Account Created!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text('Would you like to complete your profile now?'),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeNavigationPage(
                            initialIndex: 1,
                          ),
                        ),
                      );
                    },
                    child: const Text('Skip'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              CompleteResidentAccountForm(
                            residentId: residentId,
                            firstName: firstNameController.text,
                            middleName: middleNameController.text,
                            lastName: lastNameController.text,
                            suffix: selectedSuffix ?? '',
                            email: emailController.text
                                .trim(), // Use emailController.text here
                          ),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_buttonBorderRadius),
                      ),
                    ),
                    child: const Text('Continue',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show a dialog specifically for username already taken.
  Future<void> _showUsernameTakenDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text("Username Taken"),
          ],
        ),
        content: const Text(
            "The username is already taken. Please choose another one."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Show a warning dialog for a slow network.
  Future<void> _showSlowNetworkWarningDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi, size: 60, color: Colors.orange),
            SizedBox(height: 20),
            Text("Network is slow. Please check your connection."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSignUp();
            },
            child: const Text("Reload"),
          ),
        ],
      ),
    );
  }

  // Show a warning dialog for no network connectivity.
  Future<void> _showNoNetworkWarningDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_wifi_off, size: 60, color: Colors.red),
            SizedBox(height: 20),
            Text("No network connection. Please connect to the internet."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSignUp();
            },
            child: const Text("Reload"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Resident Account'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with overlay icon that changes based on whether an image exists.
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: _animationDuration,
                      curve: Curves.easeInOut,
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryColor, width: 2),
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(_profileImage!, fit: BoxFit.cover)
                            : const Icon(Icons.person,
                                size: 50, color: Colors.grey),
                      ),
                    ),
                    // Overlay icon: shows close if image exists; otherwise camera.
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          if (_profileImage != null) {
                            // Remove image.
                            setState(() {
                              _profileImage = null;
                            });
                          } else {
                            _showGalleryWarningDialog();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primaryColor,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            _profileImage != null
                                ? Icons.close
                                : Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildFormField(firstNameController, 'First Name'),
              const SizedBox(height: 15),
              _buildFormField(middleNameController, 'Middle Name',
                  isRequired: false),
              const SizedBox(height: 15),
              _buildFormField(lastNameController, 'Last Name'),
              const SizedBox(height: 15),
              _buildSuffixDropdown(),
              const SizedBox(height: 25),
              _buildFormField(emailController, 'Email Address',
                  inputType: TextInputType.emailAddress),
              const SizedBox(height: 15),
              _buildFormField(phoneController, 'Phone Number',
                  inputType: TextInputType.phone),
              const SizedBox(height: 15),
              _buildFormField(usernameController, 'Username'),
              const SizedBox(height: 15),
              _buildPasswordField(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(TextEditingController controller, String label,
      {bool isRequired = true, TextInputType inputType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      decoration: _inputDecoration(label, isRequired: isRequired),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildSuffixDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSuffix,
      decoration: _inputDecoration('Suffix', isRequired: false),
      items: suffixes
          .map((suffix) => DropdownMenuItem(
                value: suffix,
                child: Text(suffix.isEmpty ? 'None' : suffix),
              ))
          .toList(),
      onChanged: (value) => setState(() => selectedSuffix = value),
      borderRadius: BorderRadius.circular(_inputBorderRadius),
      icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: passwordController,
      obscureText: true,
      decoration: _inputDecoration('Password'),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a password';
        if (value.length < 8) return 'Password must be at least 8 characters';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _isButtonPressed = true),
      onLongPressEnd: (_) => setState(() => _isButtonPressed = false),
      child: AnimatedContainer(
        duration: _animationDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
          boxShadow: _isButtonPressed
              ? []
              : [
                  BoxShadow(
                      color: _primaryColor.withOpacity(0.3), blurRadius: 8)
                ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSignUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_buttonBorderRadius)),
            elevation: _isButtonPressed ? 0 : 4,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Create Account', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
