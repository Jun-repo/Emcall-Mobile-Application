// worker_home_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_import

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:emcall/containers/workers/pages/menu_page.dart';
import 'package:emcall/containers/workers/pages/routing_map_page.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final PanelController _panelController = PanelController();

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

  void _showErrorSnackBar({
    required String component,
    Duration duration = const Duration(seconds: 3),
    Animation<double>? animation,
  }) {
    final snack = SnackBar(
      content: Text(
        'No internet connection. Please check your network. Cannot load properly the $component.',
        style: const TextStyle(color: Colors.white),
      ),
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

  Future<void> _loadWorkerData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('worker_email');
    final storedWorkerId = prefs.getInt('worker_id');

    if (email == null || storedWorkerId == null) {
      if (mounted) {
        _showErrorSnackBar(component: 'worker authentication');
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
        if (kDebugMode) {
          print("organizationType loaded: $organizationType");
        }
      });

      if (kDebugMode) {
        print(
            "Loaded worker: $firstName $lastName, Organization: $organizationType");
      }

      // Fetch initial live locations and start listening for updates
      await _fetchInitialLiveLocations();
      _listenForLiveLocations();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(component: 'worker data');
      }
    }
  }

  Future<void> _fetchInitialLiveLocations() async {
    if (organizationType == null) {
      if (kDebugMode) print("Organization type is not loaded yet for fetch.");
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('live_locations')
          .select()
          .eq('is_sharing', true);

      if (kDebugMode) {
        print("Initial live locations fetched: $data");
      }

      if (data.isEmpty) {
        if (kDebugMode) print("No live locations with is_sharing = true.");
        setState(() {
          _residentCalls.clear();
        });
        await _updateResidentMarkers();
        return;
      }

      for (var location in data) {
        final residentId = location['resident_id'];
        final isSharing = location['is_sharing'] == true;

        if (residentId == null) {
          if (kDebugMode) print("Resident ID is null in live_locations data");
          continue;
        }

        if (kDebugMode) {
          print("Processing residentId: $residentId, isSharing: $isSharing");
        }

        if (isSharing) {
          final serviceCall = await Supabase.instance.client
              .from('service_calls')
              .select()
              .eq('resident_id', residentId)
              .eq('service_type', organizationType!.toLowerCase())
              .eq('shared_location', true)
              .limit(1)
              .maybeSingle();

          if (kDebugMode) {
            print(
                "Initial service call for residentId $residentId: $serviceCall");
          }

          if (serviceCall != null) {
            await _handleNewCall(location, serviceCall);
          } else {
            if (kDebugMode) {
              print(
                  "No matching service_call found for resident_id $residentId with organization type $organizationType");
            }
            setState(() {
              _residentCalls
                  .removeWhere((call) => call.residentId == residentId);
            });
            await _updateResidentMarkers();
          }
        } else {
          if (kDebugMode) {
            print(
                "is_sharing is false for residentId $residentId, removing from resident calls");
          }
          setState(() {
            _residentCalls.removeWhere((call) => call.residentId == residentId);
          });
          await _updateResidentMarkers();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching initial live locations: $e");
      }
      if (mounted) {
        _showErrorSnackBar(component: 'initial live locations');
      }
    }
  }

  Future<void> _fetchLiveLocations() async {
    if (organizationType == null) {
      if (kDebugMode) print("Organization type is not loaded yet for fetch.");
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('live_locations')
          .select()
          .eq('is_sharing', true);

      if (kDebugMode) {
        print("Fetched live locations (manual refresh): $data");
      }

      if (data.isEmpty) {
        if (kDebugMode) print("No live locations with is_sharing = true.");
        setState(() {
          _residentCalls.clear();
        });
        await _updateResidentMarkers();
        return;
      }

      for (var location in data) {
        final residentId = location['resident_id'];
        final isSharing = location['is_sharing'] == true;

        if (residentId == null) {
          if (kDebugMode) print("Resident ID is null in live_locations data");
          continue;
        }

        if (kDebugMode) {
          print("Processing residentId: $residentId, isSharing: $isSharing");
        }

        if (isSharing) {
          final serviceCall = await Supabase.instance.client
              .from('service_calls')
              .select()
              .eq('resident_id', residentId)
              .eq('service_type', organizationType!.toLowerCase())
              .eq('shared_location', true)
              .limit(1)
              .maybeSingle();

          if (kDebugMode) {
            print("Service call for residentId $residentId: $serviceCall");
          }

          if (serviceCall != null) {
            await _handleNewCall(location, serviceCall);
          } else {
            if (kDebugMode) {
              print(
                  "No matching service_call found for resident_id $residentId with organization type $organizationType");
            }
            setState(() {
              _residentCalls
                  .removeWhere((call) => call.residentId == residentId);
            });
            await _updateResidentMarkers();
          }
        } else {
          if (kDebugMode) {
            print(
                "is_sharing is false for residentId $residentId, removing from resident calls");
          }
          setState(() {
            _residentCalls.removeWhere((call) => call.residentId == residentId);
          });
          await _updateResidentMarkers();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching live locations (manual refresh): $e");
      }
      if (mounted) {
        _showErrorSnackBar(component: 'live locations (manual refresh)');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showErrorSnackBar(component: 'location services');
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showErrorSnackBar(component: 'location permission');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showErrorSnackBar(component: 'location permission');
      }
      return;
    }

    try {
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
      }, onError: (e) {
        if (mounted) {
          _showErrorSnackBar(component: 'location updates');
        }
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(component: 'current location');
      }
    }
  }

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

    _liveLocationsSubscription?.cancel();

    if (kDebugMode) {
      print(
          "Starting live locations stream for organizationType: $organizationType");
    }

    _liveLocationsSubscription = Supabase.instance.client
        .from('live_locations')
        .stream(primaryKey: ['resident_id']).listen(
      (List<Map<String, dynamic>> data) async {
        if (kDebugMode)
          print("Live location data received (subscription): $data");

        if (data.isEmpty) {
          if (kDebugMode)
            print("No live location updates received yet (subscription).");
        }

        for (var location in data) {
          final residentId = location['resident_id'];
          final isSharing = location['is_sharing'] == true;

          if (residentId == null) {
            if (kDebugMode) print("Resident ID is null in live_locations data");
            continue;
          }

          if (kDebugMode) {
            print("Processing residentId: $residentId, isSharing: $isSharing");
          }

          try {
            if (isSharing) {
              final serviceCall = await Supabase.instance.client
                  .from('service_calls')
                  .select()
                  .eq('resident_id', residentId)
                  .eq('service_type', organizationType!.toLowerCase())
                  .eq('shared_location', true)
                  .limit(1)
                  .maybeSingle();

              if (kDebugMode) {
                print("Service call for residentId $residentId: $serviceCall");
              }

              if (serviceCall != null) {
                await _handleNewCall(location, serviceCall);
              } else {
                if (kDebugMode) {
                  print(
                      "No matching service_call found for resident_id $residentId with organization type $organizationType");
                }
                setState(() {
                  _residentCalls
                      .removeWhere((call) => call.residentId == residentId);
                });
                await _updateResidentMarkers();
              }
            } else {
              if (kDebugMode) {
                print(
                    "is_sharing is false for residentId $residentId, removing from resident calls");
              }
              setState(() {
                _residentCalls
                    .removeWhere((call) => call.residentId == residentId);
              });
              await _updateResidentMarkers();
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                  "Error processing live location for resident $residentId: $e");
            }
            if (mounted) {
              _showErrorSnackBar(
                  component: 'live location for resident $residentId');
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print("Error in live locations subscription: $error");
        if (mounted) {
          _showErrorSnackBar(component: 'live location updates (subscription)');
        }
      },
    );
  }

  Future<void> _handleNewCall(Map<String, dynamic> locationData,
      Map<String, dynamic> serviceCall) async {
    try {
      final residentId = locationData['resident_id'] as int?;
      if (residentId == null) {
        if (kDebugMode) print("Resident ID is null in locationData");
        return;
      }

      final residentResponse = await Supabase.instance.client
          .from('residents')
          .select(
              'id, first_name, last_name, middle_name, suffix_name, username, address, birth_date, status, gender, personal_email, phone, valid_id, face_recognition_image_url, profile_image, location_id')
          .eq('id', residentId)
          .single();

      if (kDebugMode) {
        print("Resident data for ID $residentId: $residentResponse");
      }

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

      if (kDebugMode) {
        print("Location data for locationId $locationId: $locationResponse");
      }

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
          locationData['longitude'] ?? 0.0,
          locationData['latitude'] ?? 0.0,
        ),
      );

      setState(() {
        final index = _residentCalls
            .indexWhere((call) => call.residentId == newCall.residentId);
        if (index == -1) {
          _residentCalls.add(newCall);
          if (kDebugMode) {
            print("Added new call for residentId: $residentId");
            print("Total resident calls: ${_residentCalls.length}");
          }
          // Notify the worker of the new call
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("New emergency call from ${newCall.fullName}")),
          );
        } else {
          _residentCalls[index] = newCall;
          if (kDebugMode) {
            print("Updated existing call for residentId: $residentId");
            print("Total resident calls: ${_residentCalls.length}");
          }
        }
      });

      if (kDebugMode) {
        print("Current resident calls: ${_residentCalls.length}");
        for (var call in _residentCalls) {
          print(
              "ResidentCall: ${call.residentId}, Name: ${call.fullName}, Location: ${call.location}");
        }
      }

      await _updateResidentMarkers();
    } catch (e) {
      if (kDebugMode) {
        print("Error in _handleNewCall: $e");
      }
      if (mounted) {
        _showErrorSnackBar(component: 'new call for resident');
      }
    }
  }

  Future<void> _updateResidentMarkers() async {
    if (_mapController == null || _pointAnnotationManager == null) {
      if (kDebugMode)
        print("Map controller or point annotation manager is not ready.");
      return;
    }

    try {
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
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(component: 'resident markers');
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
        _showErrorSnackBar(component: 'call completion');
      }
    }
  }

  Future<Uint8List?> _getImageData(
      String imageUrl, BuildContext context) async {
    const double circleSize = 200.0;
    const double tailHeight = 40.0;
    const double tailWidth = 70.0;
    const double overlap = 20.0;
    final double overallHeight = circleSize + tailHeight - overlap;

    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, circleSize, overallHeight));

    final circleCenter = Offset(circleSize / 2, circleSize / 2);
    final circleRadius = circleSize / 2 - 10;

    final shadowColor = Colors.black.withOpacity(0.7);
    const shadowBlurRadius = 8.0;

    final tailPath = ui.Path();
    final tailTopY = circleSize - overlap;
    tailPath.moveTo((circleSize - tailWidth) / 2, tailTopY);
    tailPath.lineTo((circleSize + tailWidth) / 2, tailTopY);
    tailPath.lineTo(circleSize / 2, tailTopY + tailHeight + 20 - overlap);
    tailPath.close();

    canvas.drawShadow(tailPath, shadowColor, shadowBlurRadius, false);

    final tailPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(tailPath, tailPaint);

    final tailBorderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawPath(tailPath, tailBorderPaint);

    final circlePath = ui.Path()
      ..addOval(Rect.fromCircle(center: circleCenter, radius: circleRadius));

    canvas.drawShadow(circlePath, shadowColor, shadowBlurRadius, false);

    final borderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 15.0;
    canvas.drawCircle(circleCenter, circleRadius, borderPaint);

    final clipPath = ui.Path()
      ..addOval(
          Rect.fromCircle(center: circleCenter, radius: circleRadius - 10));
    canvas.save();
    canvas.clipPath(clipPath);

    try {
      if (imageUrl.isNotEmpty) {
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
          throw Exception('Failed to load image');
        }
      } else {
        final defaultImage = await DefaultAssetBundle.of(context)
            .load('assets/icons/person.png');
        final codec =
            await ui.instantiateImageCodec(defaultImage.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final image = frame.image;
        const double padding = 20.0;
        final dstRect = ui.Rect.fromLTWH(padding, padding,
            circleSize - 2 * padding, circleSize - 2 * padding);
        final srcRect = ui.Rect.fromLTWH(
            0, 0, image.width.toDouble(), image.height.toDouble());
        canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
        image.dispose();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading image: $e');
      if (mounted) {
        _showErrorSnackBar(component: 'profile image');
      }
      return null;
    } finally {
      canvas.restore();
    }

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
      try {
        _mapController!.flyTo(
          mp.CameraOptions(
            center: mp.Point(coordinates: location),
            zoom: 14,
            padding: padding,
          ),
          mp.MapAnimationOptions(duration: 1000),
        );
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(component: 'map animation');
        }
      }
    }
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    _mapController = controller;
    try {
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
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(component: 'map initialization');
      }
    }
  }

  void _showResidentDetails(ResidentCall call) {
    try {
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
            height: MediaQuery.of(context).size.height * 0.70,
            color: const ui.Color.fromARGB(255, 243, 239, 239),
            child: AnimatedBottomSheetContent(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
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
                                        child:
                                            Text("No Face Recognition Image")),
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
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(component: 'resident details');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Construct the worker's full name
    final workerName = (firstName != null) ? '$firstName' : 'Worker';
    return WillPopScope(
      onWillPop: () async {
        bool? exit = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            contentPadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Text(
                'Exit App',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: const Text(
                'Are you sure you want to close the app?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Exit',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.only(bottom: 16),
          ),
        );
        if (exit == true) {
          SystemNavigator.pop();
          return true;
        }
        return false;
      },
      child: Scaffold(
        body: SlidingUpPanel(
          controller: _panelController,
          minHeight: _residentCalls.isEmpty ? 150 : 240,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          panelBuilder: (ScrollController sc) {
            return Container(
              decoration: BoxDecoration(
                color: const ui.Color.fromARGB(255, 237, 232, 232),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: sc,
                      itemCount: _residentCalls.length,
                      itemBuilder: (context, index) {
                        if (kDebugMode) {
                          print(
                              "Building ResidentCallCard for index $index, total: ${_residentCalls.length}");
                        }
                        final call = _residentCalls[index];
                        return ResidentCallCard(
                          call: call,
                          onDone: () =>
                              _markCallAsCompleted(call.id, call.residentId),
                          onLocate: () => _animateToCallLocation(call.location),
                          onShowDetails: () => _showResidentDetails(call),
                          onRoute: () {
                            try {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (ctx, anim, secAnim) =>
                                      RoutingMapPage(
                                    residentPosition: call.location,
                                    residentImageUrl: call.profileImage,
                                  ),
                                  transitionsBuilder:
                                      (ctx, anim, secAnim, child) {
                                    final tween = Tween(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero)
                                        .chain(
                                            CurveTween(curve: Curves.easeOut));
                                    return SlideTransition(
                                      position: anim.drive(tween),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            } catch (e) {
                              if (mounted) {
                                _showErrorSnackBar(component: 'routing page');
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          body: Stack(
            children: [
              mp.MapWidget(
                key: const ValueKey("workerMapWidget"),
                styleUri: "mapbox://styles/mapbox/streets-v12",
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
              // Menu button (top-left)
              Positioned(
                top: 50,
                left: 16,
                child: FloatingActionButton(
                  mini: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  heroTag: "menuButton",
                  onPressed: () {
                    try {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (ctx, anim, secAnim) => MenuPage(
                            workerName: workerName,
                            workerId: workerId, // Pass workerId
                          ),
                          transitionsBuilder: (ctx, anim, secAnim, child) {
                            final tween = Tween(
                              begin: const Offset(0, 1), // From bottom
                              end: Offset.zero, // To top
                            ).chain(CurveTween(curve: Curves.easeOut));
                            return SlideTransition(
                              position: anim.drive(tween),
                              child: child,
                            );
                          },
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        _showErrorSnackBar(component: 'menu page');
                      }
                    }
                  },
                  backgroundColor: Colors.redAccent,
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              // // Video reels button (top-right)
              // Positioned(
              //   top: 50,
              //   right: 16,
              //   child: FloatingActionButton(
              //     heroTag: "videoReelsButton",
              //     onPressed: () {
              //       try {
              //         Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (context) =>
              //                 VideoReelsPage(workerId: workerId),
              //           ),
              //         );
              //       } catch (e) {
              //         if (mounted) {
              //           _showErrorSnackBar(component: 'video reels page');
              //         }
              //       }
              //     },
              //     mini: true,
              //     backgroundColor: Colors.white,
              //     child: const Icon(
              //       Icons.video_call,
              //       color: Colors.black,
              //     ),
              //   ),
              // ),
              // Recenter button (bottom-right)
              Positioned(
                bottom: _residentCalls.isEmpty ? 200 : 270,
                right: 16,
                child: SizedBox(
                  height: 70,
                  width: 70,
                  child: FloatingActionButton(
                    elevation: 8,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(54)),
                    heroTag: "recenterButton",
                    onPressed: _recenterToWorker,
                    mini: true,
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),
              ),
              // Refresh button (bottom-right, above recenter)
              Positioned(
                bottom: _residentCalls.isEmpty ? 280 : 350,
                right: 16,
                child: SizedBox(
                  height: 70,
                  width: 70,
                  child: FloatingActionButton(
                    elevation: 8,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(54)),
                    heroTag: "refreshButton",
                    onPressed: _fetchLiveLocations,
                    mini: true,
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (kDebugMode) {
          print('Could not launch $phoneUri');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error making phone call: $e');
      }
    }
  }

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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(36),
            bottomLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
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
                            child: const Text('Done',
                                style: TextStyle(fontSize: 12)),
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
                            child: const Text('Location',
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: call.phone.isNotEmpty
                    ? () => _makePhoneCall(call.phone)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      call.phone.isNotEmpty
                          ? 'Call ${call.phone}'
                          : 'No Phone Number',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
