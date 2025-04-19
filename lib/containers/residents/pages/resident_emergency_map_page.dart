import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:emcall/containers/residents/pages/call_emergency_page.dart';
import 'package:emcall/pages/services/service_info.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class ResidentEmergencyMapPage extends StatefulWidget {
  final gl.Position? initialPosition;
  final String? serviceType;
  final ServiceInfo? service;

  const ResidentEmergencyMapPage({
    super.key,
    this.initialPosition,
    this.serviceType,
    this.service,
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

  mp.PointAnnotationManager? _workerAnnotationManager;
  mp.PointAnnotationManager? _concernAnnotationManager;

  List<Map<String, dynamic>> _workers = [];
  Uint8List? _locationIconBytes;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      userPosition = mp.Position(
        widget.initialPosition!.longitude,
        widget.initialPosition!.latitude,
      );
    }
    _generateLocationIcon();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Method to render the Icons.location_on to Uint8List
  Future<void> _generateLocationIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0; // Size of the icon
    final icon = Icons.location_on;

    // Create a TextPainter to render the icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: size,
          color: Colors.red, // Customize the icon color
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    setState(() {
      _locationIconBytes = byteData!.buffer.asUint8List();
    });
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    mapboxMap = controller;
    _workerAnnotationManager =
        await controller.annotations.createPointAnnotationManager();
    _concernAnnotationManager =
        await controller.annotations.createPointAnnotationManager();

    await _initializeMap(controller);
    await _fetchWorkers();

    controller.onMapTapListener = (mp.MapContentGestureContext ctx) {
      final lat = ctx.point.coordinates.lat;
      final lng = ctx.point.coordinates.lng;
      final pos = mp.Position(lng, lat);
      _addConcernIcon(pos);
      _showConcernBottomSheet(pos);
    };
  }

  // Method to add the location icon at the tapped position
  void _addConcernIcon(mp.Position position) async {
    if (_locationIconBytes == null) return; // Wait until icon is generated

    await _concernAnnotationManager?.deleteAll(); // Clear previous annotations

    _concernAnnotationManager?.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(coordinates: position),
        image: _locationIconBytes, // Use the rendered icon
        iconSize: 3.0, // Adjust size as needed
        textField: 'Concern',
        textOffset: [0, -1.5],
      ),
    );
  }

  void _showConcernBottomSheet(mp.Position position) {
    final descriptionController = TextEditingController();
    final involvementController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Report Concern/Danger',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Describe',
                hintText: 'Describe the concern or danger',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: involvementController,
              decoration: const InputDecoration(
                labelText: 'Involvement Level',
                hintText: 'E.g., Low, High, or number of people',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _concernAnnotationManager?.deleteAll();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (descriptionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Description is required')),
                      );
                      return;
                    }
                    _submitConcern(
                      position,
                      descriptionController.text,
                      involvementController.text,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submitConcern(
    mp.Position position,
    String description,
    String involvement,
  ) async {
    try {
      final address = await _getAddressFromCoordinates(
        position.lat as double,
        position.lng as double,
      );

      final prefs = await SharedPreferences.getInstance();
      final residentId = prefs.getInt('resident_id');

      final payload = {
        if (residentId != null) 'resident_id': residentId,
        'latitude': position.lat,
        'longitude': position.lng,
        'address': address,
        'description': description,
        'involvement_level': involvement,
      };

      await Supabase.instance.client
          .from('concern_danger_location')
          .insert(payload);

      // Add the concern icon to the map at the reported location
      _addConcernIcon(position);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concern reported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reporting concern: $e')),
      );
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json'
          '&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'YourAppName/1.0 (your.email@example.com)',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown address';
      }
      return 'Unknown address';
    } catch (_) {
      return 'Unknown address';
    }
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

    if (widget.service != null) {
      final svc = widget.service!;
      final svcPos = mp.Position(svc.longitude, svc.latitude);
      await controller.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: svcPos),
          zoom: 15,
        ),
        mp.MapAnimationOptions(duration: 1000, startDelay: 0),
      );
      _workerAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(coordinates: svcPos),
          textField: svc.orgName,
          textOffset: [0, -1.5],
        ),
      );
    } else if (userPosition != null && !_isCameraCentered) {
      _centerCameraOnUser();
      _isCameraCentered = true;
    }
  }

  void _startLocationTracking() {
    const settings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _positionStreamSubscription = gl.Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((gl.Position p) {
      setState(() {
        userPosition = mp.Position(p.longitude, p.latitude);
      });
      if (!_isCameraCentered && widget.service == null) {
        _centerCameraOnUser();
        _isCameraCentered = true;
      }
    });
  }

  void _centerCameraOnUser() {
    if (mapboxMap == null || userPosition == null) return;
    mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: userPosition!),
        zoom: 17.5,
      ),
      mp.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  Future<void> _fetchWorkers() async {
    if (_workerAnnotationManager == null) return;
    try {
      var query = Supabase.instance.client.from('workers').select(r'''
        id, username, gender, phone, profile_image, location_id,
        locations!inner(latitude, longitude)
      ''');

      if (widget.service != null) {
        query = query
            .eq('organization_type', widget.service!.serviceType.toLowerCase())
            .eq('organization_id', widget.service!.id);
      } else if (widget.serviceType != null) {
        query = query.eq(
          'organization_type',
          widget.serviceType!.toLowerCase(),
        );
      } else {
        return;
      }

      final List<Map<String, dynamic>> rows =
          List<Map<String, dynamic>>.from(await query);
      setState(() => _workers = rows);

      for (final w in rows) {
        final loc = w['locations'] as Map<String, dynamic>?;
        if (loc == null) continue;

        final pos = mp.Position(
          loc['longitude'] as double,
          loc['latitude'] as double,
        );

        Uint8List? imgBytes;
        if ((w['profile_image'] as String?)?.isNotEmpty == true) {
          final resp = await http.get(Uri.parse(w['profile_image']));
          if (resp.statusCode == 200) imgBytes = resp.bodyBytes;
        }

        _workerAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: pos),
            image: imgBytes,
            iconSize: 3.0,
            textField: w['username'],
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

  void _centerCameraOnService() {
    if (widget.service == null || mapboxMap == null) return;
    final svc = widget.service!;
    final pos = mp.Position(svc.longitude, svc.latitude);
    mapboxMap!.flyTo(
      mp.CameraOptions(center: mp.Point(coordinates: pos), zoom: 17.5),
      mp.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  void _centerCameraOnWorker(Map<String, dynamic> worker) {
    if (mapboxMap == null) return;
    final loc = worker['locations'] as Map<String, dynamic>?;
    if (loc == null) return;
    final pos = mp.Position(
      loc['longitude'] as double,
      loc['latitude'] as double,
    );
    mapboxMap!.flyTo(
      mp.CameraOptions(center: mp.Point(coordinates: pos), zoom: 17.5),
      mp.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workers ListView
              if (_workers.isNotEmpty)
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Employees',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 120,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _workers.length,
                            itemBuilder: (_, i) {
                              final w = _workers[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => _centerCameraOnWorker(w),
                                  child: Card(
                                    color: const Color.fromARGB(
                                        255, 198, 198, 198),
                                    child: Container(
                                      width: 150,
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundImage:
                                                (w['profile_image'] != null &&
                                                        (w['profile_image']
                                                                as String)
                                                            .isNotEmpty)
                                                    ? NetworkImage(
                                                            w['profile_image'])
                                                        as ImageProvider
                                                    : null,
                                            child:
                                                (w['profile_image'] == null ||
                                                        (w['profile_image']
                                                                as String)
                                                            .isEmpty)
                                                    ? const Icon(Icons.person)
                                                    : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    w['username'] ?? 'Unknown'),
                                                Text(
                                                    'Gender: ${w['gender'] ?? 'N/A'}'),
                                                Text(
                                                    'Phone: ${w['phone'] ?? 'N/A'}'),
                                              ],
                                            ),
                                          ),
                                          CircleAvatar(
                                            backgroundColor: Colors.white,
                                            radius: 22,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.black,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                    Icons.phone_rounded,
                                                    size: 25),
                                                color: Colors.black,
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          CallEmergencyPage(
                                                        service:
                                                            widget.service!,
                                                        currentPosition: widget
                                                            .initialPosition,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Service Card
              if (widget.service != null)
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Agency Name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _centerCameraOnService,
                        child: Card(
                          color: const Color.fromARGB(255, 198, 198, 198),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.service!.orgName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Address: ${widget.service!.address}'),
                                      Text(
                                          'Hotline: ${widget.service!.hotlineNumber}'),
                                      Text('Email: ${widget.service!.email}'),
                                    ],
                                  ),
                                ),
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.phone_rounded,
                                          size: 25),
                                      color: Colors.black,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CallEmergencyPage(
                                              service: widget.service!,
                                              currentPosition:
                                                  widget.initialPosition,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Map Title and Description
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap on the map to report a concern or danger at your location.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Map in the center, taking remaining space
              Expanded(
                child: Container(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  child: ClipRRect(
                    child: Stack(
                      children: [
                        mp.MapWidget(
                          key: const ValueKey("emergencyMapWidget"),
                          styleUri: "mapbox://styles/mapbox/streets-v11",
                          onMapCreated: _onMapCreated,
                          onTapListener: (ctx) => _showConcernBottomSheet(
                            mp.Position(
                              ctx.point.coordinates.lng,
                              ctx.point.coordinates.lat,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            onPressed: _centerCameraOnUser,
                            backgroundColor: Colors.redAccent,
                            child: const Icon(Icons.my_location,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
