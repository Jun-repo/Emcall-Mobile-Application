import 'dart:io';
import 'package:emcall/containers/workers/pages/upload_progress_dialog.dart';
import 'package:emcall/containers/workers/pages/video_upload_page.dart';
import 'package:emcall/containers/workers/pages/worker_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class VideoReelsPage extends StatefulWidget {
  final int? workerId;

  const VideoReelsPage({super.key, required this.workerId});

  @override
  State<VideoReelsPage> createState() => _VideoReelsPageState();
}

class _VideoReelsPageState extends State<VideoReelsPage> {
  Future<void> _handleVideoRecording(String compressedPath) async {
    try {
      final directory = await getTemporaryDirectory();
      final uuid = const Uuid().v4();
      final localVideoPath = '${directory.path}/$uuid.mp4';
      final localFile = File(localVideoPath);
      await File(compressedPath).copy(localVideoPath);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoUploadFormPage(
              videoFile: localFile,
              onUploadComplete: _uploadReelVideoWithMetadata,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing video: $e')),
        );
      }
    }
  }

  Future<void> _openCameraForReels() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        CameraDescription frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerCameraScreen(
                camera: frontCamera,
                onVideoRecorded: _handleVideoRecording,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing camera: $e')),
        );
      }
    }
  }

  Future<void> _openGalleryForReels() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        File videoFile = File(pickedFile.path);

        if (mounted) {
          // Step 1: Show the progress dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => UploadProgressDialog(videoFile: videoFile),
          );

          // Step 2: Navigate to the form page after dialog is done
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoUploadFormPage(
                videoFile: videoFile,
                onUploadComplete: _uploadReelVideoWithMetadata,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No video selected from gallery')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing gallery: $e')),
        );
      }
    }
  }

  Future<void> _uploadReelVideoWithMetadata(
      File videoFile, String title, String description,
      [File? thumbnailFile]) async {
    if (widget.workerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker ID not found')),
        );
      }
      return;
    }

    final uuid = const Uuid().v4();
    final videoFileName = 'reelsvideos/$uuid.mp4';
    String? thumbnailUrl;

    try {
      await Supabase.instance.client.storage.from('reelsvideos').upload(
            videoFileName,
            videoFile,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );

      final videoUrl = Supabase.instance.client.storage
          .from('reelsvideos')
          .getPublicUrl(videoFileName);

      if (thumbnailFile != null) {
        final thumbnailFileName = 'reelsvideos/thumbnails/$uuid.jpg';
        await Supabase.instance.client.storage.from('reelsvideos').upload(
              thumbnailFileName,
              thumbnailFile,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        thumbnailUrl = Supabase.instance.client.storage
            .from('reelsvideos')
            .getPublicUrl(thumbnailFileName);
      }

      await Supabase.instance.client.from('reels_videos').insert({
        'worker_id': widget.workerId,
        'title': title,
        'description': description,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
      });

      if (mounted) {
        await _showSuccessDialog();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        await _showFailureDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading reel: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Reel uploaded successfully!'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFailureDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload Failed'),
          content: const Text('Failed to upload reel.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Reel'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/video_reels.jpg',
                  width: MediaQuery.of(context).size.width * 0.8,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.videocam_rounded, size: 24),
                    label: const Text(
                      'Record Video',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _openCameraForReels,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.video_collection_rounded, size: 24),
                    label: const Text(
                      'Pick from Gallery',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _openGalleryForReels,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 2,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
