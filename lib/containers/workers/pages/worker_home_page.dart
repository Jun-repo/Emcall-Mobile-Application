// worker_home_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_import

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:emcall/containers/workers/pages/routing_map_page.dart';
import 'package:emcall/containers/workers/pages/video_reels_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  WorkerHomePageState createState() => WorkerHomePageState();
}

class WorkerHomePageState extends State<WorkerHomePage> {
  mp.MapboxMap? _mapController;
  Position? _currentPosition;
  mp.PointAnnotationManager? _pointAnnotationManager;
  final Map<String, int> _annotationToResidentId = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _liveLocationsSubscription;
  String? firstName;
  String? middleName;
  String? lastName;
  String? suffix;
  String? organizationType;
  int? workerId;
  final List<ResidentCall> _residentCalls = [];

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _liveLocationsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('worker_email');
    final storedWorkerId = prefs.getInt('worker_id');

    if (email == null || storedWorkerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker not authenticated')),
        );
      }
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
        workerId = response['id'];
      });

      if (kDebugMode) {
        print(
            "Loaded worker: $firstName $lastName, Organization: $organizationType");
      }

      _listenForLiveLocations();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied forever')),
        );
      }
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

    // Update position stream to track location without auto-recentering
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      // Removed flyTo to prevent automatic recentering
    });
  }

  // New method to recenter map to worker's location
  void _recenterToWorker() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 14,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _listenForLiveLocations() {
    if (organizationType == null) {
      if (kDebugMode) print("Organization type is not loaded yet.");
      return;
    }

    // Cancel any existing subscription to avoid duplicates
    _liveLocationsSubscription?.cancel();

    // Set up real-time subscription for live_locations
    _liveLocationsSubscription = Supabase.instance.client
        .from('live_locations')
        .stream(primaryKey: ['resident_id']).listen(
      (List<Map<String, dynamic>> data) async {
        if (kDebugMode) print("Live location data received: $data");

        for (var location in data) {
          final residentId = location['resident_id'];
          final isSharing = location['is_sharing'] == true;

          if (isSharing) {
            // Fetch the latest service call for the resident
            final serviceCall = await Supabase.instance.client
                .from('service_calls')
                .select()
                .eq('resident_id', residentId)
                .eq('service_type', organizationType!)
                .eq('shared_location', true)
                .limit(1)
                .maybeSingle();

            if (serviceCall != null) {
              await _handleNewCall(location, serviceCall);
            } else {
              if (kDebugMode) {
                print(
                    "No service_call found for resident_id $residentId with organization type $organizationType");
              }
              // Remove the call if it no longer matches the service type
              setState(() {
                _residentCalls
                    .removeWhere((call) => call.residentId == residentId);
              });
              await _updateResidentMarkers();
            }
          } else {
            // Remove the call if is_sharing is false
            setState(() {
              _residentCalls
                  .removeWhere((call) => call.residentId == residentId);
            });
            await _updateResidentMarkers();
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print("Error in live locations subscription: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error in live location updates: $error')),
          );
        }
      },
    );
  }

  Future<void> _handleNewCall(Map<String, dynamic> locationData,
      Map<String, dynamic> serviceCall) async {
    final residentId = locationData['resident_id'];
    final residentResponse = await Supabase.instance.client
        .from('residents')
        .select(
            'id, first_name, last_name, middle_name, suffix_name, username, address, birth_date, status, gender, personal_email, phone, valid_id, face_recognition_image_url, profile_image, location_id')
        .eq('id', residentId)
        .single();

    final locationId = residentResponse['location_id'];
    if (locationId == null) {
      if (kDebugMode) print("Resident (ID: $residentId) has no location_id.");
      return;
    }

    final locationResponse = await Supabase.instance.client
        .from('locations')
        .select('latitude, longitude, address')
        .eq('id', locationId)
        .single();

    final newCall = ResidentCall(
      id: serviceCall['id'],
      residentId: residentId,
      firstName: (residentResponse['first_name'] as String?) ?? '',
      lastName: (residentResponse['last_name'] as String?) ?? '',
      middleName: (residentResponse['middle_name'] as String?) ?? '',
      suffixName: (residentResponse['suffix_name'] as String?) ?? '',
      username: (residentResponse['username'] as String?) ?? '',
      address: ((residentResponse['address'] as String?) ??
          (locationResponse['address'] as String?) ??
          'Unknown'),
      birthDate: residentResponse['birth_date']?.toString() ?? '',
      status: (residentResponse['status'] as String?) ?? '',
      gender: (residentResponse['gender'] as String?) ?? '',
      personalEmail: (residentResponse['personal_email'] as String?) ?? '',
      phone: (residentResponse['phone'] as String?) ?? '',
      validId: (residentResponse['valid_id'] as String?) ?? '',
      faceRecognitionImageUrl:
          (residentResponse['face_recognition_image_url'] as String?) ?? '',
      profileImage: (residentResponse['profile_image'] as String?) ?? '',
      location: mp.Position(
        locationData['longitude'],
        locationData['latitude'],
      ),
    );

    setState(() {
      final index = _residentCalls
          .indexWhere((call) => call.residentId == newCall.residentId);
      if (index == -1) {
        _residentCalls.add(newCall);
      } else {
        _residentCalls[index] = newCall;
      }
    });

    if (kDebugMode) {
      print(
          "New call added for residentId: $residentId at ${newCall.location}");
    }

    await _updateResidentMarkers();
  }

  Future<void> _updateResidentMarkers() async {
    if (_mapController == null || _pointAnnotationManager == null) {
      if (kDebugMode)
        print("Map controller or point annotation manager is not ready.");
      return;
    }

    await _pointAnnotationManager!.deleteAll();
    _annotationToResidentId.clear();

    for (var call in _residentCalls) {
      final imageData = await _getImageData(call.profileImage, context);
      if (imageData != null) {
        final annotation = await _pointAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: call.location),
            image: imageData,
            iconSize: 0.6,
            iconAnchor: mp.IconAnchor.CENTER,
            symbolSortKey: 2,
          ),
        );
        _annotationToResidentId[annotation.id] = call.residentId;
      } else if (kDebugMode) {
        print("Failed to get image data for residentId: ${call.residentId}");
      }
    }
  }

  Future<void> _markCallAsCompleted(int callId, int residentId) async {
    try {
      await Supabase.instance.client
          .from('service_calls')
          .update({'shared_location': false}).eq('id', callId);

      await Supabase.instance.client
          .from('live_locations')
          .update({'is_sharing': false}).eq('resident_id', residentId);

      setState(() {
        _residentCalls.removeWhere((call) => call.residentId == residentId);
      });

      await _updateResidentMarkers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing call: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _getImageData(
      String imageUrl, BuildContext context) async {
    // Define the size for the circle and the tail.
    const double circleSize = 200.0; // Diameter of the profile circle.
    const double tailHeight = 40.0; // Height of the inverted triangle tail.
    const double tailWidth = 70.0; // Width of the tail.
    const double overlap = 20.0; // Amount of overlap between tail and circle
    final double overallHeight = circleSize + tailHeight - overlap;

    // Create a recording canvas of the overall size.
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, circleSize, overallHeight));

    // Define the circle center and radius.
    final circleCenter = Offset(circleSize / 2, circleSize / 2);
    final circleRadius = circleSize / 2 - 10;

    // Define shadow properties.
    final shadowColor = Colors.black.withOpacity(0.7);
    const shadowBlurRadius = 8.0;

    // Create the tail path for the inverted triangle.
    final tailPath = ui.Path();
    final tailTopY = circleSize - overlap;
    tailPath.moveTo((circleSize - tailWidth) / 2, tailTopY);
    tailPath.lineTo((circleSize + tailWidth) / 2, tailTopY);
    tailPath.lineTo(circleSize / 2, tailTopY + tailHeight + 20 - overlap);
    tailPath.close();

    // Draw shadow for the tail.
    canvas.drawShadow(tailPath, shadowColor, shadowBlurRadius, false);

    // Paint for the tail fill.
    final tailPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(tailPath, tailPaint);

    // Draw a stroke around the tail.
    final tailBorderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawPath(tailPath, tailBorderPaint);

    // Create the circle path for the avatar.
    final circlePath = ui.Path()
      ..addOval(Rect.fromCircle(center: circleCenter, radius: circleRadius));

    // Draw shadow for the circle.
    canvas.drawShadow(circlePath, shadowColor, shadowBlurRadius, false);

    // Draw the border circle for the profile image.
    final borderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 15.0;
    canvas.drawCircle(circleCenter, circleRadius, borderPaint);

    // Set up a clipping path to limit drawing inside the circular area.
    final clipPath = ui.Path()
      ..addOval(
          Rect.fromCircle(center: circleCenter, radius: circleRadius - 10));
    canvas.save();
    canvas.clipPath(clipPath);

    // Draw the profile image into the circle.
    if (imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          final image = frame.image;
          const double padding = 20.0;
          final dstRect = ui.Rect.fromLTWH(padding, padding,
              circleSize - 2 * padding, circleSize - 2 * padding);
          final srcRect = ui.Rect.fromLTWH(
              0, 0, image.width.toDouble(), image.height.toDouble());
          canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
          image.dispose();
        } else {
          if (kDebugMode) print('Failed to load image: ${response.statusCode}');
        }
      } catch (e) {
        if (kDebugMode) print('Error loading image: $e');
      }
    } else {
      // Load a default asset image.
      final defaultImage =
          await DefaultAssetBundle.of(context).load('assets/icons/person.png');
      final codec =
          await ui.instantiateImageCodec(defaultImage.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      const double padding = 20.0;
      final dstRect = ui.Rect.fromLTWH(
          padding, padding, circleSize - 2 * padding, circleSize - 2 * padding);
      final srcRect = ui.Rect.fromLTWH(
          0, 0, image.width.toDouble(), image.height.toDouble());
      canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
      image.dispose();
    }

    // Restore the canvas (remove the clip).
    canvas.restore();

    // End recording and convert to byte data.
    final picture = recorder.endRecording();
    final img =
        await picture.toImage(circleSize.toInt(), overallHeight.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  void _animateToCallLocation(mp.Position location,
      {bool withPadding = false}) {
    if (_mapController != null) {
      final padding = withPadding
          ? mp.MbxEdgeInsets(
              top: 0,
              left: 0,
              bottom: MediaQuery.of(context).size.height * 0.7,
              right: 0,
            )
          : mp.MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0);
      _mapController!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: location),
          zoom: 14,
          padding: padding,
        ),
        mp.MapAnimationOptions(duration: 1000),
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
          zoom: 20,
        ),
        mp.MapAnimationOptions(duration: 2000),
      );
    }

    await _updateResidentMarkers();
  }

  void _showResidentDetails(ResidentCall call) {
    showBarModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      topControl: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      expand: false,
      builder: (context) {
        return Container(
          // Set the height to 70% of the screen height.
          height: MediaQuery.of(context).size.height * 0.70,
          color: Colors.white,
          child: AnimatedBottomSheetContent(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image.
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: call.profileImage.isNotEmpty
                            ? CachedNetworkImageProvider(call.profileImage)
                            : null,
                        child: call.profileImage.isEmpty
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Username in big, bold font.
                    Center(
                      child: Text(
                        call.username,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Card containing ID, Full Name, Address, Birthday, Status, and Gender.
                    Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("ID: ${call.residentId}"),
                            const SizedBox(height: 4),
                            Text(
                                "Full Name: ${call.firstName} ${call.middleName} ${call.lastName} ${call.suffixName}"),
                            const SizedBox(height: 4),
                            Text("Address: ${call.address}"),
                            const SizedBox(height: 4),
                            Text("Birth Date: ${call.birthDate}"),
                            const SizedBox(height: 4),
                            Text("Status: ${call.status}"),
                            const SizedBox(height: 4),
                            Text("Gender: ${call.gender}"),
                          ],
                        ),
                      ),
                    ),
                    // Card containing Email and Phone.
                    Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text("Email: ${call.personalEmail}")),
                            const SizedBox(width: 12),
                            Expanded(child: Text("Phone: ${call.phone}")),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Horizontal scrollable row for image cards (Valid ID and Face Recognition).
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Card for Valid ID image.
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            child: Container(
                              width: 200,
                              height: 200,
                              child: call.validId.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: call.validId,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    )
                                  : const Center(
                                      child: Text("No Valid ID Image")),
                            ),
                          ),
                          // Card for Face Recognition image.
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            child: Container(
                              width: 200,
                              height: 200,
                              child: call.faceRecognitionImageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: call.faceRecognitionImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    )
                                  : const Center(
                                      child: Text("No Face Recognition Image")),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _animateToCallLocation(call.location, withPadding: false);
    });
    _animateToCallLocation(call.location, withPadding: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            child: mp.MapWidget(
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
          ),
          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton(
              heroTag: "videoReelsButton",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoReelsPage(workerId: workerId),
                  ),
                );
              },
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.video_call,
                color: Colors.black,
              ),
            ),
          ),
          // New routing map button above the recenter button
          Positioned(
            bottom: _residentCalls.isEmpty ? 110 : 210,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'routingMapButton',
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        RoutingMapPage(
                      residentPosition: _residentCalls.first.location,
                      residentImageUrl: _residentCalls.first.profileImage,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final tween =
                          Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.ease));
                      return SlideTransition(
                          position: animation.drive(tween), child: child);
                    },
                  ),
                );
              },
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.map_rounded,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            bottom: _residentCalls.isEmpty ? 50 : 150,
            right: 16,
            child: FloatingActionButton(
              heroTag: "recenterButton",
              onPressed: _recenterToWorker,
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.my_location_rounded,
                color: Colors.black,
              ),
            ),
          ),
          // Resident calls carousel with per-card routing button
          if (_residentCalls.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  height: 150,
                  color: Colors.transparent,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _residentCalls.length,
                    itemBuilder: (context, index) {
                      final call = _residentCalls[index];
                      return ResidentCallCard(
                        call: call,
                        onDone: () =>
                            _markCallAsCompleted(call.id, call.residentId),
                        onLocate: () => _animateToCallLocation(call.location),
                        onShowDetails: () => _showResidentDetails(call),
                        onRoute: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (ctx, anim, secAnim) =>
                                  RoutingMapPage(
                                residentPosition: call.location,
                                residentImageUrl: call.profileImage,
                              ),
                              transitionsBuilder: (ctx, anim, secAnim, child) {
                                final tween = Tween(
                                        begin: const Offset(1, 0),
                                        end: Offset.zero)
                                    .chain(CurveTween(curve: Curves.easeOut));
                                return SlideTransition(
                                  position: anim.drive(tween),
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnimatedBottomSheetContent extends StatefulWidget {
  final Widget child;
  const AnimatedBottomSheetContent({Key? key, required this.child})
      : super(key: key);

  @override
  _AnimatedBottomSheetContentState createState() =>
      _AnimatedBottomSheetContentState();
}

class _AnimatedBottomSheetContentState extends State<AnimatedBottomSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Delay the start of the animation by 300ms.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class ResidentCall {
  final int id;
  final int residentId;
  final String firstName;
  final String lastName;
  final String middleName;
  final String suffixName;
  final String username;
  final String address;
  final String birthDate;
  final String status;
  final String gender;
  final String personalEmail;
  final String phone;
  final String validId;
  final String faceRecognitionImageUrl;
  final String profileImage;
  final mp.Position location;

  ResidentCall({
    required this.id,
    required this.residentId,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.suffixName,
    required this.username,
    required this.address,
    required this.birthDate,
    required this.status,
    required this.gender,
    required this.personalEmail,
    required this.phone,
    required this.validId,
    required this.faceRecognitionImageUrl,
    required this.profileImage,
    required this.location,
  });

  String get fullName => '$firstName $lastName';
}

class ResidentCallCard extends StatelessWidget {
  final ResidentCall call;
  final VoidCallback onDone;
  final VoidCallback onLocate;
  final VoidCallback onShowDetails;
  final VoidCallback onRoute;
  const ResidentCallCard({
    super.key,
    required this.call,
    required this.onDone,
    required this.onLocate,
    required this.onShowDetails,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onShowDetails,
      child: Container(
        width: 300,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: call.profileImage.isNotEmpty
                  ? CachedNetworkImageProvider(call.profileImage)
                  : null,
              child: call.profileImage.isEmpty
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    call.address,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child:
                            const Text('Done', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: onLocate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child: const Text('Locate',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.map, size: 20),
                        onPressed: onRoute,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
