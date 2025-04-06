// create_worker_account_form.dart
// ignore_for_file: use_build_context_synchronously

import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/containers/workers/pages/worker_home_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateWorkerAccountForm extends StatefulWidget {
  final String orgType;

  const CreateWorkerAccountForm({super.key, required this.orgType});

  @override
  CreateWorkerAccountFormState createState() => CreateWorkerAccountFormState();
}

class CreateWorkerAccountFormState extends State<CreateWorkerAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController productKeyController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    try {
      // Verify product key
      final productKeyResponse = await supabase
          .from('product_keys')
          .select()
          .eq('key', productKeyController.text.trim())
          .eq('organization_type', widget.orgType)
          .eq('is_used', false)
          .maybeSingle();

      if (productKeyResponse == null) {
        throw 'Invalid or used product key';
      }

      final organizationId = productKeyResponse['organization_id'];

      // Insert worker
      final workerData = {
        'organization_type': widget.orgType,
        'organization_id': organizationId,
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'username': usernameController.text.trim(),
        'password_hash':
            BCrypt.hashpw(passwordController.text.trim(), BCrypt.gensalt()),
      };

      final workerResponse = await supabase
          .from('workers')
          .insert(workerData)
          .select()
          .single(); // Retrieve the inserted worker data

      // Mark product key as used
      await supabase.from('product_keys').update({
        'is_used': true,
        'used_at': DateTime.now().toIso8601String(),
      }).eq('key', productKeyController.text.trim());

      // Store worker details in SharedPreferences
      await prefs.setBool("loggedIn", true);
      await prefs.setString("userType", "worker");
      await prefs.setString("username", usernameController.text.trim());
      await prefs.setString("worker_id", workerResponse['id'].toString());
      await prefs.setString("firstName", firstNameController.text.trim());
      await prefs.setString("lastName", lastNameController.text.trim());
      await prefs.setString(
          "middleName", ''); // Default to empty if not collected
      await prefs.setString("suffix", ''); // Default to empty if not collected

      // Navigate to WorkerHomePage with worker details
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const WorkerHomePage(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Create ${widget.orgType[0].toUpperCase()}${widget.orgType.substring(1)} Worker Account'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: productKeyController,
                decoration: const InputDecoration(labelText: 'Product Key *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password *'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    productKeyController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
