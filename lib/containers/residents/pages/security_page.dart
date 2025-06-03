import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  SecurityPageState createState() => SecurityPageState();
}

class SecurityPageState extends State<SecurityPage> {
  @override
  void initState() {
    super.initState();
    _launchSecurityUrl();
  }

  Future<void> _launchSecurityUrl() async {
    const securityDocUrl =
        'https://docs.google.com/document/d/1R2SqecLo2QwG9BaUJP6d89PoYUQaXaRClqre2WrRxZI/edit?usp=sharing'; // Replace with your actual URL
    final Uri uri = Uri.parse(securityDocUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $securityDocUrl';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Security page: $e')),
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
          'Security',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
