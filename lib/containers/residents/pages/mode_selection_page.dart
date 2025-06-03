import 'package:flutter/material.dart';

class ModeSelectionPage extends StatelessWidget {
  final String currentMode;

  const ModeSelectionPage({super.key, required this.currentMode});

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
          'Select Mode',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Off',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            trailing: currentMode == 'Off'
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, 'Off'),
          ),
          ListTile(
            title: const Text('Night',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            trailing: currentMode == 'Night'
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, 'Night'),
          ),
          ListTile(
            title: const Text('Day',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            trailing: currentMode == 'Day'
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, 'Day'),
          ),
          ListTile(
            title: const Text('Same as Phone Settings',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            trailing: currentMode == 'Same as Phone Settings'
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, 'Same as Phone Settings'),
          ),
        ],
      ),
    );
  }
}
