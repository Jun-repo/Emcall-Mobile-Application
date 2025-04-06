// otp_verification_page.dart
import 'package:email_otp/email_otp.dart';
import 'package:emcall/pages/passwords/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String userType;
  final int userId;
  final EmailOTP emailOTP;

  const OTPVerificationPage({
    super.key,
    required this.email,
    required this.userType,
    required this.userId,
    required this.emailOTP,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final FocusNode _firstFieldFocusNode = FocusNode(); // Added focus node
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFieldFocusNode.requestFocus(); // Focus on the first field
    });
  }

  @override
  void dispose() {
    _firstFieldFocusNode.dispose(); // Dispose focus node
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);
    final otp = _controllers.map((c) => c.text).join();

    try {
      // Verify with both systems
      final supabase = Supabase.instance.client;

      // Database verification
      final dbVerification = await supabase
          .from('session_tokens')
          .select()
          .eq('user_type', widget.userType)
          .eq('user_id', widget.userId)
          .eq('token', otp)
          .eq('status', 'active')
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      // EmailOTP verification
      final emailOTPVerified = EmailOTP.verifyOTP(otp: otp);

      if (dbVerification != null && emailOTPVerified == true) {
        await supabase
            .from('session_tokens')
            .update({'status': 'used'}).eq('id', dbVerification['id']);

        Navigator.push(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(
              userType: widget.userType,
              userId: widget.userId,
            ),
          ),
        );
      } else {
        _showError('Invalid or expired OTP');
      }
    } catch (e) {
      _showError('Verification failed: ${e.toString()}');
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
      appBar: AppBar(
        title: const Text('OTP Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            Text(
              'Enter OTP sent to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                  6,
                  (index) => SizedBox(
                        width: 45,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: index == 0
                              ? _firstFieldFocusNode
                              : null, // Assign focus node to the first field
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                              fontSize: 18), // Improve text style
                          decoration: const InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (value.length == 1 && index < 5) {
                              FocusScope.of(context).nextFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              FocusScope.of(context).previousFocus();
                            }
                          },
                        ),
                      )),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify OTP', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
