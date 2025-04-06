// ignore_for_file: use_build_context_synchronously, unused_element

import 'dart:async';
import 'dart:convert';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class FullMap extends StatefulWidget {
  const FullMap({super.key});

  @override
  State<FullMap> createState() => _FullMapState();
}

class _FullMapState extends State<FullMap> with TickerProviderStateMixin {
  mp.MapboxMap? mapboxMap;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.PolylineAnnotationManager? polylineAnnotationManager;
  Uint8List? hqMarkerImage;
  StreamSubscription<gl.Position>? usersPositionStream;

  mp.Position? userPosition;
  mp.Position? destinationPosition;
  bool _isCameraCentered = false;
  List<mp.Position> routeCoordinates = [];
  bool hasDestination = false;
  bool isFollowingUser = false;
  bool showRoutePanel = false;
  bool _hasAnimatedRoute = false;
  bool _routeConfirmed = false;
  bool isNavigationActive = false;

  double? userBearing;
  Uint8List? userLocationImage;
  bool isPitchEnabled = false;
  bool _isNavigationPuckActive = false;

  // Route metrics
  String startLocationName = 'Your Location';
  String endLocationName = 'Destination';
  double? routeDistance;
  double? routeDuration;
  double? averageSpeed;

  // Route configuration
  String selectedProfile = 'driving-car';
  final Map<String, IconData> routeProfiles = {
    'driving-car': Icons.local_taxi,
    'cycling-regular': Icons.pedal_bike,
    'foot-walking': Icons.hiking,
  };

  final Map<String, Color> routeColors = {
    'driving-car': Colors.indigo,
    'cycling-regular': Colors.teal,
    'foot-walking': Colors.deepOrange,
  };

  // API configuration
  static const String orsBaseUrl =
      'https://api.openrouteservice.org/v2/directions';
  static const String orsApiKey =
      '5b3ce3597851110001cf6248f55d7a31499e40848c6848d7de8fa624';

  AnimationController? controller;
  Animation<double>? animation;
  AnimationController? _bounceController;
  Animation<double>? _bounceAnimation;
  AnimationController? _bubbleScaleController;
  Animation<double>? _bubbleScaleAnimation;

  bool showRouteProfiles = true;
  bool showNavigationInfoPanel = false;
  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();

    // Initialize vertical bounce animation controller (for up/down movement)
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _bounceController!, curve: Curves.easeInOut),
    );

    // Initialize bubble scale animation controller (for bouncing in/out effect)
    _bubbleScaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bubbleScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bubbleScaleController!,
        curve: Curves.fastEaseInToSlowEaseOut,
      ),
    );
  }

  @override
  void dispose() {
    _bounceController?.dispose();
    _bubbleScaleController?.dispose();
    usersPositionStream?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          mp.MapWidget(
            key: const ValueKey("mapWidget"),
            styleUri: "mapbox://styles/buddyapp01/cm8qqmuxt00eo01sr3zd0apes",
            onMapCreated: _onMapCreated,
            onLongTapListener: (event) => _handleLongTap(event.point),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            },
          ),
          if (_showBubble && destinationPosition != null)
            _buildBouncingMarkerWithBubble(),
          Positioned(
            top: isNavigationActive ? 300 : 40,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: hasDestination ? null : _toggleFollowUser,
                  backgroundColor: Colors.white,
                  child: Icon(
                    isFollowingUser
                        ? Icons.navigation
                        : Icons.navigation_outlined,
                    color: hasDestination ? Colors.grey : Colors.red,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  mini: true,
                  onPressed: _togglePitch,
                  backgroundColor: Colors.white,
                  child: Icon(
                    isPitchEnabled ? Icons.architecture : Icons.terrain,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        onPressed: _zoomIn,
                        backgroundColor: Colors.white.withOpacity(0.0),
                        child: const Icon(Icons.add_rounded, color: Colors.red),
                      ),
                      FloatingActionButton(
                        mini: true,
                        onPressed: _zoomOut,
                        backgroundColor: Colors.white.withOpacity(0.0),
                        child:
                            const Icon(Icons.remove_rounded, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showRoutePanel) _buildInfoPanel(),
          if (showNavigationInfoPanel) _buildNavigationInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildBouncingMarkerWithBubble() {
    return FutureBuilder<mp.ScreenCoordinate>(
      future: mapboxMap?.pixelForCoordinate(
        mp.Point(coordinates: destinationPosition!),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final screenPos = snapshot.data!;
        return Positioned(
          left: screenPos.x - 90, // Adjusted for larger container with buttons
          top: screenPos.y - 110, // Adjusted for larger container
          child: AnimatedBuilder(
            animation: _bounceAnimation!,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -_bounceAnimation!.value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _bubbleScaleAnimation!,
                      child: Container(
                        padding: const EdgeInsets.all(
                            16), // Adjusted padding for larger content
                        margin: const EdgeInsets.only(bottom: 35),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Destination",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                                height: 12), // Space between text and buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _cancelRoute,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors
                                        .grey[300], // Light grey background
                                    foregroundColor:
                                        Colors.grey[800], // Dark grey text/icon
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side:
                                          const BorderSide(color: Colors.grey),
                                    ),
                                  ),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(
                                    width: 10), // Space between buttons
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _routeConfirmed = true;
                                      _showBubble = false;
                                    });
                                    _getRouteCoordinates();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.red[400], // Red background
                                    foregroundColor:
                                        Colors.white, // White text/icon
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                  child: const Text(
                                    "Routes",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      child: CustomPaint(
                        size: const Size(30, 45),
                        painter: BubbleTailPainter(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLocationRow(Icons.my_location, startLocationName),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.flag, endLocationName),
            if (routeDistance != null) ...[
              const Divider(),
              _buildMetricRow('Distance',
                  '${(routeDistance! / 1000).toStringAsFixed(1)} km'),
              _buildMetricRow('Duration',
                  '${(routeDuration! / 60).toStringAsFixed(0)} mins'),
              _buildMetricRow(
                  'Speed', '${averageSpeed?.toStringAsFixed(1) ?? '--'} km/h'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                            color: Colors.redAccent, width: 1.0),
                      ),
                    ),
                    child: const Text(
                      'Navigation',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cancelRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    mapboxMap = controller;
    await _initializeMap(controller);
    controller.addListener(handleMapInteraction);
  }

  void handleMapInteraction() {
    if (isFollowingUser) {
      setState(() => isFollowingUser = false);
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

    hqMarkerImage ??= await _loadHQMarkerImage();

    pointAnnotationManager =
        await controller.annotations.createPointAnnotationManager();
    polylineAnnotationManager =
        await controller.annotations.createPolylineAnnotationManager();

    await controller.style.addSource(
      mp.GeoJsonSource(id: "source", lineMetrics: true),
    );

    await controller.style.addLayer(
      mp.LineLayer(
        id: "layer",
        sourceId: "source",
        lineColor: routeColors[selectedProfile]!.value,
        lineWidth: 10.0,
        lineOpacity: 0.9,
        lineBorderColor: routeColors[selectedProfile]!.value,
        lineBorderWidth: 2,
        lineCap: mp.LineCap.ROUND,
        lineJoin: mp.LineJoin.ROUND,
        lineTrimOffset: [0.0, 1.0],
      ),
    );

    controller.flyTo(
      mp.CameraOptions(zoom: 10, pitch: 0, bearing: 0),
      mp.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  void _handleLongTap(mp.Point point) async {
    if (hqMarkerImage == null) return;

    setState(() {
      destinationPosition = point.coordinates;
      hasDestination = true;
      isFollowingUser = false;
      endLocationName = 'Destination';
      _routeConfirmed = true;
      _showBubble = true;
    });

    // Reset and start the bubble scale animation
    _bubbleScaleController?.reset();
    _bubbleScaleController?.forward();

    pointAnnotationManager?.deleteAll();
    pointAnnotationManager?.create(
      mp.PointAnnotationOptions(
        image: hqMarkerImage,
        iconSize: 0.2,
        geometry: point,
      ),
    );

    await _getRouteCoordinates();
  }

  Future<bool> _getRouteCoordinates({bool useDialogError = false}) async {
    if (!(hasDestination && _routeConfirmed) ||
        userPosition == null ||
        destinationPosition == null) {
      return false;
    }

    final start = "${userPosition!.lng},${userPosition!.lat}";
    final end = "${destinationPosition!.lng},${destinationPosition!.lat}";

    try {
      final response = await http.get(
        Uri.parse('$orsBaseUrl/$selectedProfile?start=$start&end=$end'),
        headers: {
          'Authorization': 'Bearer $orsApiKey',
          'Accept': 'application/json, application/geo+json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feature = data['features'][0];
        final coordinates = feature['geometry']['coordinates'];
        final properties = feature['properties'];
        final summary = properties['summary'];

        setState(() {
          routeCoordinates = coordinates.map<mp.Position>((coord) {
            return mp.Position(
              (coord[0] as num).toDouble(),
              (coord[1] as num).toDouble(),
            );
          }).toList();
          routeDistance = summary['distance'];
          routeDuration = summary['duration'];
          averageSpeed = (routeDistance! / routeDuration!) * 3.6;
          showRoutePanel = true;
        });

        _reverseGeocode(userPosition!, true);
        _reverseGeocode(destinationPosition!, false);
        _updateRoutePolyline();
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Route calculation error: $e');
      }
    }
    return false;
  }

  void _updateRoutePolyline() async {
    final source = await mapboxMap?.style.getSource("source");
    if (routeCoordinates.isEmpty) {
      if (source is mp.GeoJsonSource) {
        source.updateGeoJSON(json.encode({
          "type": "FeatureCollection",
          "features": [],
        }));
      }
      return;
    }
    final line = mp.LineString(coordinates: routeCoordinates);
    if (source is mp.GeoJsonSource) {
      source.updateGeoJSON(json.encode(line));
    }

    if (!_hasAnimatedRoute) {
      controller?.stop();
      controller?.dispose();
      controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );
      animation = Tween<double>(begin: 0, end: 1.0).animate(controller!)
        ..addListener(() {
          mapboxMap?.style.setStyleLayerProperty(
              "layer", "line-trim-offset", [animation?.value, 1.0]);
        });
      controller?.forward().whenComplete(() {
        _hasAnimatedRoute = true;
      });
    } else {
      mapboxMap?.style
          .setStyleLayerProperty("layer", "line-trim-offset", [1.0, 1.0]);
    }
  }

  void _updateRouteProfile(String profile) async {
    setState(() {
      selectedProfile = profile;
      _hasAnimatedRoute = false;
    });

    final layerExists =
        await mapboxMap?.style.styleLayerExists("layer") ?? false;
    if (layerExists) {
      final colorHex =
          '#${routeColors[selectedProfile]!.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      mapboxMap?.style.setStyleLayerProperty("layer", "line-color", colorHex);
      mapboxMap?.style
          .setStyleLayerProperty("layer", "line-border-color", colorHex);
    }

    if (hasDestination) {
      setState(() {
        _routeConfirmed = true;
      });
      await _getRouteCoordinates();
    }
  }

  void _toggleFollowUser() {
    if (hasDestination) return;
    setState(() => isFollowingUser = !isFollowingUser);
    if (isFollowingUser && userPosition != null) {
      _activeCameraOnUser(bearing: userBearing);
      mapboxMap?.easeTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: userPosition!),
          bearing: userBearing,
          zoom: 17.5,
        ),
        mp.MapAnimationOptions(duration: 2000, startDelay: 0),
      );
    }
  }

  void _activeCameraOnUser({double? bearing, bool useBottomCenter = false}) {
    if (userPosition == null) return;
    if (_isNavigationPuckActive) {
      _changeLocationPuckToNavigation();
    }
    final anchor = useBottomCenter
        ? mp.ScreenCoordinate(
            x: MediaQuery.of(context).size.width / 2,
            y: MediaQuery.of(context).size.height * 0.9,
          )
        : mp.ScreenCoordinate(x: 1, y: 1);
    mapboxMap?.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: userPosition!),
        bearing: bearing,
        pitch: isPitchEnabled ? 50.0 : 0.0,
        padding: mp.MbxEdgeInsets(top: 400, left: 2, bottom: 4, right: 2),
        anchor: anchor,
        zoom: 17.5,
      ),
      mp.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  void _centerCameraOnUser({double? bearing, bool useBottomCenter = false}) {
    if (userPosition == null) return;
    final anchor = useBottomCenter
        ? mp.ScreenCoordinate(
            x: MediaQuery.of(context).size.width / 2,
            y: MediaQuery.of(context).size.height * 0.9,
          )
        : mp.ScreenCoordinate(x: 1, y: 1);
    mapboxMap?.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: userPosition!),
        bearing: bearing,
        pitch: isPitchEnabled ? 75.0 : 0.0,
        padding: mp.MbxEdgeInsets(top: 4, left: 2, bottom: 4, right: 2),
        anchor: anchor,
        zoom: 18,
      ),
      mp.MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) await gl.Geolocator.openLocationSettings();

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) return;
    }

    if (permission != gl.LocationPermission.deniedForever) {
      _startLocationTracking();
    }
  }

  void _startLocationTracking() {
    const locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    usersPositionStream =
        gl.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((gl.Position position) {
      final newPosition = mp.Position(position.longitude, position.latitude);
      double routeBearing = _calculateRouteBearing(newPosition);

      setState(() {
        userPosition = newPosition;
        userBearing = routeBearing;
      });

      if (!_isCameraCentered && userPosition != null) {
        _centerCameraOnUser(bearing: routeBearing);
        _isCameraCentered = true;
      }

      if (isFollowingUser && !hasDestination) {
        _centerCameraOnUser(bearing: routeBearing);
      }

      if (hasDestination && _routeConfirmed) {
        _getRouteCoordinates();
      }
      if (isNavigationActive && routeCoordinates.isNotEmpty) {
        _updateUpcomingRoute();
        _activeCameraOnUser(
            bearing: _calculateRouteBearing(userPosition!),
            useBottomCenter: true);
      }
      _reverseGeocode(newPosition, true);
    });
  }

  void _updateUpcomingRoute() async {
    if (userPosition == null || routeCoordinates.isEmpty) return;
    int nearestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < routeCoordinates.length; i++) {
      final d = gl.Geolocator.distanceBetween(
        userPosition!.lat.toDouble(),
        userPosition!.lng.toDouble(),
        routeCoordinates[i].lat.toDouble(),
        routeCoordinates[i].lng.toDouble(),
      );
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }
    final upcomingRoute = routeCoordinates.sublist(nearestIndex);
    final source = await mapboxMap?.style.getSource("source");
    if (source is mp.GeoJsonSource) {
      final line = mp.LineString(coordinates: upcomingRoute);
      source.updateGeoJSON(json.encode(line));
    }
  }

  double _calculateRouteBearing(mp.Position currentPos) {
    if (routeCoordinates.length < 2) return 0;
    int nearestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < routeCoordinates.length; i++) {
      final d = gl.Geolocator.distanceBetween(
        currentPos.lat.toDouble(),
        currentPos.lng.toDouble(),
        routeCoordinates[i].lat.toDouble(),
        routeCoordinates[i].lng.toDouble(),
      );
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }
    final nextIndex = (nearestIndex + 1 < routeCoordinates.length)
        ? nearestIndex + 1
        : nearestIndex;
    return gl.Geolocator.bearingBetween(
      currentPos.lat.toDouble(),
      currentPos.lng.toDouble(),
      routeCoordinates[nextIndex].lat.toDouble(),
      routeCoordinates[nextIndex].lng.toDouble(),
    );
  }

  void _togglePitch() {
    setState(() => isPitchEnabled = !isPitchEnabled);
    final newPitch = isPitchEnabled ? 65.0 : 0.0;
    if (isFollowingUser && userPosition != null) {
      _centerCameraOnUser(bearing: userBearing);
    } else {
      mapboxMap?.flyTo(
        mp.CameraOptions(pitch: newPitch),
        mp.MapAnimationOptions(duration: 700, startDelay: 0),
      );
    }
  }

  Future<Uint8List> _loadHQMarkerImage() async {
    final ByteData byteData =
        await rootBundle.load('assets/icons/pin-point.png');
    return byteData.buffer.asUint8List();
  }

  Future<void> _changeLocationPuckToNavigation() async {
    final ByteData navData =
        await rootBundle.load('assets/icons/navigation.png');
    final Uint8List navImage = navData.buffer.asUint8List();
    await mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: Colors.red.value,
        locationPuck: mp.LocationPuck(
          locationPuck2D: mp.DefaultLocationPuck2D(
            topImage: navImage,
            shadowImage: Uint8List(0),
          ),
        ),
      ),
    );
  }

  Future<void> _reverseGeocode(mp.Position position, bool isStart) async {
    final url = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${position.lng},${position.lat}.json?access_token=${dotenv.env["MAPBOX_ACCESS_TOKEN"]!}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          setState(() {
            final name = features[0]['place_name'] ?? 'Unknown Location';
            if (isStart) {
              startLocationName = name;
            } else {
              endLocationName = name;
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Geocoding error: $e');
      }
    }
  }

  Widget _buildNavigationInfoPanel() {
    return Positioned(
      top: 90,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: _exitNavigationMode,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Navigation Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (routeDistance != null && routeDuration != null)
                  Text(
                    'Distance: ${(routeDistance! / 1000).toStringAsFixed(1)} km, '
                    'Duration: ${(routeDuration! / 60).toStringAsFixed(0)} mins',
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 8),
                if (startLocationName.isNotEmpty)
                  Text(
                    'From: $startLocationName',
                    style: const TextStyle(fontSize: 14),
                  ),
                if (endLocationName.isNotEmpty)
                  Text(
                    'To: $endLocationName',
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: routeProfiles.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: IconButton(
                        icon: Icon(entry.value),
                        color: selectedProfile == entry.key
                            ? routeColors[entry.key]
                            : Colors.grey,
                        onPressed: () => _updateRouteProfile(entry.key),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startNavigation() {
    _changeLocationPuckToNavigation();
    setState(() {
      showRoutePanel = false;
      isNavigationActive = true;
      _isNavigationPuckActive = true;
      isPitchEnabled = true;
      showRouteProfiles = true;
      showNavigationInfoPanel = true;
      _showBubble = false;
    });
    _activeCameraOnUser(
      bearing: _calculateRouteBearing(userPosition ?? mp.Position(0, 0)),
      useBottomCenter: true,
    );
  }

  void _exitNavigationMode() {
    setState(() {
      showNavigationInfoPanel = false;
      showRouteProfiles = false;
      routeCoordinates.clear();
      hasDestination = false;
      destinationPosition = null;
      routeDistance = null;
      routeDuration = null;
      averageSpeed = null;
      _routeConfirmed = false;
      isNavigationActive = false;
      _showBubble = false;
      pointAnnotationManager?.deleteAll();
      _isNavigationPuckActive = false;
      _updateRoutePolyline();
    });
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(
        pulsingColor: Colors.red.value,
        locationPuck: mp.LocationPuck(
          locationPuck2D: mp.DefaultLocationPuck2D(),
        ),
      ),
    );
  }

  void _cancelRoute() {
    _bubbleScaleController?.reverse().then((_) {
      setState(() {
        showRoutePanel = false;
        routeCoordinates.clear();
        hasDestination = false;
        destinationPosition = null;
        routeDistance = null;
        routeDuration = null;
        averageSpeed = null;
        _routeConfirmed = false;
        isNavigationActive = false;
        _showBubble = false;
        pointAnnotationManager?.deleteAll();
        _isNavigationPuckActive = false;
        _updateRoutePolyline();
      });
    });
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(
        pulsingColor: Colors.red.value,
        locationPuck: mp.LocationPuck(
          locationPuck2D: mp.DefaultLocationPuck2D(),
        ),
      ),
    );
  }

  void _zoomIn() async {
    final currentZoom = (await mapboxMap?.getCameraState())?.zoom ?? 0;
    mapboxMap?.flyTo(
      mp.CameraOptions(zoom: currentZoom + 1),
      mp.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  Future<void> _zoomOut() async {
    mapboxMap?.flyTo(
      mp.CameraOptions(
          zoom: ((await mapboxMap?.getCameraState())?.zoom ?? 0) - 1),
      mp.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }
}

// Modified BubbleTailPainter to ensure a full circle with a connecting tail
class BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw a full circle
    final circleRadius = size.width / 2;
    final circleCenter = Offset(size.width / 2, circleRadius);
    canvas.drawCircle(circleCenter, circleRadius, paint);

    //   // Draw the connecting tail
    //   final path = Path()
    //     ..moveTo(size.width / 2, circleRadius) // Start at bottom of circle
    //     ..lineTo(size.width / 2 - 5, 0) // Top left of tail (connecting to bubble)
    //     ..lineTo(size.width / 2 + 5, 0) // Top right of tail (connecting to bubble)
    //     ..close();

    //   canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
