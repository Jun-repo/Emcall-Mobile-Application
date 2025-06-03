import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/pages/passwords/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final String userType;
  final int userId;

  const ResetPasswordPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _resetPassword() async {
    if (_passwordController.text != _confirmController.text) {
      _showError('Both passwords must match.');
      return;
    }
    if (_passwordController.text.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final hashedPassword =
        BCrypt.hashpw(_passwordController.text, BCrypt.gensalt());

    try {
      String tableName;
      if (widget.userType == 'resident') {
        tableName = 'residents';
      } else if (widget.userType == 'worker') {
        tableName = 'workers';
      } else if (widget.userType == 'disaster_responder') {
        tableName = 'disaster_responders';
      } else {
        tableName = widget.userType;
      }

      final updateData =
          (widget.userType == 'resident' || widget.userType == 'worker')
              ? {'password_hash': hashedPassword}
              : {'org_password_hash': hashedPassword};

      await supabase.from(tableName).update(updateData).eq('id', widget.userId);

      // Show success bottom sheet
      if (mounted) {
        _showSuccessBottomSheet(context);
      }
    } catch (e, stackTrace) {
      debugPrint("Error resetting password: $e");
      debugPrint(stackTrace.toString());
      _showError('Password reset failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String> _fetchUserName() async {
    final supabase = Supabase.instance.client;
    try {
      if (widget.userType == 'resident') {
        final response = await supabase
            .from('residents')
            .select('username')
            .eq('id', widget.userId)
            .single();
        return response['username'] ?? 'User';
      } else if (widget.userType == 'worker') {
        final response = await supabase
            .from('workers')
            .select('username')
            .eq('id', widget.userId)
            .single();
        return response['username'] ?? 'User';
      } else {
        // For organization types (police, rescue, firefighter, disaster_responder)
        final tableName = widget.userType == 'disaster_responder'
            ? 'disaster_responders'
            : widget.userType;
        final response = await supabase
            .from(tableName)
            .select('public_org_name')
            .eq('id', widget.userId)
            .single();
        return response['public_org_name'] ?? 'User';
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
      return 'User'; // Fallback if fetch fails
    }
  }

  void _showSuccessBottomSheet(BuildContext context) async {
    final userName = await _fetchUserName();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // Transparent background for floating effect
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(
            16, 0, 16, 24), // Margin on sides and bottom
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20), // Rounded corners on all sides
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close icon
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: CircleAvatar(
                    backgroundColor: const Color.fromARGB(51, 158, 158, 158),
                    child: Icon(Icons.close_rounded, color: Colors.grey)),
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  _navigateToWelcomePage(context);
                },
              ),
            ),
            // Success icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Successfully',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$userName! You nailed it! You have successfully reset password for your account.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close bottom sheet
                  _navigateToWelcomePage(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToWelcomePage(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => const WelcomePage()), // Adjust as needed
      (route) => false, // Clear the entire navigation stack
    );
  }

  void _navigateToForgotPassword(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 120),
                  const Text(
                    'Create new password',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your new password must be different from previous used passwords.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter new password',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8.0),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.0,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Must be at least 8 characters.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Confirm new password',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8.0),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.0,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Both passwords must match.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _navigateToForgotPassword(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 48,
                width: 48,
                child: FloatingActionButton(
                  onPressed: () => Navigator.pop(context),
                  elevation: 4,
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.redAccent,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
