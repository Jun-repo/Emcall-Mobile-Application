// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:emcall/components/maps/navigation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;

class RouteInfoPage extends StatefulWidget {
  final String startLocation;
  final String endLocation;
  final mb.Position endPosition;
  final String initialProfile;

  const RouteInfoPage({
    Key? key,
    required this.startLocation,
    required this.endLocation,
    required this.endPosition,
    required this.initialProfile,
  }) : super(key: key);

  @override
  _RouteInfoPageState createState() => _RouteInfoPageState();
}

class _RouteInfoPageState extends State<RouteInfoPage>
    with SingleTickerProviderStateMixin {
  mb.MapboxMap? mapboxMap;
  mb.PolylineAnnotationManager? polylineAnnotationManager;
  mb.PointAnnotationManager? pointAnnotationManager;
  Uint8List? endMarkerImage;
  AnimationController? _bounceController;

  bool _isLoading = true;

  // Route data
  double? distance;
  double? duration;
  String selectedProfile = 'driving-car';
  List<mb.Position> routeCoordinates = [];
  final Map<String, IconData> routeProfiles = {
    'driving-car': Icons.local_taxi_rounded,
    'cycling-regular': Icons.pedal_bike_rounded,
    'foot-walking': Icons.directions_walk_rounded,
  };
  final Map<String, Color> routeColors = {
    'driving-car': const Color.fromARGB(255, 40, 119, 255),
    'cycling-regular': const Color.fromARGB(255, 8, 211, 15),
    'foot-walking': const Color.fromARGB(255, 255, 60, 0),
  };
  String viaText = 'Via Unknown Route';
  String userLocationName = 'Your Location'; // Dynamic user location name
  String routeDescription =
      'Best route, Typical traffic'; // Dynamic route description

  @override
  void initState() {
    super.initState();
    selectedProfile = widget.initialProfile;
    _loadMarkerImage();
    _fetchRoute();
  }

  Future<void> _loadMarkerImage() async {
    final ByteData endData =
        await rootBundle.load('assets/icons/location_puck.png');
    endMarkerImage = endData.buffer.asUint8List();
    if (mounted) setState(() {});
  }

  Future<void> _fetchRoute() async {
    try {
      final position = await _determinePosition();
      final start = mb.Position(position.longitude, position.latitude);

      // Perform reverse geocoding for user location
      await _reverseGeocode(start);

      final end = widget.endPosition;

      final apiKey = dotenv.env['ORS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('ORS API key is missing. Please check your .env file.');
      }

      final url =
          'https://api.openrouteservice.org/v2/directions/$selectedProfile'
          '?api_key=$apiKey'
          '&start=${start.lng},${start.lat}'
          '&end=${end.lng},${end.lat}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!data.containsKey('features') || data['features'].isEmpty) {
          throw Exception('No route data returned from API.');
        }
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        final properties = data['features'][0]['properties'];
        final summary = properties['summary'];

        String dynamicViaText = 'Unknown Route';
        String dynamicRouteDescription = 'Best route, Typical traffic';
        if (properties.containsKey('segments')) {
          final segments = properties['segments'] as List<dynamic>;
          for (var segment in segments) {
            if (segment.containsKey('steps')) {
              final steps = segment['steps'] as List<dynamic>;
              for (var step in steps) {
                if (step.containsKey('name') && step['name'] != '-') {
                  dynamicViaText = step['name'];
                  break;
                }
              }
            }
            // Derive route description based on duration and distance
            if (summary.containsKey('duration') &&
                summary.containsKey('distance')) {
              final double speed = (summary['distance'] / 1000) /
                  (summary['duration'] / 3600); // km/h
              if (selectedProfile == 'driving-car') {
                if (speed > 60) {
                  dynamicRouteDescription = 'Fastest route, Light traffic';
                } else if (speed > 30) {
                  dynamicRouteDescription = 'Best route, Moderate traffic';
                } else {
                  dynamicRouteDescription = 'Shortest route, Heavy traffic';
                }
              } else if (selectedProfile == 'cycling-regular') {
                dynamicRouteDescription =
                    speed > 15 ? 'Fast cycling route' : 'Scenic cycling route';
              } else if (selectedProfile == 'foot-walking') {
                dynamicRouteDescription = speed > 5
                    ? 'Quick walking route'
                    : 'Leisurely walking route';
              }
            }
            if (dynamicViaText != 'Unknown Route') break;
          }
        }

        setState(() {
          routeCoordinates =
              coords.map<mb.Position>((c) => mb.Position(c[0], c[1])).toList();
          distance = summary['distance'];
          duration = summary['duration'];
          viaText = 'Via $dynamicViaText';
          routeDescription = dynamicRouteDescription;
          _isLoading = false;
        });

        await _initializeMap();
      } else {
        throw Exception('Failed to load!');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully load!',
            style: const TextStyle(color: Colors.green),
          ),
        ),
      );
    }
  }

  Future<void> _reverseGeocode(mb.Position position) async {
    final apiKey = dotenv.env['ORS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return;

    final url = Uri.parse(
        'https://api.openrouteservice.org/geocode/reverse?api_key=$apiKey&point.lon=${position.lng}&point.lat=${position.lat}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          setState(() {
            final properties = features[0]['properties'];
            userLocationName = properties['label'] ?? 'Your Location';
          });
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
  }

  Future<gl.Position> _determinePosition() async {
    final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    var permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await gl.Geolocator.getCurrentPosition(
      desiredAccuracy: gl.LocationAccuracy.high,
    );
  }

  Future<void> _initializeMap() async {
    if (mapboxMap == null || routeCoordinates.isEmpty) return;

    // Enable location puck for start position
    await mapboxMap?.location.updateSettings(
      mb.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: false,
        pulsingEnabled: true,
        pulsingColor: Colors.blue.value,
        pulsingMaxRadius: 50.0,
        puckBearing: mb.PuckBearing.COURSE,
      ),
    );

    if (mapboxMap == null || routeCoordinates.isEmpty) return;

    // 1) Remove old route_layer/source if they’re there
    if (await mapboxMap!.style.styleLayerExists("route_layer")) {
      await mapboxMap!.style.removeStyleLayer("route_layer");
    }
    if (await mapboxMap!.style.styleSourceExists("route_source")) {
      await mapboxMap!.style.removeStyleSource("route_source");
    }

    // 2) Add fresh source + layer
    await mapboxMap!.style.addSource(
      mb.GeoJsonSource(id: "route_source", lineMetrics: true),
    );
    await mapboxMap!.style.addLayer(
      mb.LineLayer(
        id: "route_layer",
        sourceId: "route_source",
        lineColor: routeColors[selectedProfile]!.value,
        lineWidth: 8.0,
        lineOpacity: 0.8,
        lineBorderColor: Colors.black.value,
        lineBorderWidth: 1.0,
        lineCap: mb.LineCap.ROUND,
        lineJoin: mb.LineJoin.ROUND,
      ),
    );
    // Initialize point annotations for the end marker
    pointAnnotationManager =
        await mapboxMap!.annotations.createPointAnnotationManager();

    _updateRoutePolyline();
    await _addEndMarker(); // Add static marker
    _fitMapToRoute();
  }

  void _updateRouteProfile(String profile) {
    setState(() {
      selectedProfile = profile;
      _isLoading = true; // Show loading when switching profiles
    });
    _fetchRoute(); // Re-fetch route with new profile
    _updateRouteColor(); // Update polyline color
  }

  void _updateRoutePolyline() async {
    final source = await mapboxMap?.style.getSource("route_source");
    if (routeCoordinates.isEmpty) {
      if (source is mb.GeoJsonSource) {
        source.updateGeoJSON(
            json.encode({"type": "FeatureCollection", "features": []}));
      }
      return;
    }
    final line = mb.LineString(coordinates: routeCoordinates);
    if (source is mb.GeoJsonSource) source.updateGeoJSON(json.encode(line));
  }

  Future<void> _updateRouteColor() async {
    if (mapboxMap == null) return;

    final exists = await mapboxMap!.style.styleLayerExists("route_layer");
    if (!exists) return;

    await mapboxMap!.style.setStyleLayerProperty(
      "route_layer",
      "line-color",
      _colorToHex(routeColors[selectedProfile]!),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Future<void> _addEndMarker() async {
    if (endMarkerImage == null || routeCoordinates.isEmpty) return;

    // Clear existing markers to prevent duplicates
    await pointAnnotationManager?.deleteAll();

    await pointAnnotationManager?.create(
      mb.PointAnnotationOptions(
        geometry: mb.Point(coordinates: routeCoordinates.last),
        image: endMarkerImage,
        iconSize: 0.5, // Reduced size for smaller marker
        iconOffset: [0, -15],
      ),
    );
  }

  Future<void> _fitMapToRoute() async {
    if (routeCoordinates.isEmpty || mapboxMap == null) return;

    final coordinates =
        routeCoordinates.map((pos) => mb.Point(coordinates: pos)).toList();

    // Measure bottom sheet height
    const double bottomSheetHeight = 320; // Approximate height of bottom sheet
    const double headerHeight = 56; // Approximate height of header
    final paddingBottom =
        bottomSheetHeight + headerHeight + 50; // Extra padding for visibility

    final camera = await mapboxMap!.cameraForCoordinates(
      coordinates,
      mb.MbxEdgeInsets(
        top: headerHeight + 50.0,
        left: 50.0,
        bottom: paddingBottom,
        right: 50.0,
      ),
      null,
      0.0,
    );

    mapboxMap!.flyTo(
      mb.CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        pitch: 0.0,
        bearing: 0.0,
      ),
      mb.MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }

  /// Truncates text to a maximum length with ellipsis if needed.
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  @override
  void dispose() {
    _bounceController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Full-screen Map
            mb.MapWidget(
              key: const ValueKey("routeMapWidget"),
              styleUri: "mapbox://styles/mapbox/navigation-day-v1",
              onMapCreated: (mb.MapboxMap controller) {
                mapboxMap = controller;
                if (!_isLoading && routeCoordinates.isNotEmpty) {
                  _initializeMap();
                }
              },
            ),

            // Header with back icon and location info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        '${_truncateText(userLocationName, 15)} → ${_truncateText(widget.endLocation, 15)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 20), // Spacer for symmetry
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: Center(
                  child: SizedBox(
                    width: 45.0, // Set loading indicator size
                    height: 45.0,
                    child: CircularProgressIndicator(
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      strokeWidth: 6.0,
                      strokeCap: StrokeCap.round,
                      semanticsLabel: 'Loading route',
                      semanticsValue: 'In progress',
                      value: null, // Indeterminate progress
                    ),
                  ),
                ),
              ),

            // Non-dismissible Bottom Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Duration and Distance Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                duration != null
                                    ? '${(duration! / 3600).toStringAsFixed(0)}h ${(duration! / 60 % 60).toStringAsFixed(0)}m'
                                    : 'N/A',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                routeDescription,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            distance != null
                                ? '${(distance! / 1000).toStringAsFixed(0)} km'
                                : 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Route Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                viaText,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: ToggleButtons(
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: Colors.redAccent,
                          borderColor: Colors.grey,
                          selectedBorderColor: Colors.redAccent,
                          constraints: const BoxConstraints(
                            minHeight: 55.0,
                            minWidth: 100.0,
                          ),
                          isSelected: routeProfiles.keys
                              .map((key) => key == selectedProfile)
                              .toList(),
                          onPressed: (index) {
                            final profile = routeProfiles.keys.elementAt(index);
                            _updateRouteProfile(profile);
                          },
                          children: routeProfiles.entries
                              .map((entry) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(entry.value),
                                        const SizedBox(width: 4),
                                        Text(
                                          entry.key.split('-')[0].capitalize(),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 38),
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 209, 209, 209),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 16),
                                child: Text(
                                  "Leave Later",
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation,
                                            secondaryAnimation) =>
                                        NavigationPage(
                                      startLocation: userLocationName,
                                      endLocation: widget.endLocation,
                                      endPosition: widget.endPosition,
                                      routeCoordinates: routeCoordinates,
                                      routeDistance: distance ?? 0.0,
                                      routeDuration: duration ?? 0.0,
                                      selectedProfile: selectedProfile,
                                    ),
                                    transitionsBuilder: (context, animation,
                                        secondaryAnimation, child) {
                                      const begin =
                                          Offset(1.0, 0.0); // Slide from right
                                      const end = Offset.zero;
                                      const curve = Curves.easeInOut;

                                      var tween = Tween(begin: begin, end: end)
                                          .chain(CurveTween(curve: curve));
                                      var offsetAnimation =
                                          animation.drive(tween);

                                      return SlideTransition(
                                        position: offsetAnimation,
                                        child: child,
                                      );
                                    },
                                    transitionDuration:
                                        const Duration(milliseconds: 700),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 16),
                                child: Text(
                                  "Go Now",
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
