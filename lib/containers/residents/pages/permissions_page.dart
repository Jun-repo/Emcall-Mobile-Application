import 'package:flutter/material.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  PermissionsPageState createState() => PermissionsPageState();
}

class PermissionsPageState extends State<PermissionsPage> {
  bool _locationEnabled = true;
  bool _cameraEnabled = true;
  bool _phoneEnabled = true;
  bool _microphoneEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Permissions',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            activeColor: Colors.redAccent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            title: const Text(
              'Location',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            subtitle: const Text(
              'Allow access to your location for maps and emergency services',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: Colors.white),
            ),
            value: _locationEnabled,
            onChanged: (bool value) {
              setState(() {
                _locationEnabled = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Location permission ${value ? 'enabled' : 'disabled'}'),
                ),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            activeColor: Colors.redAccent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            title: const Text(
              'Camera',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            subtitle: const Text(
              'Allow access to your camera for photos and video calls',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
            value: _cameraEnabled,
            onChanged: (bool value) {
              setState(() {
                _cameraEnabled = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Camera permission ${value ? 'enabled' : 'disabled'}'),
                ),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            activeColor: Colors.redAccent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            title: const Text(
              'Phone',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            subtitle: const Text(
              'Allow access to phone for making calls',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.white),
            ),
            value: _phoneEnabled,
            onChanged: (bool value) {
              setState(() {
                _phoneEnabled = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Phone permission ${value ? 'enabled' : 'disabled'}'),
                ),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            activeColor: Colors.redAccent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            title: const Text(
              'Microphone',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            subtitle: const Text(
              'Allow access to microphone for voice calls and recordings',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white),
            ),
            value: _microphoneEnabled,
            onChanged: (bool value) {
              setState(() {
                _microphoneEnabled = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Microphone permission ${value ? 'enabled' : 'disabled'}'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
