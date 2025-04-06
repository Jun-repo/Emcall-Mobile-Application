// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class ResidentEmergencyMapPage extends StatefulWidget {
  final gl.Position? initialPosition;
  final String? serviceType; // New parameter for the called service type

  const ResidentEmergencyMapPage({
    super.key,
    this.initialPosition,
    this.serviceType,
  });

  @override
  State<ResidentEmergencyMapPage> createState() =>
      _ResidentEmergencyMapPageState();
}

class _ResidentEmergencyMapPageState extends State<ResidentEmergencyMapPage> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription<gl.Position>? _positionStreamSubscription;
  mp.Position? userPosition;
  bool _isCameraCentered = false;
  mp.PointAnnotationManager? _pointAnnotationManager;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      userPosition = mp.Position(
        widget.initialPosition!.longitude,
        widget.initialPosition!.latitude,
      );
    }
    _startLocationTracking();
    _fetchWorkers(); // Fetch workers when the page loads
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    mapboxMap = controller;
    _pointAnnotationManager =
        await controller.annotations.createPointAnnotationManager();
    await _initializeMap(controller);
  }

  Future<void> _initializeMap(mp.MapboxMap controller) async {
    await controller.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: Colors.red.value,
        puckBearingEnabled: true,
        puckBearing: mp.PuckBearing.COURSE,
      ),
    );

    if (userPosition != null && !_isCameraCentered) {
      _centerCameraOnUser();
      _isCameraCentered = true;
    }
  }

  void _startLocationTracking() {
    const locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: null,
    );

    _positionStreamSubscription = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position position) async {
      setState(() {
        userPosition = mp.Position(position.longitude, position.latitude);
      });

      if (!_isCameraCentered && userPosition != null) {
        _centerCameraOnUser();
        _isCameraCentered = true;
      }
    });
  }

  void _centerCameraOnUser() {
    if (userPosition == null || mapboxMap == null) return;
    mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: userPosition!),
        zoom: 17.5,
        pitch: 0.0,
      ),
      mp.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  Future<void> _fetchWorkers() async {
    if (widget.serviceType == null || _pointAnnotationManager == null) return;

    try {
      final workerResponse = await Supabase.instance.client
          .from('workers') // Adjust table name if different
          .select('first_name, last_name, profile_image, location_id')
          .eq('organization_type', widget.serviceType!);

      for (var worker in workerResponse) {
        final locationId = worker['location_id'];
        if (locationId == null) continue;

        final locationResponse = await Supabase.instance.client
            .from('locations')
            .select('latitude, longitude')
            .eq('id', locationId)
            .single();

        final workerPosition = mp.Position(
          locationResponse['longitude'],
          locationResponse['latitude'],
        );

        // Fetch profile image as Uint8List
        Uint8List? imageBytes;
        if (worker['profile_image'] != null &&
            worker['profile_image'].isNotEmpty) {
          final response = await http.get(Uri.parse(worker['profile_image']));
          if (response.statusCode == 200) {
            imageBytes = response.bodyBytes;
          }
        }

        // Add worker marker with profile image
        _pointAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: workerPosition),
            image: imageBytes, // Use profile image bytes
            iconSize: 0.5, // Adjust size as needed
            textField: '${worker['first_name']} ${worker['last_name']}',
            textOffset: [0, -1.5],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching workers: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Location'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: mp.MapWidget(
        key: const ValueKey("emergencyMapWidget"),
        styleUri: "mapbox://styles/mapbox/streets-v11",
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
