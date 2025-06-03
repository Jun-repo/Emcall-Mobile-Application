import 'dart:io';
import 'package:emcall/containers/workers/pages/video_upload_page.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class UploadProgressDialog extends StatefulWidget {
  final File videoFile;

  const UploadProgressDialog({
    Key? key,
    required this.videoFile,
  }) : super(key: key);

  @override
  _UploadProgressDialogState createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  double _progress = 0.0;
  bool _isUploading = true;

  @override
  void initState() {
    super.initState();
    _startFakeProgress();
  }

  void _startFakeProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isUploading) return false;

      setState(() {
        // Increase progress until 100%
        if (_progress < 1.0) {
          _progress += 0.02;
        } else {
          _isUploading = false;
        }
      });
      return _isUploading;
    });
  }

  void _navigateToUploadForm() {
    Navigator.of(context).pop(); // Close the dialog first

    // Navigate to VideoUploadFormPage
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoUploadFormPage(
          videoFile: widget.videoFile,
          onUploadComplete: (videoFile, title, description,
              [thumbnailFile]) async {
            print('Video uploaded: $title, $description');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.videoFile.path);

    return AlertDialog(
      title: Text('Loading “$fileName”'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: _progress),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toStringAsFixed(0)}%'),
        ],
      ),
      actions: [
        if (!_isUploading)
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
            onPressed: _navigateToUploadForm,
          ),
      ],
    );
  }
}
