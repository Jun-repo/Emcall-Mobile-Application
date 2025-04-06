// ignore_for_file: use_build_context_synchronously

import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/containers/residents/create_resident_account_form.dart';
import 'package:emcall/containers/organizations/create_organization_account_form.dart';
import 'package:emcall/containers/workers/create_worker_account_form.dart';
import 'package:emcall/pages/passwords/forgot_password_page.dart';
import 'package:emcall/containers/organizations/pages/organization_home_page.dart';
import 'package:emcall/containers/residents/pages/resident_home_page.dart';
import 'package:emcall/containers/workers/pages/worker_home_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  LoginFormState createState() => LoginFormState();
}

class LoginFormState extends State<LoginForm> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  OutlineInputBorder get customInputBorder {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: const BorderSide(
        color: Colors.blue,
        width: 1.5,
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    _showLoadingDialog(); // Show loading dialog
    final supabase = Supabase.instance.client;
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    bool loginSuccessful = false;

    try {
      // Check Residents
      final residentResponse = await supabase
          .from('residents')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (residentResponse != null) {
        final storedHash = residentResponse['password_hash'] as String;
        if (BCrypt.checkpw(password, storedHash)) {
          loginSuccessful = true;
          final residentId = residentResponse['id'];
          final firstName = residentResponse['first_name'] ?? '';
          final middleName = residentResponse['middle_name'] ?? '';
          final lastName = residentResponse['last_name'] ?? '';
          final suffix = residentResponse['suffix_name'] ?? '';
          final email = residentResponse['personal_email'] ?? '';
          final address = residentResponse['address'] ?? '';
          await prefs.setBool("loggedIn", true);
          await prefs.setString("userType", "resident");
          await prefs.setString("username", username);
          await prefs.setInt("resident_id", residentId);
          await prefs.setString("firstName", firstName);
          await prefs.setString("middleName", middleName);
          await prefs.setString("lastName", lastName);
          await prefs.setString("suffix", suffix);
          await prefs.setString("personal_email", email);
          await prefs.setString("address", address);

          // Dismiss the loading dialog before navigation
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResidentHomePage(
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                suffix: suffix,
                address: address,
              ),
            ),
          );
          return;
        }
      }

      // Check Workers
      final workerResponse = await supabase
          .from('workers')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (workerResponse != null) {
        final storedHash = workerResponse['password_hash'] as String;
        if (BCrypt.checkpw(password, storedHash)) {
          loginSuccessful = true;
          final workerId = workerResponse['id'];
          final firstName = workerResponse['first_name'] ?? '';
          final middleName = workerResponse['middle_name'] ?? '';
          final lastName = workerResponse['last_name'] ?? '';
          final suffix = workerResponse['suffix_name'] ?? '';

          await prefs.setBool("loggedIn", true);
          await prefs.setString("userType", "worker");
          await prefs.setString("username", username);
          await prefs.setInt("worker_id", workerId);
          await prefs.setString("firstName", firstName);
          await prefs.setString("middleName", middleName);
          await prefs.setString("lastName", lastName);
          await prefs.setString("suffix", suffix);

          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const WorkerHomePage(),
            ),
          );
          return;
        }
      }

      // Check Organizations
      const serviceTables = [
        'police',
        'rescue',
        'firefighter',
        'disaster_responders'
      ];

      for (final table in serviceTables) {
        final orgResponse = await supabase
            .from(table)
            .select()
            .eq('public_org_name', username)
            .maybeSingle();

        if (orgResponse != null) {
          final storedHash = orgResponse['org_password_hash'] as String;
          if (BCrypt.checkpw(password, storedHash)) {
            loginSuccessful = true;
            final orgName = orgResponse['public_org_name'] ?? 'Organization';
            final orgAddress = orgResponse['address'] ?? 'Address not provided';

            await prefs.setBool("loggedIn", true);
            await prefs.setString("userType", "organization");
            await prefs.setString("orgName", orgName);
            await prefs.setString("orgAddress", orgAddress);

            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrganizationHomePage(
                  orgName: orgName,
                  orgAddress: orgAddress,
                ),
              ),
            );
            return;
          }
        }
      }

      // If no branch succeeded, show error.
      if (!loginSuccessful) {
        Navigator.pop(context); // dismiss loading dialog
        _showErrorDialog('Invalid Credentials.');
      }
    } catch (e) {
      Navigator.pop(context); // dismiss loading dialog
      _showErrorDialog('An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLoadingDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      barrierLabel: "Loading",
      barrierColor: Colors.black.withOpacity(0.5), // Dark overlay
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        // The pageBuilder is required but won't be used directly.
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close the dialog
              setState(() => _isLoading = false); // Stop loading
            },
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(40.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    color: Colors.redAccent,
                    strokeWidth: 8.0,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAccountTypeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to take up necessary height
      backgroundColor:
          Colors.transparent, // Transparent background for floating effect
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 20.0), // Padding around the sheet
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20.0),
                bottomRight: Radius.circular(20.0),
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              border: Border.all(color: Colors.blue, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5), // Shadow for floating effect
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose Account Type',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('Create Resident Account'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateResidentAccountForm(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Create Organization Account'),
                    onTap: () {
                      Navigator.pop(context);
                      _showOrganizationTypeBottomSheet(context,
                          isWorker: false);
                    },
                  ),
                  ListTile(
                    title: const Text('Create Worker Account'),
                    onTap: () {
                      Navigator.pop(context);
                      _showOrganizationTypeBottomSheet(context, isWorker: true);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOrganizationTypeBottomSheet(BuildContext context,
      {required bool isWorker}) {
    const orgTypes = ['police', 'rescue', 'firefighter', 'disaster'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20.0),
                bottomRight: Radius.circular(20.0),
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              border: Border.all(color: Colors.blue, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose ${isWorker ? 'Worker' : 'Organization'} Type',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...orgTypes
                      .map((type) => ListTile(
                            title: Text(
                                '${type[0].toUpperCase()}${type.substring(1)}'),
                            onTap: () {
                              Navigator.pop(context);
                              if (isWorker) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreateWorkerAccountForm(orgType: type),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreateOrganizationAccountForm(
                                      orgType: type,
                                      publicOrgName:
                                          '${type[0].toUpperCase()}${type.substring(1)}',
                                    ),
                                  ),
                                );
                              }
                            },
                          ))
                      // ignore: unnecessary_to_list_in_spreads
                      .toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 70),
                  const SizedBox(width: 10),
                  const Text(
                    'Emcall',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                        borderSide:
                            const BorderSide(color: Colors.blue, width: 2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  PasswordField(
                    customInputBorder: customInputBorder,
                    controller: passwordController,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ForgotPasswordPage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              final slideTween = Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeInOut));
                              final fadeTween =
                                  Tween<double>(begin: 0.0, end: 1.0);
                              return SlideTransition(
                                position: animation.drive(slideTween),
                                child: FadeTransition(
                                  opacity: animation.drive(fadeTween),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          side:
                              const BorderSide(color: Colors.blue, width: 1.5),
                        ),
                      ),
                      child:
                          const Text('Login', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          _showAccountTypeBottomSheet(context);
                        },
                        child: const Text('Create an Account'),
                      ),
                    ],
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

class PasswordField extends StatefulWidget {
  final OutlineInputBorder customInputBorder;
  final TextEditingController? controller;
  const PasswordField({
    super.key,
    required this.customInputBorder,
    this.controller,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: 'Password',
        border: widget.customInputBorder,
        enabledBorder: widget.customInputBorder,
        focusedBorder: widget.customInputBorder.copyWith(
          borderSide: const BorderSide(color: Colors.blue, width: 2.0),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue,
          ),
          onPressed: () {
            setState(() => _obscureText = !_obscureText);
          },
        ),
      ),
    );
  }
}
