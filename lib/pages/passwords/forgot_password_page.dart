// forgot_password_page.dart
import 'package:email_otp/email_otp.dart';
import 'package:emcall/pages/auth/confirmation_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);
  final EmailOTP _emailOTP = EmailOTP();
  bool _isLoading = false;

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim();

    try {
      String? userType;
      int? userId;
      String? userEmail;

      // Check residents
      final resident = await supabase
          .from('residents')
          .select()
          .eq('personal_email', email)
          .maybeSingle();

      if (resident != null) {
        userType = 'resident';
        userId = resident['id'];
        userEmail = resident['personal_email'];
      } else {
        // Check workers
        final worker = await supabase
            .from('workers')
            .select()
            .eq('personal_email', email)
            .maybeSingle();
        if (worker != null) {
          userType = 'worker';
          userId = worker['id'];
          userEmail = worker['personal_email'];
        } else {
          // Check organizations
          const orgTables = [
            'police',
            'rescue',
            'firefighter',
            'disaster_responders'
          ];
          for (final table in orgTables) {
            final org = await supabase
                .from(table)
                .select()
                .eq('gmail_org_account', email)
                .maybeSingle();
            if (org != null) {
              userType =
                  table == 'disaster_responders' ? 'disaster_responder' : table;
              userId = org['id'];
              userEmail = org['gmail_org_account'];
              break;
            }
          }
        }
      }

      if (userId == null || userType == null || userEmail == null) {
        _showError('No account found with this email');
        return;
      }

      // Configure EmailOTP
      EmailOTP.config(
        appName: "Emcall Support",
        appEmail: "support@emcall.com",
        otpLength: 6,
        otpType: OTPType.numeric,
        emailTheme: EmailTheme.v2,
      );

      // Uncomment and configure SMTP settings in production

      EmailOTP.setSMTP(
        host: 'smtp.gmail.com',
        emailPort: EmailPort.port465,
        secureType: SecureType.ssl,
        username: 'emcallcompany@gmail.com',
        password: 'hqrlyllujvhiiqqv',
      );
      EmailOTP.setTemplate(
        template: '''
    <div style="font-family: Arial, sans-serif; text-align: center;">
      <h1>{{appName}}</h1>
      <p>Your One-Time Password (OTP) is: <strong>{{otp}}</strong></p>
      <p>Please use this code to complete your password reset. It is valid for 5 minutes.</p>
    </div>
  ''',
      );

      //     // Set custom email template
      //     EmailOTP.setTemplate(
      //       template: '''
      // <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #f8f9fa; padding: 40px 0;">
      //   <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.05);">
      //     <!-- Header -->
      //     <div style="padding: 24px; background: linear-gradient(135deg, #22b8cf, #1098ad); border-radius: 8px 8px 0 0;">

      //       <h1 style="color: #ffffff; margin: 16px 0 0 0; font-size: 24px; font-weight: 600;">Password Reset Request</h1>
      //     </div>

      //     <!-- Content -->
      //     <div style="padding: 32px 24px;">
      //       <p style="color: #495057; margin: 0 0 16px 0; line-height: 1.5;">
      //         We received a request to reset your Emcall account password. Use the following verification code:
      //       </p>

      //       <div style="background-color: #f1f3f5; padding: 16px; border-radius: 6px; text-align: center; margin: 24px 0;">
      //         <div style="font-size: 28px; color: #1098ad; font-weight: 600; letter-spacing: 2px;">{{otp}}</div>
      //         <div style="color: #868e96; font-size: 12px; margin-top: 8px;">Valid for 5 minutes</div>
      //       </div>

      //       <p style="color: #495057; margin: 24px 0 0 0; line-height: 1.5;">
      //         If you didn't request this code, you can safely ignore this email. For security reasons, please do not share this code with anyone.
      //       </p>
      //     </div>

      //     <!-- Footer -->
      //     <div style="padding: 24px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; border-top: 1px solid #e9ecef;">
      //       <div style="color: #868e96; font-size: 12px; line-height: 1.5;">
      //         <p style="margin: 0;">Emcall Security Team</p>
      //         <p style="margin: 8px 0 0 0;">
      //           <a href="https://yourdomain.com" style="color: #1098ad; text-decoration: none;">Visit our website</a> |
      //           <a href="mailto:support@emcall.com" style="color: #1098ad; text-decoration: none;">Contact Support</a>
      //         </p>
      //         <p style="margin: 16px 0 0 0; color: #adb5bd;">
      //           © ${DateTime.now().year} Emcall. All rights reserved.<br>
      //           This is an automated message - please do not reply directly to this email.
      //         </p>
      //       </div>
      //     </div>
      //   </div>
      // </div>
      // ''',
      //     );

      // Send OTP
      if (await EmailOTP.sendOTP(email: userEmail) == true) {
        // Store OTP in session_tokens
        await supabase.from('session_tokens').insert({
          'user_type': userType,
          'user_id': userId,
          'action_type': 'password_reset',
          'token': EmailOTP.getOTP(),
          'expires_at':
              DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'status': 'active'
        });

        // Navigate to ConfirmationPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationPage(
              email: userEmail!,
              userType: userType!,
              userId: userId!,
              emailOTP: _emailOTP,
            ),
          ),
        );
      } else {
        _showError('Failed to send OTP');
      }
    } catch (e, stackTrace) {
      _showNoNetworkSnackBar();
      debugPrint(stackTrace.toString());
      _showNoNetworkSnackBar();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      "assets/images/mail_delivery.png",
                      height: 350,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.mail),
                      suffixIcon: IconButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        icon: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.redAccent,
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.grey),
                      ),
                      labelText: 'Email Address',
                      hintText: 'Enter your Email',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: Colors.black54,
                        fontSize: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8.0),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.0,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8.0),
                        ),
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 202, 202, 202),
                          width: 0.7,
                        ),
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
                    ),
                    cursorColor: Colors.redAccent,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
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
    _emailController.dispose();
    super.dispose();
  }
}
