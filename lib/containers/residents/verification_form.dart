// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:io';
import 'package:emcall/containers/residents/pages/face_verification_page.dart';
import 'package:emcall/containers/residents/pages/resident_home_page.dart';
import 'package:emcall/containers/residents/pages/verified_successfully_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationForm extends StatefulWidget {
  final int residentId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String email;

  const VerificationForm({
    super.key,
    required this.residentId,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.email,
  });

  @override
  _VerificationFormState createState() => _VerificationFormState();
}

class _VerificationFormState extends State<VerificationForm> {
  String? selectedValidIdType;
  File? _validIdImage;
  bool _isFaceVerified = false;
  bool _isLoading = false;
  String? _faceImageUrl;
  bool _isButtonPressed = false;

  // Design constants
  static const _primaryColor = Color(0xFF2962FF);
  static const _errorColor = Color(0xFFD32F2F);
  static const _successColor = Color(0xFF388E3C);
  static const _inputBorderRadius = 12.0;
  static const _buttonBorderRadius = 15.0;
  static const _animationDuration = Duration(milliseconds: 200);

  final List<String> validIdTypes = [
    'Passport',
    'Driver\'s License',
    'National ID',
    'Postal ID',
    'Voter\'s ID',
  ];

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _primaryColor),
      floatingLabelStyle: const TextStyle(color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _scanValidId() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _validIdImage = File(pickedFile.path));
    }
  }

  Future<void> _openFaceVerification() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleFaceVerificationPage(
          residentId: widget.residentId,
          fullName: '${widget.firstName}_${widget.lastName}',
        ),
      ),
    );

    if (result != null && result is List<String>) {
      setState(() {
        _isFaceVerified = true;
        _faceImageUrl = result.join(',');
      });
      _showSuccessDialog('Face verification successful!');
    }
  }

  Future<void> _handleSave() async {
    if (selectedValidIdType == null ||
        _validIdImage == null ||
        !_isFaceVerified) {
      _showErrorDialog('Please complete all verification steps');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Upload Valid ID
      final fullName =
          '${widget.firstName}_${widget.lastName}'.replaceAll(' ', '_');
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
      final validIdPath =
          'id/${widget.residentId}/validid_${fullName}_$timestamp.jpg';

      await supabase.storage
          .from('valididimages')
          .upload(validIdPath, _validIdImage!);

      final validIdUrl =
          supabase.storage.from('valididimages').getPublicUrl(validIdPath);

      // Update resident record with valid ID and face recognition image URL.
      await supabase.from('residents').update({
        'valid_id': '$selectedValidIdType - $validIdUrl',
        'face_recognition_image_url': _faceImageUrl,
      }).eq('id', widget.residentId);

      // Navigate to Verified Successfully Page.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifiedSuccessfullyPage(
            fullName: '${widget.firstName} ${widget.lastName}',
            recipientEmail: widget.email, // <-- Pass the email here.
          ),
        ),
      );

      // After closing the verified page, navigate to the Resident Home Page.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResidentHomePage(
            firstName: widget.firstName,
            middleName: widget.middleName,
            lastName: widget.lastName,
            suffix: widget.suffix,
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Verification Error', 'Failed to save: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, [String? message]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message ?? 'Please check your inputs'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        content,
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildIDUploadSection() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedValidIdType,
          decoration: _inputDecoration('Select Valid ID Type'),
          items: validIdTypes
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) => setState(() => selectedValidIdType = value),
          borderRadius: BorderRadius.circular(_inputBorderRadius),
          icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _scanValidId,
          child: AnimatedContainer(
            duration: _animationDuration,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(_inputBorderRadius),
              border: Border.all(
                color: _validIdImage == null ? _errorColor : _primaryColor,
                width: 2,
              ),
            ),
            child: _validIdImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(_inputBorderRadius),
                    child: Image.file(_validIdImage!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt,
                          size: 40, color: _primaryColor),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to scan ${selectedValidIdType ?? 'ID'}',
                        style: const TextStyle(color: _primaryColor),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceVerificationSection() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _openFaceVerification,
          icon: const Icon(Icons.face_retouching_natural),
          label: const Text('Start Face Verification'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_buttonBorderRadius),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Icon(
              _isFaceVerified ? Icons.check_circle : Icons.error,
              color: _isFaceVerified ? _successColor : _errorColor,
            ),
            const SizedBox(width: 10),
            Text(
              _isFaceVerified ? 'Verified Successfully' : 'Not Verified',
              style: TextStyle(
                color: _isFaceVerified ? _successColor : _errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isButtonPressed = true),
      onTapUp: (_) => setState(() => _isButtonPressed = false),
      onTapCancel: () => setState(() => _isButtonPressed = false),
      child: AnimatedContainer(
        duration: _animationDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
          boxShadow: _isButtonPressed
              ? []
              : [
                  BoxShadow(
                      color: _primaryColor.withOpacity(0.3), blurRadius: 8)
                ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_buttonBorderRadius),
            ),
            elevation: _isButtonPressed ? 0 : 4,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Complete Verification',
                  style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Verification'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerificationStep(
                '1. ID Verification', _buildIDUploadSection()),
            _buildVerificationStep(
                '2. Face Verification', _buildFaceVerificationSection()),
            const SizedBox(height: 40),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}
