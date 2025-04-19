import 'package:flutter/material.dart';
import 'package:emcall/components/maps/flutter_map.dart'; // Ensure FullMap is imported from here

class ResidentMap extends StatelessWidget {
  const ResidentMap({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          FullMap(),
        ],
      ),
    );
  }
}
