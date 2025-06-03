import 'package:emcall/components/maps/emcall_map.dart';
import 'package:flutter/material.dart';

class ResidentMap extends StatelessWidget {
  const ResidentMap({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          EmcallMap(),
        ],
      ),
    );
  }
}
