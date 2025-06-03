// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:io';
import 'package:emcall/containers/residents/pages/face_verification_page.dart';
import 'package:emcall/containers/residents/pages/home_navigation_page.dart';
import 'package:emcall/containers/residents/pages/verified_successfully_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image/image.dart' as img;

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
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

  final List<String> validIdTypes = [
    'Passport',
    'Driver\'s License',
    'National ID',
    'Postal ID',
    'Voter\'s ID',
    'Barangay\'s ID',
    'Student\'s ID',
  ];

  OutlineInputBorder get customInputBorder {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(
        color: Color.fromARGB(255, 198, 198, 198),
        width: 0.7,
      ),
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

  Future<File?> _flipImage(File imageFile) async {
    try {
      // Read the image file

      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Flip the image horizontally
      image = img.flipHorizontal(image);

      // Save the flipped image to a temporary file
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/flipped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final flippedFile = File(tempPath);
      await flippedFile.writeAsBytes(img.encodeJpg(image));

      return flippedFile;
    } catch (e) {
      _showErrorDialog('Image Processing Error', 'Failed to process image');
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // Check network connectivity
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showNoNetworkSnackBar();
      return;
    } else if (result == ConnectivityResult.mobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’re on mobile data. Charges may apply.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        // Flip the image if it was taken with the camera (to correct mirroring)
        if (source == ImageSource.camera) {
          final flippedImage = await _flipImage(imageFile);
          if (flippedImage != null) {
            imageFile = flippedImage;
          } else {
            return; // Abort if flipping failed
          }
        }
        setState(() => _validIdImage = imageFile);
      }
    } catch (e) {
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showErrorDialog('Image Error', 'Failed to select image: ');
      }
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy',
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.redAccent),
              title: const Text(
                'Open Camera',
                style: TextStyle(fontFamily: 'Gilroy'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.redAccent),
              title: const Text(
                'Browse Gallery',
                style: TextStyle(fontFamily: 'Gilroy'),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style:
                      TextStyle(color: Colors.redAccent, fontFamily: 'Gilroy'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final supabase = Supabase.instance.client;

    // Check network connectivity
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showNoNetworkSnackBar();
      setState(() => _isLoading = false);
      return;
    } else if (result == ConnectivityResult.mobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’re on mobile data. Charges may apply.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    try {
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

      // Update resident record
      await supabase.from('residents').update({
        'valid_id': '$selectedValidIdType - $validIdUrl',
        'face_recognition_image_url': _faceImageUrl,
      }).eq('id', widget.residentId);

      // Navigate to Verified Successfully Page
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifiedSuccessfullyPage(
            fullName: '${widget.firstName} ${widget.lastName}',
            recipientEmail: widget.email,
          ),
        ),
      );

      // Navigate to Home Navigation Page
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeNavigationPage(
            initialIndex: 1,
          ),
        ),
      );
    } catch (e) {
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showErrorDialog('Verification Error', 'Failed to save');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, [String? message]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Gilroy')),
        content: Text(message ?? 'Please check your inputs',
            style: const TextStyle(fontFamily: 'Gilroy')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style:
                    TextStyle(color: Colors.redAccent, fontFamily: 'Gilroy')),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success', style: TextStyle(fontFamily: 'Gilroy')),
        content: Text(message, style: const TextStyle(fontFamily: 'Gilroy')),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue',
                style:
                    TextStyle(color: Colors.redAccent, fontFamily: 'Gilroy')),
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
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gilroy',
            ),
          ),
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
          decoration: InputDecoration(
            labelText: 'Select Valid ID Type *',
            hintText: 'Choose ID type',
            filled: true,
            fillColor: Colors.grey[100],
            labelStyle: const TextStyle(color: Colors.black54, fontSize: 20),
            prefixIcon: const Icon(Icons.perm_identity_rounded),
            border: customInputBorder,
            enabledBorder: customInputBorder,
            focusedBorder: customInputBorder.copyWith(
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
            ),
          ),
          items: validIdTypes
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) => setState(() => selectedValidIdType = value),
          validator: (value) => value == null ? 'Required' : null,
          borderRadius: BorderRadius.circular(8.0),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.redAccent),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _showImageSourceBottomSheet,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: Colors.redAccent,
                width: 2,
              ),
            ),
            child: _validIdImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.file(_validIdImage!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt,
                          size: 40, color: Colors.redAccent),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to select ${selectedValidIdType ?? 'ID'}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontFamily: 'Gilroy',
                        ),
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openFaceVerification,
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text('Start Face Verification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Icon(
              _isFaceVerified ? Icons.check_circle : Icons.error,
              color: _isFaceVerified ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(width: 10),
            Text(
              _isFaceVerified ? 'Verified Successfully' : 'Not Verified',
              style: TextStyle(
                color: _isFaceVerified ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : const Text(
                'Complete Verification',
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Account Verification',
          style: TextStyle(fontFamily: 'Gilroy'),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
