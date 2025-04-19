// routing_map_page.dart
import 'package:emcall/containers/workers/full_map.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

// routing_map_page.dart
class RoutingMapPage extends StatelessWidget {
  final mp.Position residentPosition;
  final String residentImageUrl;

  const RoutingMapPage({
    Key? key,
    required this.residentPosition,
    required this.residentImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routing Map')),
      body: FullMap(
        residentPosition: residentPosition,
        residentImageUrl: residentImageUrl,
        showRouteImmediately: true,
      ),
    );
  }
}
