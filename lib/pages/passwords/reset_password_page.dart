// reset_password_page.dart
import 'package:bcrypt/bcrypt.dart';
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

  Future<void> _resetPassword() async {
    if (_passwordController.text != _confirmController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final hashedPassword =
        BCrypt.hashpw(_passwordController.text, BCrypt.gensalt());

    try {
      String tableName;
      // Map user types to the correct table names:
      if (widget.userType == 'resident') {
        tableName = 'residents';
      } else if (widget.userType == 'worker') {
        tableName = 'workers';
      } else if (widget.userType == 'disaster_responder') {
        tableName = 'disaster_responders';
      } else {
        // For police, rescue, firefighter
        tableName = widget.userType;
      }

      // Choose the column name based on table type:
      final updateData =
          (widget.userType == 'resident' || widget.userType == 'worker')
              ? {'password_hash': hashedPassword}
              : {'org_password_hash': hashedPassword};

      await supabase.from(tableName).update(updateData).eq('id', widget.userId);

      // Go back to the first page after a successful update.
      // ignore: use_build_context_synchronously
      Navigator.popUntil(context, (route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                hintText: 'Enter new password',
              ),
              obscureText: true,
            ),
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Confirm new password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}
