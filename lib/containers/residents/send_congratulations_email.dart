import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Sends a congratulatory email to the [recipientEmail].
Future<void> sendCongratulationsEmail(
    String recipientEmail, String recipientName) async {
  const String username = 'emcallcompany@gmail.com';
  const String password = 'ulqpxshshecjrria';

  final smtpServer = gmail(username, password);

  final message = Message()
    ..from = const Address(username, 'Emcall Support')
    ..recipients.add(recipientEmail)
    ..subject = 'Welcome to Emcall, $recipientName!'
    ..text = '''Dear $recipientName,

Congratulations! Your account has been successfully created.
Welcome to Emcall—We're excited to have you with us!

If you have any questions, feel free to reply to this email.

Best regards,
The Emcall Team

To unsubscribe, click here: [Unsubscribe](#)''' // Replace with a real link if needed
    ..html = '''<h1>Congratulations, $recipientName!</h1>
<p>Your account has been successfully created.</p>
<p>Welcome to Emcall—We're excited to have you with us!</p>
<p>If you have any questions, feel free to <a href="mailto:$username">reply to this email</a>.</p>
<p>Best regards,<br>The Emcall Team</p>
<p><small><a href="#">Unsubscribe</a></small></p>''';

  try {
    final sendReport = await send(message, smtpServer);
    if (kDebugMode) {
      print('Message sent: $sendReport');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Message not sent. Error: $e');
    }
  }
}
