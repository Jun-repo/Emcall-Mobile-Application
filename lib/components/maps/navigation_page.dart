// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;

class NavigationPage extends StatefulWidget {
  final String startLocation;
  final String endLocation;
  final mb.Position endPosition;
  final List<mb.Position> routeCoordinates;
  final double routeDistance;
  final double routeDuration;
  final String selectedProfile;

  const NavigationPage({
    Key? key,
    required this.startLocation,
    required this.endLocation,
    required this.endPosition,
    required this.routeCoordinates,
    required this.routeDistance,
    required this.selectedProfile,
    required this.routeDuration,
  }) : super(key: key);

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with TickerProviderStateMixin {
  mb.MapboxMap? _mapboxMap;
  mb.PolylineAnnotationManager? _polylineAnnotationManager;
  mb.PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _endMarkerImage;
  Uint8List? _navigationIconImage;
  StreamSubscription<gl.Position>? _positionStreamSubscription;
  AnimationController? _cardAnimationController;
  Animation<double>? _cardAnimation;
  AnimationController? _speedometerAnimationController;
  Animation<Offset>? _speedometerSlideAnimation;
  Animation<double>? _speedometerFadeAnimation;
  bool _isCardExpanded = false;
  bool _isArrived = false;
  List<Map<String, dynamic>> _instructions = [];
  String _currentInstruction = 'Starting...';
  double _remainingDistance;
  mb.Position? _currentUserPosition;
  double _currentSpeed = 0.0;

  // Route styling
  final Map<String, Color> _routeColors = {
    'driving-car': const Color.fromARGB(255, 40, 119, 255),
    'cycling-regular': const Color.fromARGB(255, 8, 211, 15),
    'foot-walking': const Color.fromARGB(255, 255, 60, 0),
  };

  _NavigationPageState() : _remainingDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _remainingDistance = widget.routeDistance;
    _initializeAnimations();
    _loadMarkerImages();
    _fetchNavigationInstructions();
    _startLocationUpdates();
  }

  void _initializeAnimations() {
    // Card animation
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardAnimation = Tween<double>(begin: 200.0, end: 400.0).animate(
      CurvedAnimation(
          parent: _cardAnimationController!, curve: Curves.easeInOut),
    );

    // Speedometer animation
    _speedometerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _speedometerSlideAnimation = Tween<Offset>(
      begin: const Offset(2.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _speedometerAnimationController!,
      curve: Curves.easeInOut,
    ));
    _speedometerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _speedometerAnimationController!,
      curve: Curves.easeInOut,
    ));

    // Always show speedometer initially
    _speedometerAnimationController!.forward();
  }

  Future<void> _loadMarkerImages() async {
    final endData = await rootBundle.load('assets/icons/location_puck.png');
    _endMarkerImage = endData.buffer.asUint8List();
    final navData = await rootBundle.load('assets/icons/navigation.png');
    _navigationIconImage = navData.buffer.asUint8List();

    if (mounted) {
      setState(() {});
      if (_currentUserPosition != null && _mapboxMap != null) {
        _updateUserPositionOnRoute(
          _currentUserPosition!,
          gl.Position(
            latitude: _currentUserPosition!.lat.toDouble(),
            longitude: _currentUserPosition!.lng.toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: _currentSpeed,
            speedAccuracy: 0.0,
          ),
        );
      }
    }
  }

  Future<void> _fetchNavigationInstructions() async {
    try {
      final apiKey = dotenv.env['ORS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('ORS API key is missing.');
      }

      final start = widget.routeCoordinates.first;
      final end = widget.endPosition;

      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/${widget.selectedProfile}'
        '?api_key=$apiKey'
        '&start=${start.lng},${start.lat}'
        '&end=${end.lng},${end.lat}',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'].isEmpty) {
          throw Exception('No route data returned.');
        }

        final segments =
            data['features'][0]['properties']['segments'] as List<dynamic>;
        List<Map<String, dynamic>> instructions = [];
        for (var segment in segments) {
          if (segment.containsKey('steps')) {
            for (var step in segment['steps']) {
              instructions.add({
                'instruction': step['instruction'] ?? 'Continue',
                'distance': step['distance']?.toDouble() ?? 0.0,
                'duration': step['duration']?.toDouble() ?? 0.0,
                'name': step['name'] ?? 'Unnamed road',
              });
            }
          }
        }

        setState(() {
          _instructions = instructions;
          if (instructions.isNotEmpty) {
            _currentInstruction = instructions[0]['instruction'];
          }
        });
      } else {
        throw Exception('Failed to fetch instructions.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching instructions: $e')),
      );
    }
  }

  void _startLocationUpdates() {
    const locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.best,
      distanceFilter: 5,
    );

    _positionStreamSubscription =
        gl.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(
      (gl.Position position) {
        final newPosition = mb.Position(position.longitude, position.latitude);
        setState(() {
          _currentUserPosition = newPosition;
          _currentSpeed = position.speed;
        });
        _updateUserPositionOnRoute(newPosition, position);
        _checkArrival(newPosition);
        _updateCurrentInstruction(newPosition);
      },
      onError: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      },
    );
  }

  void _updateUserPositionOnRoute(
      mb.Position userPosition, gl.Position position) async {
    if (_mapboxMap == null || _isArrived || _navigationIconImage == null)
      return;

    final snappedPosition = _snapToRoute(userPosition);
    await _mapboxMap?.location.updateSettings(
      mb.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: mb.PuckBearing.HEADING,
        pulsingEnabled: false,
        locationPuck: mb.LocationPuck(
          locationPuck2D: mb.LocationPuck2D(
            topImage: _navigationIconImage,
            bearingImage: _navigationIconImage,
            scaleExpression: json.encode({
              "interpolate": ["linear"],
              "zoom": [0, 0.5, 20, 0.5]
            }),
          ),
        ),
      ),
    );

    // Calculate bearing to next point on route
    final nextPointIndex = widget.routeCoordinates.indexOf(snappedPosition) + 1;
    double bearing = position.heading;
    if (nextPointIndex < widget.routeCoordinates.length) {
      final nextPoint = widget.routeCoordinates[nextPointIndex];
      bearing = gl.Geolocator.bearingBetween(
        snappedPosition.lat.toDouble(),
        snappedPosition.lng.toDouble(),
        nextPoint.lat.toDouble(),
        nextPoint.lng.toDouble(),
      );
    }

    // Continuously center camera on user's snapped position
    _mapboxMap?.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: snappedPosition),
        zoom: 18.0, // Maintain a close zoom level
        pitch: 60.0, // Keep a 3D perspective
        bearing: bearing, // Align with user's heading or route direction
      ),
      mb.MapAnimationOptions(duration: 200), // Smooth transition
    );
  }

  mb.Position _snapToRoute(mb.Position userPosition) {
    mb.Position closestPoint = widget.routeCoordinates.first;
    double minDistance = double.infinity;

    for (var point in widget.routeCoordinates) {
      final distance = gl.Geolocator.distanceBetween(
        userPosition.lat.toDouble(),
        userPosition.lng.toDouble(),
        point.lat.toDouble(),
        point.lng.toDouble(),
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint;
  }

  void _checkArrival(mb.Position userPosition) {
    final distanceToDestination = gl.Geolocator.distanceBetween(
      userPosition.lat.toDouble(),
      userPosition.lng.toDouble(),
      widget.endPosition.lat.toDouble(),
      widget.endPosition.lng.toDouble(),
    );

    if (distanceToDestination < 10.0) {
      setState(() {
        _isArrived = true;
        _currentInstruction = 'You have arrived at ${widget.endLocation}!';
      });
      _positionStreamSubscription?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have arrived!')),
      );
    } else {
      setState(() {
        _remainingDistance = distanceToDestination;
      });
    }
  }

  void _updateCurrentInstruction(mb.Position userPosition) {
    if (_instructions.isEmpty || _isArrived) return;

    for (int i = 0; i < _instructions.length; i++) {
      final nextPointIndex = widget.routeCoordinates.indexWhere((pos) {
        return gl.Geolocator.distanceBetween(
              userPosition.lat.toDouble(),
              userPosition.lng.toDouble(),
              pos.lat.toDouble(),
              pos.lng.toDouble(),
            ) <
            10.0;
      });

      if (nextPointIndex != -1) {
        setState(() {
          _currentInstruction = _instructions[i]['instruction'];
        });
        break;
      }
    }
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (_mapboxMap == null || widget.routeCoordinates.isEmpty) return;

    _polylineAnnotationManager =
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    await _mapboxMap!.style
        .addSource(mb.GeoJsonSource(id: "route_source", lineMetrics: true));
    if (_navigationIconImage == null) {
      await _loadMarkerImages();
    }
    await _mapboxMap!.style.addLayer(
      mb.LineLayer(
        id: "route_layer",
        sourceId: "route_source",
        lineColor: _routeColors[widget.selectedProfile]!.value,
        lineWidth: 6.0,
        lineOpacity: 0.9,
        lineBorderColor: Colors.black.value,
        lineBorderWidth: 1.0,
        lineCap: mb.LineCap.ROUND,
        lineJoin: mb.LineJoin.ROUND,
      ),
    );

    final line = mb.LineString(coordinates: widget.routeCoordinates);
    final source = await _mapboxMap?.style.getSource("route_source");
    if (source is mb.GeoJsonSource) {
      source.updateGeoJSON(json.encode(line));
    }

    _pointAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    if (_endMarkerImage != null) {
      await _pointAnnotationManager?.create(
        mb.PointAnnotationOptions(
          geometry: mb.Point(coordinates: widget.endPosition),
          image: _endMarkerImage,
          iconSize: 0.5,
          iconOffset: [0, -15],
        ),
      );
    }

    // Set initial location puck settings
    await _mapboxMap?.location.updateSettings(
      mb.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: mb.PuckBearing.HEADING,
        pulsingEnabled: true,
        locationPuck: mb.LocationPuck(
          locationPuck2D: mb.LocationPuck2D(
            topImage: _navigationIconImage ?? null,
            bearingImage: _navigationIconImage ?? null,
            scaleExpression: json.encode({
              "interpolate": ["linear"],
              "zoom": [0, 1.0, 20, 1.0]
            }),
          ),
        ),
      ),
    );

    // Initial camera setup
    if (_currentUserPosition != null) {
      _updateUserPositionOnRoute(
        _currentUserPosition!,
        gl.Position(
          latitude: _currentUserPosition!.lat.toDouble(),
          longitude: _currentUserPosition!.lng.toDouble(),
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: _currentSpeed,
          speedAccuracy: 0.0,
        ),
      );
    } else {
      _mapboxMap?.setCamera(
        mb.CameraOptions(
          center: mb.Point(coordinates: widget.routeCoordinates.first),
          zoom: 18.0,
          pitch: 60.0,
          bearing: 0.0,
        ),
      );
    }
  }

  Future<void> _fitMapToRoute() async {
    if (widget.routeCoordinates.isEmpty || _mapboxMap == null) return;

    final coordinates = widget.routeCoordinates
        .map((pos) => mb.Point(coordinates: pos))
        .toList();

    const double cardHeight = 200.0;
    final paddingTop = cardHeight + 50.0;

    final camera = await _mapboxMap!.cameraForCoordinates(
      coordinates,
      mb.MbxEdgeInsets(
        top: paddingTop,
        left: 50.0,
        bottom: 50.0,
        right: 50.0,
      ),
      null,
      0.0,
    );

    _mapboxMap!.flyTo(
      mb.CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        pitch: 0.0,
        bearing: 0.0,
      ),
      mb.MapAnimationOptions(duration: 1000),
    );
  }

  void _centerOnUser() {
    if (_currentUserPosition == null || _mapboxMap == null) return;
    _mapboxMap!.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: _currentUserPosition!),
        zoom: 18.0,
        pitch: 60.0,
        bearing: 0.0,
      ),
      mb.MapAnimationOptions(duration: 700),
    );
  }

  void _handleOverviewClick() async {
    await _fitMapToRoute();
    await Future.delayed(const Duration(seconds: 1));
    _centerOnUser();
  }

  void _toggleCardExpansion() {
    setState(() {
      _isCardExpanded = !_isCardExpanded;
    });
    if (_isCardExpanded) {
      _cardAnimationController?.forward();
    } else {
      _cardAnimationController?.reverse();
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _cardAnimationController?.dispose();
    _speedometerAnimationController?.dispose();
    if (_polylineAnnotationManager != null) {
      _mapboxMap?.annotations
          .removeAnnotationManager(_polylineAnnotationManager!);
    }
    if (_pointAnnotationManager != null) {
      _mapboxMap?.annotations.removeAnnotationManager(_pointAnnotationManager!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            AnimatedBuilder(
              animation: _cardAnimationController!,
              builder: (context, child) {
                final instructionLength = _currentInstruction.length;
                double instructionFontSize;
                double remainingDistanceFontSize;

                if (instructionLength <= 17) {
                  instructionFontSize = 38.0;
                  remainingDistanceFontSize = 24.0;
                } else if (instructionLength <= 48) {
                  instructionFontSize = 26.0;
                  remainingDistanceFontSize = 18.0;
                } else {
                  instructionFontSize = 18.0;
                  remainingDistanceFontSize = 14.0;
                }

                return Container(
                  height: _isCardExpanded ? _cardAnimation!.value : 120.0,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: _toggleCardExpansion,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 20, left: 20, bottom: 10, top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentInstruction,
                                      style: TextStyle(
                                        fontSize: instructionFontSize,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Remaining: ${(_remainingDistance / 1000).toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        fontSize: remainingDistanceFontSize,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _isCardExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        if (_isCardExpanded)
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _instructions.length,
                              itemBuilder: (context, index) {
                                final instruction = _instructions[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.directions,
                                    color: _routeColors[widget.selectedProfile],
                                  ),
                                  title: Text(
                                    instruction['instruction'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '${instruction['name']} - ${(instruction['distance'] / 1000).toStringAsFixed(1)} km',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Map Section
            Expanded(
              child: Stack(
                children: [
                  mb.MapWidget(
                    key: const ValueKey("navigationMapWidget"),
                    styleUri: "mapbox://styles/mapbox/navigation-day-v1",
                    onMapCreated: _onMapCreated,
                    cameraOptions: mb.CameraOptions(
                      zoom: 16.0,
                      center:
                          mb.Point(coordinates: widget.routeCoordinates.first),
                      pitch: 45.0,
                    ),
                  ),
                  // Speedometer
                  Positioned(
                    bottom: 120,
                    right: 20,
                    child: SlideTransition(
                      position: _speedometerSlideAnimation!,
                      child: FadeTransition(
                        opacity: _speedometerFadeAnimation!,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (_currentSpeed * 3.6).toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'km/h',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Overview Button
                  Positioned(
                    top: 140,
                    left: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      radius: 30,
                      child: IconButton(
                        icon: const Icon(
                          Icons.route_sharp,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _handleOverviewClick,
                      ),
                    ),
                  ),
                  // Back Button
                  Positioned(
                    top: 30,
                    left: 20,
                    child: SafeArea(
                      child: CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isArrived
          ? Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 25, horizontal: 8),
                ),
                child: const Text(
                  'End Navigation',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
