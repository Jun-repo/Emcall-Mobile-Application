import 'dart:io';
import 'package:emcall/containers/workers/pages/video_upload_page.dart';
import 'package:emcall/containers/workers/pages/worker_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

class VideoReelsPage extends StatefulWidget {
  final int? workerId;

  const VideoReelsPage({super.key, required this.workerId});

  @override
  State<VideoReelsPage> createState() => _VideoReelsPageState();
}

class _VideoReelsPageState extends State<VideoReelsPage> {
  Future<void> _handleVideoRecording(String videoPath) async {
    try {
      // Compress the video to approximately 480p
      MediaInfo? compressedInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );

      if (compressedInfo == null || compressedInfo.path == null) {
        throw Exception('Video compression failed.');
      }

      final directory = await getTemporaryDirectory();
      final uuid = const Uuid().v4();
      final localVideoPath = '${directory.path}/$uuid.mp4';
      final localFile = File(localVideoPath);
      await File(compressedInfo.path!).copy(localVideoPath);

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
      // Upload the video to Supabase storage
      await Supabase.instance.client.storage.from('reelsvideos').upload(
            videoFileName,
            videoFile,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );

      // Get the public URL for the video
      final videoUrl = Supabase.instance.client.storage
          .from('reelsvideos')
          .getPublicUrl(videoFileName);

      // Upload thumbnail if provided
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

      // Insert metadata into the reels_videos table
      await Supabase.instance.client.from('reels_videos').insert({
        'worker_id': widget.workerId,
        'title': title,
        'description': description,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
      });

      if (mounted) {
        await _showSuccessDialog();
        Navigator.pop(context); // Return to WorkerHomePage
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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Record Video'),
              onPressed: _openCameraForReels,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick from Gallery'),
              onPressed: _openGalleryForReels,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
