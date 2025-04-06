// organization_home_page.dart (updated)
// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrganizationHomePage extends StatefulWidget {
  final String orgName;
  final String orgAddress;

  const OrganizationHomePage({
    super.key,
    required this.orgName,
    required this.orgAddress,
  });

  @override
  OrganizationHomePageState createState() => OrganizationHomePageState();
}

class OrganizationHomePageState extends State<OrganizationHomePage> {
  String? _generatedKey;
  bool _isLoading = false;

  String _generateProductKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _handleGenerateKey() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final orgType = prefs.getString('orgType') ?? '';
    final orgId = prefs.getInt('orgId');

    if (kDebugMode) {
      print('Retrieved orgId: $orgId');
    } // Debug print

    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization ID not found')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      String key;
      bool isUnique;
      do {
        key = _generateProductKey();
        final response = await supabase
            .from('product_keys')
            .select()
            .eq('key', key)
            .maybeSingle();
        isUnique = response == null;
      } while (!isUnique);

      await supabase.from('product_keys').insert({
        'organization_type': orgType,
        'organization_id': orgId,
        'key': key,
        'is_used': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() => _generatedKey = key);
      _showKeyDialog(key);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating key: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showKeyDialog(String key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generated Product Key'),
        content:
            Text('Your product key is: $key\nShare this with your worker.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orgName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${widget.orgAddress}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleGenerateKey,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate Product Key'),
            ),
            if (_generatedKey != null) ...[
              const SizedBox(height: 20),
              Text('Last Generated Key: $_generatedKey'),
            ],
          ],
        ),
      ),
    );
  }
}
