import 'package:flutter/material.dart';

class TypeSelectionPage extends StatelessWidget {
  final String currentType;

  const TypeSelectionPage({super.key, required this.currentType});

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
          'Select Type',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Default',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            trailing: currentType == 'Default'
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, 'Default'),
          ),
          ListTile(
            title: const Text('Map Editors',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            trailing: currentType == 'Map Editors'
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, 'Map Editors'),
          ),
        ],
      ),
    );
  }
}
