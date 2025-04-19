import 'package:emcall/pages/auth/otp_verification_page.dart';
import 'package:email_otp/email_otp.dart';
import 'package:emcall/pages/passwords/forgot_password_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfirmationPage extends StatelessWidget {
  final String email;
  final String userType;
  final int userId;
  final EmailOTP emailOTP;

  const ConfirmationPage({
    super.key,
    required this.email,
    required this.userType,
    required this.userId,
    required this.emailOTP,
  });

  Future<void> _openEmailApp(BuildContext context) async {
    // Try launching mailto: URI
    final Uri emailUri = Uri.parse('mailto:');
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        // Navigate to OTPVerificationPage after a delay to allow email app to open
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: email,
                userType: userType,
                userId: userId,
                emailOTP: emailOTP,
              ),
            ),
          );
        });
      } else {
        // Fallback: Try launching a specific email app (e.g., Gmail on Android)
        final Uri gmailUri = Uri.parse('com.google.android.gm');
        if (await canLaunchUrl(gmailUri)) {
          await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationPage(
                  email: email,
                  userType: userType,
                  userId: userId,
                  emailOTP: emailOTP,
                ),
              ),
            );
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('No email app found. Please check your email manually.'),
            ),
          );
          // Navigate to OTPVerificationPage anyway
          _navigateToOTPVerification(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening email app: $e')),
      );
      // Navigate to OTPVerificationPage as a fallback
      _navigateToOTPVerification(context);
    }
  }

  void _navigateToOTPVerification(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerificationPage(
          email: email,
          userType: userType,
          userId: userId,
          emailOTP: emailOTP,
        ),
      ),
    );
  }

  void _navigateToForgotPassword(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(56, 255, 82, 82),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 48,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your mail',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We have sent a password recovery instructions to your email.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openEmailApp(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Open email app',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _navigateToOTPVerification(context),
                child: Text(
                  'Skip, I\'ll confirm later',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  text:
                      'Did not receive the email? Check your spam filter, or ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  children: [
                    TextSpan(
                      text: 'try another email address',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.blue[700],
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _navigateToForgotPassword(context),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
