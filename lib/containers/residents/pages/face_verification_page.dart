// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui'; // For ImageFilter

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SimpleFaceVerificationPage extends StatefulWidget {
  final int residentId;
  final String fullName;

  const SimpleFaceVerificationPage({
    super.key,
    required this.residentId,
    required this.fullName,
  });

  @override
  _SimpleFaceVerificationPageState createState() =>
      _SimpleFaceVerificationPageState();
}

class _SimpleFaceVerificationPageState
    extends State<SimpleFaceVerificationPage> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  File? _capturedImage;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _analyzingText = 'Analyzing';
  Timer? _captureTimer;
  Timer? _progressTimer;
  Timer? _analyzingTimer;
  bool _showPreview = false;

  // Design constants
  static const _primaryColor = Color.fromARGB(255, 255, 58, 52);
  static const _previewSize = 100.0;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
    _startAutomaticCapture();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.ultraHigh,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController.initialize();
      await _initializeControllerFuture;
    } catch (e) {
      _showErrorAndExit('Camera!', 'Failed to initialize camera');
    }
  }

  void _startAutomaticCapture() {
    _captureTimer = Timer(const Duration(seconds: 10), _captureAndProcess);
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _showPreview = false;
    });

    try {
      final image = await _cameraController.takePicture();
      _capturedImage = File(image.path);
      _startProgressAnimation();
      _startAnalyzingAnimation();

      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 10));

      // Upload to Supabase
      final imageUrl = await _uploadFaceImage();

      setState(() => _showPreview = true);
      await Future.delayed(const Duration(seconds: 10));

      Navigator.pop(context, [imageUrl]);
    } catch (e) {
      _showErrorAndExit('Upload!', 'Failed to upload image');
    } finally {
      _stopAnimations();
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _uploadFaceImage() async {
    final supabase = Supabase.instance.client;
    final formattedDate =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    final fileName = 'face_${widget.fullName}_$formattedDate.jpg';
    final filePath = 'id/${widget.residentId}/$fileName';

    await supabase.storage
        .from('faceverificationimages')
        .upload(filePath, _capturedImage!);

    return supabase.storage
        .from('faceverificationimages')
        .getPublicUrl(filePath);
  }

  void _startProgressAnimation() {
    _progressTimer?.cancel();
    final random = Random();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_progress < 1.0) {
        setState(() {
          _progress += random.nextDouble() * 0.15;
          if (_progress > 1.0) _progress = 1.0;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startAnalyzingAnimation() {
    _analyzingTimer?.cancel();
    int dots = 0;
    _analyzingTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      setState(() {
        dots = (dots + 1) % 4;
        _analyzingText = 'Analyzing${'.' * dots}';
      });
    });
  }

  void _stopAnimations() {
    _progressTimer?.cancel();
    _analyzingTimer?.cancel();
    setState(() {
      _progress = 0.0;
      _analyzingText = 'Analyzing';
    });
  }

  void _showErrorAndExit(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => Navigator.pop(context));
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _progressTimer?.cancel();
    _analyzingTimer?.cancel();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text(
          'Face Verification',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                _buildCameraPreview(),
                _buildFaceGuideOverlay(),
                _buildProcessingOverlay(),
                if (_showPreview && _capturedImage != null)
                  _buildPreviewOverlay(),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildCameraPreview() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: _cameraController.value.previewSize?.width,
          height: _cameraController.value.previewSize?.height,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: CameraPreview(_cameraController),
          ),
        ),
      ),
    );
  }

  /// Face guide overlay: shows a circular outline and instructions in the center.
  /// Everything outside the circle is blurred.
  Widget _buildFaceGuideOverlay() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Blurred overlay for areas outside the circle.
        Positioned.fill(
          child: ClipPath(
            clipper: InvertedCircleClipper(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),
        ),
        // Center the circle and text.
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The circle guide.
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isProcessing
                        ? _primaryColor.withOpacity(0.3)
                        : _primaryColor,
                    width: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 100,
          child: Center(
            child: Text(
              _isProcessing
                  ? _analyzingText
                  : 'Position your face in the circle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Visibility(
      visible: _isProcessing,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 4,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_primaryColor),
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _analyzingText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewOverlay() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          _capturedImage!,
          width: _previewSize,
          height: _previewSize,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Custom clipper that creates an inverted circle path.
/// The returned path clips out a circle in the center (radius 125).
class InvertedCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final circleRect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: 125);
    final fullPath = Path()..addRect(fullRect);
    final circlePath = Path()..addOval(circleRect);
    return Path.combine(PathOperation.difference, fullPath, circlePath);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
