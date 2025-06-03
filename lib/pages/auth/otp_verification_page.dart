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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      "assets/images/otp.png",
                      height: 350,
                    ),
                  ),
                  const SizedBox(height: 30),
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
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                ),
                                controller: _controllers[index],
                                focusNode: index == 0
                                    ? _firstFieldFocusNode
                                    : null, // Assign focus node to the first field
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,

                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(4.0),
                                    ),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(4.0),
                                    ),
                                    borderSide: const BorderSide(
                                      color: Color.fromARGB(255, 202, 202, 202),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(4.0),
                                    ),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    ),
                                  ),
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
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Verify',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              )),
                    ),
                  ),
                  SizedBox(height: 60),
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
}
