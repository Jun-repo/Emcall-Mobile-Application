import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  PrivacyPageState createState() => PrivacyPageState();
}

class PrivacyPageState extends State<PrivacyPage> {
  @override
  void initState() {
    super.initState();
    _launchPrivacyUrl();
  }

  Future<void> _launchPrivacyUrl() async {
    const privacyDocUrl =
        'https://docs.google.com/document/d/1V4kaWJKcr5B0wZrN-iMKWLlfa5AXSbOSrdsHXHn7Pdo/edit?usp=sharing';
    final Uri uri = Uri.parse(privacyDocUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $privacyDocUrl';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Privacy page: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context); // Close the page after launching the URL
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
