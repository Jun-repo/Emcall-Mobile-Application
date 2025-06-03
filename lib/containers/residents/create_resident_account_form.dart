// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

  final List<String> suffixes = ['', 'Jr.', 'Sr.', 'II', 'III', 'IV'];
  final _formKey = GlobalKey<FormState>();

  OutlineInputBorder get customInputBorder {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(
        color: Color.fromARGB(255, 198, 198, 198),
        width: 0.7,
      ),
    );
  }

  void _showNoNetworkSnackBar({
    Duration duration = _snackBarDisplayDuration,
    Animation<double>? animation,
  }) {
    final snack = SnackBar(
      content: const Text(
          'No Internet Connection, \nBro! checked your network data/wifi before login...'),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
      backgroundColor: Colors.redAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      duration: duration,
      animation: animation,
    );

    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

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

    // Check network connectivity
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showNoNetworkSnackBar();
      setState(() => _isLoading = false);
      return;
    } else if (result == ConnectivityResult.mobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’re on mobile data. Charges may apply.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }

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
        await _showUsernameTakenDialog(context);
        return;
      }

      String? profileImageUrl;
      if (_profileImage != null) {
        final fullNameForImage = '${firstName}_$lastName'.replaceAll(' ', '_');
        final formattedDate =
            DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
        final fileName = 'profile_${fullNameForImage}_$formattedDate.jpg';
        final filePath = 'id/$username/$fileName';

        await supabase.storage
            .from('profileimages')
            .upload(filePath, _profileImage!);
        profileImageUrl =
            supabase.storage.from('profileimages').getPublicUrl(filePath);
      }

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
            'profile_image': profileImageUrl,
          })
          .select('id')
          .single();

      final int residentId = insertedData['id'];

      await prefs.setBool("loggedIn", true);
      await prefs.setString("userType", "resident");
      await prefs.setString("username", username);
      await prefs.setInt("resident_id", residentId);
      await prefs.setString("personal_email", email);

      await _showCompletionDialog(context, residentId);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception')) {
        _showNoNetworkSnackBar();
      } else if (errorStr.contains('timeout') || errorStr.contains('slow')) {
        await _showSlowNetworkWarningDialog(context);
      } else if (!errorStr.contains('username is already taken')) {
        await _showErrorDialog('Registration Failed', 'SERVER ERROR!!!');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
                            email: emailController.text.trim(),
                          ),
                          transitionsBuilder: (_, a, __, c) =>
                              FadeTransition(opacity: a, child: c),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Create Resident Account',
            style: TextStyle(fontFamily: 'Gilroy')),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(_profileImage!, fit: BoxFit.cover)
                            : const Icon(Icons.person,
                                size: 50, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          if (_profileImage != null) {
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
                            color: Colors.redAccent,
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
              TextFormField(
                controller: firstNameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'First Name',
                  hintText: 'Enter your first name',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: middleNameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Middle Name',
                  hintText: 'Enter your middle name',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: lastNameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  hintText: 'Enter your last name',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedSuffix,
                decoration: InputDecoration(
                  labelText: 'Suffix',
                  hintText: 'Select suffix',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
                items: suffixes
                    .map((suffix) => DropdownMenuItem(
                          value: suffix,
                          child: Text(suffix.isEmpty ? 'None' : suffix),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedSuffix = value),
                borderRadius: BorderRadius.circular(8.0),
                icon:
                    const Icon(Icons.arrow_drop_down, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter your email',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.email_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.phone_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (!RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(value)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: usernameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: customInputBorder,
                  enabledBorder: customInputBorder,
                  focusedBorder: customInputBorder.copyWith(
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              PasswordField(
                customInputBorder: customInputBorder,
                controller: passwordController,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  if (value.length < 8)
                    return 'Password must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 22, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
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

class PasswordField extends StatefulWidget {
  final OutlineInputBorder customInputBorder;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const PasswordField({
    super.key,
    required this.customInputBorder,
    this.controller,
    this.validator,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Colors.redAccent,
      style: const TextStyle(fontSize: 20, color: Colors.black),
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: 'Password *',
        hintText: 'Enter your password',
        filled: true,
        fillColor: Colors.grey[100],
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 20),
        prefixIcon: const Icon(Icons.lock_rounded),
        border: widget.customInputBorder,
        enabledBorder: widget.customInputBorder,
        focusedBorder: widget.customInputBorder.copyWith(
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      validator: widget.validator,
    );
  }
}
