// ignore_for_file: deprecated_member_use

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
  Timer? _locationUpdateTimer;

  mp.PointAnnotationManager? _workerAnnotationManager;
  mp.PointAnnotationManager? _concernAnnotationManager;

  List<Map<String, dynamic>> _workers = [];
  Uint8List? _locationIconBytes;

  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      userPosition = mp.Position(
        widget.initialPosition!.longitude,
        widget.initialPosition!.latitude,
      );
      debugPrint(
          "Initial position set: lat=${userPosition!.lat}, lng=${userPosition!.lng}");
    }
    _generateLocationIcon();
    _checkPermissionsAndStartTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _showNoNetworkSnackBar({
    Duration duration = _snackBarDisplayDuration,
    Animation<double>? animation,
  }) {
    final snack = SnackBar(
      content: const Text(
          'Failed to Load! No Internet Connection, \n or Network Slow.'),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 20),
      backgroundColor: Colors.redAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      duration: duration,
      animation: animation,
    );

    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<void> _checkPermissionsAndStartTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        debugPrint("Location permissions denied.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      debugPrint("Location permissions permanently denied.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permissions are permanently denied. Please enable them in settings.')),
      );
      return;
    }

    await _getCurrentPositionFallback();
    _startLocationTracking();
  }

  Future<void> _getCurrentPositionFallback() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.bestForNavigation,
      );
      setState(() {
        userPosition = mp.Position(position.longitude, position.latitude);
      });
      debugPrint(
          "Fallback position: lat=${position.latitude}, lng=${position.longitude}");
      if (!_isCameraCentered && widget.service == null) {
        _centerCameraOnUser();
        _isCameraCentered = true;
      }
      if (_locationUpdateTimer == null) {
        _startLocationUpdateTimer();
      }
    } catch (e) {
      _showNoNetworkSnackBar();
    }
  }

  Future<void> _startLocationUpdateTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final residentId = prefs.getInt('resident_id');
    if (residentId == null) {
      debugPrint("Resident ID not found in SharedPreferences.");
      return;
    }

    _locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (userPosition != null) {
        try {
          // Fetch the current is_sharing value
          final existingLocation = await Supabase.instance.client
              .from('live_locations')
              .select('is_sharing')
              .eq('resident_id', residentId)
              .maybeSingle();

          bool currentIsSharing = existingLocation?['is_sharing'] ?? false;

          await Supabase.instance.client.from('live_locations').upsert({
            'resident_id': residentId,
            'latitude': userPosition!.lat,
            'longitude': userPosition!.lng,
            'is_sharing': currentIsSharing, // Preserve the existing value
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint(
              "Updated live_locations: lat=${userPosition!.lat}, lng=${userPosition!.lng}, is_sharing=$currentIsSharing");
        } catch (e) {
          _showNoNetworkSnackBar();
        }
      } else {
        _showNoNetworkSnackBar();
        debugPrint("userPosition is null, skipping live_locations update.");
      }
    });
  }

  Future<void> _generateLocationIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;
    final icon = Icons.location_on;

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: size,
          color: Colors.red,
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

  void _addConcernIcon(mp.Position position) async {
    if (_locationIconBytes == null) return;

    await _concernAnnotationManager?.deleteAll();

    _concernAnnotationManager?.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(coordinates: position),
        image: _locationIconBytes,
        iconSize: 3.0,
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

      _addConcernIcon(position);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concern reported successfully')),
      );
    } catch (e) {
      _showNoNetworkSnackBar();
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
      debugPrint(
          "Received position update: lat=${p.latitude}, lng=${p.longitude}");
      if (!_isCameraCentered && widget.service == null) {
        _centerCameraOnUser();
        _isCameraCentered = true;
      }
      if (_locationUpdateTimer == null) {
        _startLocationUpdateTimer();
      }
    }, onError: (e) {
      _showNoNetworkSnackBar();
      _getCurrentPositionFallback();
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
        _showNoNetworkSnackBar();
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
          SingleChildScrollView(
            child: Container(
              color: Colors.white,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16),
                child: Text(
                  'Share Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
                child: Text(
                  'Tap on the map to report a concern or danger at a specific location.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  child: ClipRRect(
                    child: Stack(
                      children: [
                        mp.MapWidget(
                          key: const ValueKey("emergencyMapWidget"),
                          styleUri: "mapbox://styles/mapbox/streets-v12",
                          onMapCreated: _onMapCreated,
                          onTapListener: (ctx) => _showConcernBottomSheet(
                            mp.Position(
                              ctx.point.coordinates.lng,
                              ctx.point.coordinates.lat,
                            ),
                          ),
                        ),
                        if (userPosition == null) ...[
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Unable to get location"),
                                ElevatedButton(
                                  onPressed: _checkPermissionsAndStartTracking,
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          ),
                        ],
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
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_workers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 8),
                        child: Text(
                          'Employees',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _workers.length,
                          itemBuilder: (_, i) {
                            final w = _workers[i];
                            return Card(
                              color: const Color.fromARGB(255, 240, 240, 240),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  top: 0,
                                  right: 4,
                                  bottom: 0,
                                ),
                                child: GestureDetector(
                                  onTap: () => _centerCameraOnWorker(w),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundImage: (w['profile_image'] !=
                                                    null &&
                                                (w['profile_image'] as String)
                                                    .isNotEmpty)
                                            ? NetworkImage(w['profile_image'])
                                                as ImageProvider
                                            : null,
                                        child: (w['profile_image'] == null ||
                                                (w['profile_image'] as String)
                                                    .isEmpty)
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(w['username'] ?? 'Unknown'),
                                          Text(
                                              'Gender: ${w['gender'] ?? 'N/A'}'),
                                          Text('Phone: ${w['phone'] ?? 'N/A'}'),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        backgroundColor: Colors.white,
                                        radius: 14,
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
                                                size: 12),
                                            color: Colors.black,
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CallEmergencyPage(
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
                            );
                          },
                        ),
                      ),
                    ],
                    if (widget.service != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 16),
                        child: Text(
                          'Agency Name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        margin:
                            const EdgeInsets.only(left: 16, right: 16, top: 8),
                        child: GestureDetector(
                          onTap: _centerCameraOnService,
                          child: Card(
                            color: const Color.fromARGB(255, 198, 198, 198),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  Text('Address: ${widget.service!.address}'),
                                  Text(
                                      'Hotline: ${widget.service!.hotlineNumber}'),
                                  Text('Email: ${widget.service!.email}'),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.phone_rounded, size: 16),
                                          SizedBox(width: 8),
                                          Text('Call Agency',
                                              style: TextStyle(fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
