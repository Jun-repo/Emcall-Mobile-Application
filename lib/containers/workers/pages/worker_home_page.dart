// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  WorkerHomePageState createState() => WorkerHomePageState();
}

class WorkerHomePageState extends State<WorkerHomePage> {
  mp.MapboxMap? _mapController;
  Position? _currentPosition;
  ResidentCall? _currentCall;
  mp.PointAnnotationManager? _pointAnnotationManager;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Store worker data
  String? firstName;
  String? middleName;
  String? lastName;
  String? suffix;
  String? organizationType;

  // Store the service call id for later updates.
  int? _currentCallId;

  // Maintain a list of resident calls.
  final List<ResidentCall> _residentCalls = [];

  @override
  void initState() {
    super.initState();
    _loadWorkerData(); // Fetch worker data from Supabase
    _getCurrentLocation();
    _listenForCalls();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Fetch worker data from Supabase based on authenticated user.
  Future<void> _loadWorkerData() async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        prefs.getString('worker_email'); // Assuming worker logs in with email

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker not authenticated')),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('workers')
          .select()
          .eq('personal_email', email)
          .single();

      setState(() {
        firstName = response['first_name'];
        middleName = response['middle_name'];
        lastName = response['last_name'];
        suffix = response['suffix_name'];
        organizationType = response['organization_type'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading worker data: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied forever')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });

    if (_mapController != null) {
      _mapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 14,
        ),
        mp.MapAnimationOptions(duration: 2000),
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      if (_mapController != null) {
        _mapController!.flyTo(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(position.longitude, position.latitude),
            ),
            zoom: 14,
          ),
          mp.MapAnimationOptions(duration: 500),
        );
      }
    });
  }

  void _listenForCalls() {
    // Ensure organizationType is loaded before listening for calls.
    if (organizationType == null) {
      return;
    }
    Supabase.instance.client
        .from('service_calls')
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      for (var call in data) {
        // Process only calls matching the worker's organization type and with shared_location true.
        if (call['service_type'] == organizationType &&
            call['shared_location'] == true) {
          _handleNewCall(call);
        }
      }
    });
  }

  Future<void> _handleNewCall(Map<String, dynamic> callData) async {
    // Only handle the call if shared_location is true.
    if (callData['shared_location'] != true) {
      return;
    }

    // Store the call id for later update.
    _currentCallId = callData['id'];

    final residentId = callData['resident_id'];
    final residentResponse = await Supabase.instance.client
        .from('residents')
        .select()
        .eq('id', residentId)
        .single();

    final locationId = residentResponse['location_id'];
    final locationResponse = await Supabase.instance.client
        .from('locations')
        .select()
        .eq('id', locationId)
        .single();

    final newCall = ResidentCall(
      id: callData['id'],
      profileImage: residentResponse['profile_image'] ?? '',
      fullName:
          '${residentResponse['first_name']} ${residentResponse['last_name']}',
      address: locationResponse['address'] ?? 'Unknown',
      age: _calculateAge(residentResponse['birth_date']),
      gender: residentResponse['gender'] ?? 'Not specified',
      location: mp.Position(
        locationResponse['longitude'],
        locationResponse['latitude'],
      ),
    );

    setState(() {
      _currentCall = newCall;
      // Add to list if not already present.
      if (!_residentCalls.any((call) => call.id == newCall.id)) {
        _residentCalls.add(newCall);
      }
    });

    // Show the resident marker on the map.
    if (_mapController != null &&
        _pointAnnotationManager != null &&
        _currentCall != null) {
      _pointAnnotationManager!.deleteAll();
      _pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(coordinates: _currentCall!.location),
          image: null, // Use a default marker image or customize as needed.
          iconSize: 1.0,
          textField: _currentCall!.fullName,
          textOffset: [0, -1.5],
        ),
      );
    }
  }

  int _calculateAge(String? birthDate) {
    if (birthDate == null) return 0;
    DateTime dob = DateTime.parse(birthDate);
    DateTime now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // Called when the worker taps the "Done" button.
  Future<void> _markCallAsCompleted() async {
    if (_currentCallId == null) return;

    final response = await Supabase.instance.client
        .from('service_calls')
        .update({'shared_location': false})
        .eq('id', _currentCallId!)
        .maybeSingle();

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating call: Response is null')),
      );
      return;
    }

    setState(() {
      // Remove the call from the list before clearing current call.
      _residentCalls.removeWhere((call) => call.id == _currentCallId);
      _currentCall = null;
      _currentCallId = null;
    });

    // Remove the resident marker from the map.
    _pointAnnotationManager?.deleteAll();
  }

  // Animate the map center to the resident call's location.
  void _animateToCallLocation(ResidentCall call) {
    if (_mapController != null) {
      _mapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: call.location),
          zoom: 14,
        ),
        mp.MapAnimationOptions(duration: 500),
      );
    }
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    _mapController = controller;
    _pointAnnotationManager =
        await controller.annotations.createPointAnnotationManager();

    await controller.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: Colors.blue.value,
        puckBearingEnabled: true,
        puckBearing: mp.PuckBearing.COURSE,
      ),
    );

    if (_currentPosition != null) {
      controller.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
                _currentPosition!.longitude, _currentPosition!.latitude),
          ),
          zoom: 14,
        ),
        mp.MapAnimationOptions(duration: 2000),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          mp.MapWidget(
            key: const ValueKey("workerMapWidget"),
            styleUri: "mapbox://styles/mapbox/streets-v11",
            onMapCreated: _onMapCreated,
            cameraOptions: mp.CameraOptions(
              center: _currentPosition != null
                  ? mp.Point(
                      coordinates: mp.Position(
                        _currentPosition!.longitude,
                        _currentPosition!.latitude,
                      ),
                    )
                  : null,
              zoom: 14,
            ),
          ),
          // Optionally display a ResidentCallCard above the horizontal list.
          if (_currentCall != null)
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: ResidentCallCard(
                call: _currentCall!,
                onDone: _markCallAsCompleted,
              ),
            ),
          // Horizontally scrolling list of resident avatars.
          if (_residentCalls.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                color: Colors.white.withOpacity(0.8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _residentCalls.length,
                  itemBuilder: (context, index) {
                    final call = _residentCalls[index];
                    return GestureDetector(
                      onTap: () => _animateToCallLocation(call),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: call.profileImage.isNotEmpty
                              ? NetworkImage(call.profileImage)
                              : null,
                          child: call.profileImage.isEmpty
                              ? const Icon(Icons.person, size: 30)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ResidentCall {
  final int id; // Unique service call id.
  final String profileImage;
  final String fullName;
  final String address;
  final int age;
  final String gender;
  final mp.Position location;

  ResidentCall({
    required this.id,
    required this.profileImage,
    required this.fullName,
    required this.address,
    required this.age,
    required this.gender,
    required this.location,
  });
}

class ResidentCallCard extends StatelessWidget {
  final ResidentCall call;
  final VoidCallback onDone;

  const ResidentCallCard({super.key, required this.call, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // You may show additional details or options when the marker is tapped.
            },
            child: CircleAvatar(
              backgroundImage: call.profileImage.isNotEmpty
                  ? NetworkImage(call.profileImage)
                  : null,
              radius: 30,
              child: call.profileImage.isEmpty
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(call.address),
                Text('Age: ${call.age}'),
                Text('Gender: ${call.gender}'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
