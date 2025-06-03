// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:emcall/containers/workers/pages/worker_home_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateWorkerAccountForm extends StatefulWidget {
  final String orgType;
  final String? initialProductKey;
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialEmail;
  final String? initialUsername;

  const CreateWorkerAccountForm({
    super.key,
    required this.orgType,
    this.initialProductKey,
    this.initialFirstName,
    this.initialLastName,
    this.initialEmail,
    this.initialUsername,
  });

  @override
  CreateWorkerAccountFormState createState() => CreateWorkerAccountFormState();
}

class CreateWorkerAccountFormState extends State<CreateWorkerAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController productKeyController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // Populate fields with initial data if provided
    if (widget.initialProductKey != null) {
      productKeyController.text = widget.initialProductKey!;
    }
    if (widget.initialFirstName != null) {
      firstNameController.text = widget.initialFirstName!;
    }
    if (widget.initialLastName != null) {
      lastNameController.text = widget.initialLastName!;
    }
    if (widget.initialEmail != null) {
      emailController.text = widget.initialEmail!;
    }
    if (widget.initialUsername != null) {
      usernameController.text = widget.initialUsername!;
    }
  }

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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    // Check network connectivity
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.wifi) {
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
    } else if (result == ConnectivityResult.none) {
      _showNoNetworkSnackBar();
      setState(() => _isLoading = false);
      return;
    }

    try {
      final productKeyResponse = await supabase
          .from('product_keys')
          .select()
          .eq('key', productKeyController.text.trim())
          .eq('organization_type', widget.orgType)
          .eq('is_used', false)
          .maybeSingle();

      if (productKeyResponse == null) {
        throw 'Invalid or used product key';
      }

      final organizationId = productKeyResponse['organization_id'];

      final workerData = {
        'organization_type': widget.orgType,
        'organization_id': organizationId,
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'personal_email': emailController.text.trim(),
        'username': usernameController.text.trim(),
        'password_hash':
            BCrypt.hashpw(passwordController.text.trim(), BCrypt.gensalt()),
      };

      final workerResponse =
          await supabase.from('workers').insert(workerData).select().single();

      await supabase.from('product_keys').update({
        'is_used': true,
        'used_at': DateTime.now().toIso8601String(),
      }).eq('key', productKeyController.text.trim());

      await prefs.setBool("loggedIn", true);
      await prefs.setString("userType", "worker");
      await prefs.setString("worker_email", emailController.text.trim());
      await prefs.setString("username", usernameController.text.trim());
      await prefs.setString("worker_id", workerResponse['id'].toString());
      await prefs.setString("firstName", firstNameController.text.trim());
      await prefs.setString("lastName", lastNameController.text.trim());
      await prefs.setString("middleName", '');
      await prefs.setString("suffix", '');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerSuccessPage(
            firstName: firstNameController.text.trim(),
            lastName: lastNameController.text.trim(),
            email: emailController.text.trim(),
            username: usernameController.text.trim(),
            orgType: widget.orgType,
          ),
        ),
      );
    } catch (e) {
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkerFailurePage(
              errorMessage: e.toString(),
              orgType: widget.orgType,
              productKey: productKeyController.text.trim(),
              firstName: firstNameController.text.trim(),
              lastName: lastNameController.text.trim(),
              email: emailController.text.trim(),
              username: usernameController.text.trim(),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create ${widget.orgType[0].toUpperCase()}${widget.orgType.substring(1)} Worker Account',
                style: const TextStyle(fontSize: 35, fontFamily: 'Gilroy'),
              ),
              const Text(
                'Please fill in the details to continue.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: productKeyController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Product Key *',
                  hintText: 'Enter your product key',
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle:
                      const TextStyle(color: Colors.black54, fontSize: 20),
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
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
              TextFormField(
                controller: firstNameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'First Name *',
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
              TextFormField(
                controller: lastNameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Last Name *',
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
              TextFormField(
                controller: emailController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email *',
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
                controller: usernameController,
                cursorColor: Colors.redAccent,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Username *',
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
                validator: (value) => value!.isEmpty ? 'Required' : null,
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
    productKeyController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
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

class WorkerSuccessPage extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String orgType;

  const WorkerSuccessPage({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.orgType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.redAccent,
                  size: 120,
                ),
                const SizedBox(height: 20),
                Text(
                  'Account Created!',
                  style: const TextStyle(
                    fontSize: 35,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your ${orgType[0].toUpperCase()}${orgType.substring(1)} Worker account has been successfully created!',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Details',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(Icons.person_rounded, 'Name',
                            '$firstName $lastName'),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.email_rounded, 'Email', email),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                            Icons.person_rounded, 'Username', username),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.work_rounded, 'Organization',
                            '${orgType[0].toUpperCase()}${orgType.substring(1)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkerHomePage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      "Let's Go!",
                      style: TextStyle(fontSize: 22, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.redAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WorkerFailurePage extends StatelessWidget {
  final String errorMessage;
  final String orgType;
  final String productKey;
  final String firstName;
  final String lastName;
  final String email;
  final String username;

  const WorkerFailurePage({
    super.key,
    required this.errorMessage,
    required this.orgType,
    required this.productKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_rounded,
                  color: Colors.redAccent,
                  size: 120,
                ),
                const SizedBox(height: 20),
                Text(
                  'Account Creation Failed',
                  style: const TextStyle(
                    fontSize: 35,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Failed to create your ${orgType[0].toUpperCase()}${orgType.substring(1)} Worker account.',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Error Details',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                            Icons.error_outline, 'Error', errorMessage),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateWorkerAccountForm(
                            orgType: orgType,
                            initialProductKey: productKey,
                            initialFirstName: firstName,
                            initialLastName: lastName,
                            initialEmail: email,
                            initialUsername: username,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(fontSize: 22, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.redAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
