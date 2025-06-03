// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/auth/forms/account_preview_page.dart';
import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/containers/residents/create_resident_account_form.dart';
import 'package:emcall/containers/organizations/create_organization_account_form.dart';
import 'package:emcall/containers/workers/create_worker_account_form.dart';
import 'package:emcall/pages/passwords/forgot_password_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'enums.dart';

class LoginForm extends StatefulWidget {
  final UserType userType;
  const LoginForm({super.key, required this.userType});

  @override
  LoginFormState createState() => LoginFormState();
}

class LoginFormState extends State<LoginForm> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
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

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        usernameController.text = prefs.getString('savedUsername') ?? '';
        passwordController.text = prefs.getString('savedPassword') ?? '';
      }
    });
  }

  Future<void> _saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('savedUsername', username);
      await prefs.setString('savedPassword', password);
    } else {
      await prefs.setBool('rememberMe', false);
      await prefs.remove('savedUsername');
      await prefs.remove('savedPassword');
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

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _showLoadingDialog();
    });

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
        ),
      );
    }

    final supabase = Supabase.instance.client;
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    try {
      if (widget.userType == UserType.resident) {
        final residentResponse = await supabase
            .from('residents')
            .select()
            .eq('username', username)
            .maybeSingle();
        if (residentResponse != null &&
            BCrypt.checkpw(password, residentResponse['password_hash'])) {
          final residentData = {
            'id': residentResponse['id'],
            'username': username,
            'firstName': residentResponse['first_name'] ?? '',
            'middleName': residentResponse['middle_name'] ?? '',
            'lastName': residentResponse['last_name'] ?? '',
            'suffix': residentResponse['suffix_name'] ?? '',
            'profileImage': residentResponse['profile_image'],
            'email': residentResponse['personal_email'] ?? '',
            'address': residentResponse['address'] ?? '',
          };
          await _saveCredentials(username, password);
          Navigator.pop(context);
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AccountPreviewPage(
                userType: widget.userType,
                userData: residentData,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final tween =
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.ease));
                return SlideTransition(
                    position: animation.drive(tween), child: child);
              },
            ),
          );
        } else {
          Navigator.pop(context);
          _showErrorDialog('Invalid or No credentials.');
        }
      } else if (widget.userType == UserType.worker) {
        final workerResponse = await supabase
            .from('workers')
            .select()
            .eq('username', username)
            .maybeSingle();
        if (workerResponse != null &&
            BCrypt.checkpw(password, workerResponse['password_hash'])) {
          final workerData = {
            'id': workerResponse['id'],
            'username': username,
            'firstName': workerResponse['first_name'] ?? '',
            'middleName': workerResponse['middle_name'] ?? '',
            'lastName': workerResponse['last_name'] ?? '',
            'suffix': workerResponse['suffix_name'] ?? '',
            'profileImage': workerResponse['profile_image'],
            'email': workerResponse['personal_email'] ?? '',
          };
          await _saveCredentials(username, password);
          Navigator.pop(context);
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AccountPreviewPage(
                userType: widget.userType,
                userData: workerData,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final tween =
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.ease));
                return SlideTransition(
                    position: animation.drive(tween), child: child);
              },
            ),
          );
        } else {
          Navigator.pop(context);
          _showErrorDialog('Invalid or No credentials.');
        }
      } else if (widget.userType == UserType.organization) {
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
          if (orgResponse != null &&
              BCrypt.checkpw(password, orgResponse['org_password_hash'])) {
            final orgId = orgResponse['id'] as int;
            final orgData = {
              'orgId': orgId,
              'orgName': orgResponse['public_org_name'] ?? 'Organization',
              'orgAddress': orgResponse['address'] ?? 'Address not provided',
              'orgType': table,
              'username': username,
            };

            // Save orgId and orgType to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('orgId', orgId);
            await prefs.setString('orgType', table);
            if (kDebugMode) {
              print('Saved to SharedPreferences: orgId=$orgId, orgType=$table');
            }

            await _saveCredentials(username, password);
            Navigator.pop(context);
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    AccountPreviewPage(
                  userType: widget.userType,
                  userData: orgData,
                ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  final tween =
                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                          .chain(CurveTween(curve: Curves.ease));
                  return SlideTransition(
                      position: animation.drive(tween), child: child);
                },
              ),
            );
            return;
          }
        }
        Navigator.pop(context);
        _showErrorDialog('Invalid or No credentials.');
      }
    } catch (e) {
      Navigator.pop(context);
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showNoNetworkSnackBar();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLoadingDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Loading",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
          ),
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
                        offset: const Offset(0, 5))
                  ],
                ),
                child: const CircularProgressIndicator(
                    color: Colors.redAccent,
                    strokeWidth: 8.0,
                    strokeCap: StrokeCap.round),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        title: const Text(
          'Failed to Login',
          style: TextStyle(fontFamily: 'Gilroy', color: Colors.black),
        ),
        content: Text(
          message,
          style: TextStyle(
              fontSize: 16, color: const Color.fromARGB(255, 26, 26, 26)),
        ),
        actionsPadding: EdgeInsets.only(
          top: 25,
          bottom: 20,
          left: 25,
          right: 25,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
              ),
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCreateAccount(BuildContext context) {
    if (widget.userType == UserType.resident) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateResidentAccountForm(),
        ),
      );
    } else if (widget.userType == UserType.worker) {
      _showOrganizationTypeBottomSheet(context, isWorker: true);
    } else if (widget.userType == UserType.organization) {
      _showOrganizationTypeBottomSheet(context, isWorker: false);
    }
  }

  void _showOrganizationTypeBottomSheet(BuildContext context,
      {required bool isWorker}) {
    const orgTypes = ['police', 'rescue', 'firefighter', 'disaster'];
    final orgIcons = {
      'police': Icons.local_police,
      'rescue': Icons.medical_services,
      'firefighter': Icons.local_fire_department,
      'disaster': Icons.warning,
    };
    // Mapping for table names
    final orgTypeToTableName = {
      'police': 'police',
      'rescue': 'rescue',
      'firefighter': 'firefighter',
      'disaster': 'disaster_responders',
    };

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
                topLeft: customRadius,
                topRight: customRadius,
                bottomLeft: customRadius,
                bottomRight: customRadius,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
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
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.2,
                    children: orgTypes.map((type) {
                      return GestureDetector(
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
                                  orgType: orgTypeToTableName[
                                      type]!, // Use mapped table name
                                  publicOrgName:
                                      '${type[0].toUpperCase()}${type.substring(1)}',
                                ),
                              ),
                            );
                          }
                        },
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: const BorderSide(
                                color: Colors.redAccent, width: 0.7),
                          ),
                          elevation: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                orgIcons[type],
                                color: Colors.redAccent,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${type[0].toUpperCase()}${type.substring(1)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                value: 0.66, // Step 2 of 3
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
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Skip',
                style: TextStyle(color: Colors.black54, fontFamily: 'Gilroy')),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(height: 40),
                    Image.asset('assets/images/logo.png', height: 25),
                    const SizedBox(width: 5),
                    const Text('Emcall',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 60),
                const Text('Kamusta,\nWelcome back!',
                    style: TextStyle(fontSize: 35, fontFamily: 'Gilroy')),
                const Text(
                  'Please sign in to continue.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  cursorColor: Colors.redAccent,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.black,
                  ),
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: const TextStyle(
                      color: Colors.black54,
                      fontSize: 20,
                    ),
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: customInputBorder,
                    enabledBorder: customInputBorder,
                    focusedBorder: customInputBorder.copyWith(
                        borderSide: const BorderSide(
                            color: Colors.redAccent, width: 1.0)),
                  ),
                ),
                const SizedBox(height: 20),
                PasswordField(
                  customInputBorder: customInputBorder,
                  controller: passwordController,
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: Colors.redAccent,
                      onChanged: (value) =>
                          setState(() => _rememberMe = value!),
                    ),
                    const Text(
                      'Remember me',
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                    Expanded(
                      child: Align(
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
                                          end: Offset.zero)
                                      .chain(
                                          CurveTween(curve: Curves.easeInOut));
                                  final fadeTween =
                                      Tween<double>(begin: 0.0, end: 1.0);
                                  return SlideTransition(
                                      position: animation.drive(slideTween),
                                      child: FadeTransition(
                                          opacity: animation.drive(fadeTween),
                                          child: child));
                                },
                              ),
                            );
                          },
                          label: const Text(
                            'Forgot Password?',
                            style:
                                TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Login',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                        )),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => _navigateToCreateAccount(context),
                      child: const Text(
                        'Create an Account',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ],
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
  const PasswordField(
      {super.key, required this.customInputBorder, this.controller});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      cursorColor: Colors.redAccent,
      style: const TextStyle(
        fontSize: 20,
        color: Colors.black,
      ),
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        filled: true,
        fillColor: Colors.grey[100],
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontSize: 20,
        ),
        prefixIcon: const Icon(Icons.lock_rounded),
        border: widget.customInputBorder,
        enabledBorder: widget.customInputBorder,
        focusedBorder: widget.customInputBorder.copyWith(
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.0)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
    );
  }
}

const customRadius = Radius.circular(26.0);
