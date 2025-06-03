// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenerateTokenPage extends StatefulWidget {
  const GenerateTokenPage({super.key});

  @override
  _GenerateTokenPageState createState() => _GenerateTokenPageState();
}

class _GenerateTokenPageState extends State<GenerateTokenPage> {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating key: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyKeyToClipboard() {
    if (_generatedKey != null) {
      Clipboard.setData(ClipboardData(text: _generatedKey!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Product key copied to clipboard'),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Generate a Token for a New Worker',
              style: TextStyle(
                fontSize: 30,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleGenerateKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Generate Token',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                        ),
                      ),
              ),
            ),
            if (_generatedKey != null) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.redAccent, width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Product Key: $_generatedKey',
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: 'Gilroy',
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.redAccent),
                      onPressed: _copyKeyToClipboard,
                      tooltip: 'Copy Key',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
