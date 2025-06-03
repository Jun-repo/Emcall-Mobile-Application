// video_upload_form_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoUploadFormPage extends StatefulWidget {
  final File videoFile;
  final Future<void> Function(File videoFile, String title, String description,
      [File? thumbnailFile]) onUploadComplete;

  const VideoUploadFormPage({
    super.key,
    required this.videoFile,
    required this.onUploadComplete,
  });

  @override
  State<VideoUploadFormPage> createState() => _VideoUploadFormPageState();
}

class _VideoUploadFormPageState extends State<VideoUploadFormPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  File? _thumbnailFile;
  bool isUploading = false;

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _thumbnailFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _upload() async {
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and Description are required')));
      return;
    }
    setState(() {
      isUploading = true;
    });
    await widget.onUploadComplete(
      widget.videoFile,
      title,
      description,
      _thumbnailFile,
    );
    setState(() {
      isUploading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video preview placeholder
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Text(
                  'Video Preview (under maintenance)',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              // Thumbnail selection
              const Text(
                'Thumbnail (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _thumbnailFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _thumbnailFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo),
                label: const Text('Pick Thumbnail'),
                onPressed: _pickThumbnail,
              ),
              const SizedBox(height: 16),
              // Title input
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Description input
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Upload button
              isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload'),
                      onPressed: _upload,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
