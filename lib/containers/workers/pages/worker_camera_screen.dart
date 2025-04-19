import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class WorkerCameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final Function(String) onVideoRecorded;

  const WorkerCameraScreen({
    super.key,
    required this.camera,
    required this.onVideoRecorded,
  });

  @override
  State<WorkerCameraScreen> createState() => _WorkerCameraScreenState();
}

class _WorkerCameraScreenState extends State<WorkerCameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late List<CameraDescription> _cameras;
  bool _isFrontCamera = true;
  bool _isRecording = false;
  int _secondsRemaining = 60;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.camera);
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    _cameras = await availableCameras();
  }

  void _initializeCamera(CameraDescription camera) {
    _controller = CameraController(camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _switchCamera() async {
    await _controller.dispose();
    _isFrontCamera = !_isFrontCamera;
    CameraDescription newCamera = _cameras.firstWhere(
      (cam) =>
          cam.lensDirection ==
          (_isFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
      orElse: () => _cameras.first,
    );
    _initializeCamera(newCamera);
    if (mounted) setState(() {});
  }

  void _startRecording() async {
    try {
      await _initializeControllerFuture;
      await _controller.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
      _secondsRemaining = 60;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _secondsRemaining--;
        });
        if (_secondsRemaining <= 0) {
          _stopRecording();
          timer.cancel();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  void _stopRecording() async {
    try {
      final video = await _controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      _recordingTimer?.cancel();
      widget.onVideoRecorded(video.path);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.previewSize?.height ??
                          MediaQuery.of(context).size.width,
                      height: _controller.value.previewSize?.width ??
                          MediaQuery.of(context).size.height,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scale(_isFrontCamera ? -1.0 : 1.0, 1.0),
                        child: CameraPreview(_controller),
                      ),
                    ),
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_isRecording)
            Positioned(
              top: 16,
              right: 16,
              child: Text(
                '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.videocam,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                onPressed: _switchCamera,
                icon:
                    const Icon(Icons.flip_camera_android, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
