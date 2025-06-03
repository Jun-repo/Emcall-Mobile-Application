// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RoutingMapPage extends StatefulWidget {
  final mp.Position residentPosition;
  final String residentImageUrl;

  const RoutingMapPage({
    super.key,
    required this.residentPosition,
    required this.residentImageUrl,
  });

  @override
  State<RoutingMapPage> createState() => _RoutingMapPageState();
}

class _RoutingMapPageState extends State<RoutingMapPage> {
  mp.MapboxMap? _mapController;
  mp.Position? _workerPosition;
  List<mp.Position> _routeCoordinates = [];
  double? _routeDistance;
  double? _routeDuration;
  bool _isLoading = true;
  bool _isNavigationMode = false;
  bool _isCardExpanded = false; // New state for card expansion
  mp.PointAnnotationManager? _pointAnnotationManager;
  String _currentMapStyle = 'mapbox://styles/mapbox/navigation-day-v1';
  StreamSubscription<gl.Position>? _positionStream;

  String? _startAddress;
  String? _endAddress;
  String _selectedProfile = 'driving-car';
  final List<bool> _isSelected = [true, false, false];
  final List<String> _profiles = [
    'driving-car',
    'foot-walking',
    'cycling-regular'
  ];
  Map<String, double?> _durations = {
    'driving-car': null,
    'foot-walking': null,
    'cycling-regular': null,
  };

  // Navigation instructions
  List<Map<String, dynamic>> _navigationSteps = [];
  int _currentStepIndex = 0;
  double _remainingDistance = 0;
  double _remainingDuration = 0;
  DateTime _startTime = DateTime.now();

  static const String orsBaseUrl =
      'https://api.openrouteservice.org/v2/directions';

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _fetchEndAddress();
    _getWorkerPosition();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _getWorkerPosition() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      return;
    }

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied forever')),
        );
      }
      return;
    }

    gl.Position position = await gl.Geolocator.getCurrentPosition(
      desiredAccuracy: gl.LocationAccuracy.high,
    );

    setState(() {
      _workerPosition = mp.Position(position.longitude, position.latitude);
    });

    // Wait for all data to be fetched
    await Future.wait([
      _fetchStartAddress(),
      _fetchEndAddress(),
      _getRoute(),
      _fetchAllRoutes(),
      _addResidentMarker(),
    ]);

    setState(() {
      _isLoading = false; // Only set to false when all data is ready
    });
  }

  Future<String> _getAddressFromCoordinates(mp.Position position) async {
    final apiKey = dotenv.env['ORS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return 'API key missing';
    final url =
        'https://api.openrouteservice.org/geocode/reverse?api_key=$apiKey&point.lon=${position.lng}&point.lat=${position.lat}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'];
        if (features.isNotEmpty) {
          return features[0]['properties']['label'];
        } else {
          return 'Address not found';
        }
      } else {
        return 'Error fetching address';
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }

  Future<void> _fetchStartAddress() async {
    if (_workerPosition == null) return;
    final address = await _getAddressFromCoordinates(_workerPosition!);
    setState(() {
      _startAddress = address;
    });
  }

  Future<void> _fetchEndAddress() async {
    final address = await _getAddressFromCoordinates(widget.residentPosition);
    setState(() {
      _endAddress = address;
    });
  }

  Future<void> _getRoute() async {
    if (_workerPosition == null) return;
    await _fetchRouteForProfile(_selectedProfile);
    final start = "${_workerPosition!.lng},${_workerPosition!.lat}";
    final end = "${widget.residentPosition.lng},${widget.residentPosition.lat}";
    final profile = _selectedProfile;
    final apiKey = dotenv.env['ORS_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      if (kDebugMode) print('ORS API key is missing');
      return;
    }

    final url = "$orsBaseUrl/$profile?api_key=$apiKey&start=$start&end=$end";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feature = data['features'][0];
        final coordinates = feature['geometry']['coordinates'] as List;
        final summary = feature['properties']['summary'];
        final segments = feature['properties']['segments'] as List;

        // Extract turn-by-turn instructions
        List<Map<String, dynamic>> steps = [];
        double cumulativeDuration = 0;
        if (segments.isNotEmpty && segments[0]['steps'] != null) {
          steps = (segments[0]['steps'] as List).map((step) {
            cumulativeDuration += (step['duration']?.toDouble() ?? 0.0);
            final estimatedTime =
                _startTime.add(Duration(seconds: cumulativeDuration.toInt()));
            return {
              'instruction': step['instruction'] ?? 'Continue',
              'distance': step['distance'] ?? 0.0, // in meters
              'duration': step['duration'] ?? 0.0, // in seconds
              'position': mp.Position(
                step['way_points'][1] != null
                    ? coordinates[step['way_points'][1]][0]
                    : coordinates.last[0],
                step['way_points'][1] != null
                    ? coordinates[step['way_points'][1]][1]
                    : coordinates.last[1],
              ),
              'estimatedTime': estimatedTime,
            };
          }).toList();
        }

        setState(() {
          _routeCoordinates = coordinates
              .map<mp.Position>((coord) => mp.Position(coord[0], coord[1]))
              .toList();
          _routeDistance = summary['distance'];
          _routeDuration = summary['duration'];
          _navigationSteps = steps;
          _currentStepIndex = 0;
          _remainingDistance = _routeDistance ?? 0;
          _remainingDuration = _routeDuration ?? 0;
        });
        await _drawRoute();
        if (!_isNavigationMode) {
          await _fitCameraToBounds();
        }
      } else {
        if (kDebugMode) print('ORS API error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Exception fetching route: $e');
    }
  }

  Future<void> _drawRoute() async {
    if (_routeCoordinates.isEmpty || _mapController == null) return;
    final lineString = mp.LineString(coordinates: _routeCoordinates);
    final source = await _mapController!.style.getSource('routeSource');
    if (source is mp.GeoJsonSource) {
      source.updateGeoJSON(json.encode(lineString));
    }
  }

  Future<void> _fitCameraToBounds() async {
    if (_workerPosition == null ||
        widget.residentPosition.isEmpty ||
        _mapController == null) return;
    final coordinates = [
      mp.Point(coordinates: _workerPosition!),
      mp.Point(coordinates: widget.residentPosition),
    ];
    final camera = await _mapController!.cameraForCoordinates(
      coordinates,
      mp.MbxEdgeInsets(top: 140, left: 100, bottom: 140, right: 100),
      null,
      null,
    );
    _mapController!.flyTo(
      camera,
      mp.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _addResidentMarker() async {
    final imageData = await _getResidentMarkerImage(widget.residentImageUrl);
    if (imageData != null && _pointAnnotationManager != null) {
      await _pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(coordinates: widget.residentPosition),
          image: imageData,
          iconSize: 0.8,
          iconAnchor: mp.IconAnchor.CENTER,
          symbolSortKey: 2,
        ),
      );
    }
  }

  Future<void> _resetBearingToNorth() async {
    if (_mapController == null) return;
    final currentCamera = await _mapController!.getCameraState();
    _mapController!.flyTo(
      mp.CameraOptions(
        center: currentCamera.center,
        zoom: currentCamera.zoom,
        bearing: 0,
        pitch: currentCamera.pitch,
      ),
      mp.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _changeMapStyle(String newStyle) async {
    if (_mapController == null || newStyle == _currentMapStyle) return;
    setState(() {
      _currentMapStyle = newStyle;
    });

    await _mapController!.style.setStyleURI(newStyle);
    _onMapCreated(_mapController!);
    await _getRoute();
    await _fetchAllRoutes();
    await _addResidentMarker();
  }

  Future<void> _startNavigationMode() async {
    if (_workerPosition == null || _mapController == null) return;

    setState(() {
      _isNavigationMode = true;
      _startTime = DateTime.now(); // Set start time when navigation begins
    });

    await _mapController!.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false,
        puckBearingEnabled: true,
        puckBearing: mp.PuckBearing.HEADING,
        locationPuck: mp.LocationPuck(
          locationPuck2D: mp.LocationPuck2D(
            topImage: await _createNavigationIcon(),
            bearingImage: await _createNavigationIcon(),
          ),
        ),
      ),
    );

    await _mapController!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: _workerPosition!),
        zoom: 18,
        pitch: 50,
        bearing: 0,
      ),
      mp.MapAnimationOptions(duration: 500),
    );

    _positionStream = gl.Geolocator.getPositionStream(
      locationSettings: const gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((gl.Position position) {
      _updatePositionAndCamera(position);
    });
  }

  Future<Uint8List> _createNavigationIcon() async {
    const size = 100.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final fillPaint = ui.Paint()
      ..color = Colors.redAccent
      ..style = ui.PaintingStyle.fill;

    final borderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final path = ui.Path();
    path.moveTo(size / 2, 0);
    path.lineTo(size, size);
    path.lineTo(0, size);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _updatePositionAndCamera(gl.Position position) async {
    if (_mapController == null) return;

    setState(() {
      _workerPosition = mp.Position(position.longitude, position.latitude);
    });

    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _routeCoordinates.length; i++) {
      final distance = gl.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _routeCoordinates[i].lat.toDouble(),
        _routeCoordinates[i].lng.toDouble(),
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Update the current step based on the worker's position
    for (int i = _currentStepIndex; i < _navigationSteps.length; i++) {
      final stepPosition = _navigationSteps[i]['position'] as mp.Position;
      final distanceToStep = gl.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stepPosition.lat.toDouble(),
        stepPosition.lng.toDouble(),
      );
      if (distanceToStep < 10) {
        setState(() {
          _currentStepIndex = i + 1;
        });
      } else {
        break;
      }
    }
    // Play voice instruction if the step has changed
    int previousStepIndex = _currentStepIndex;
    if (_currentStepIndex != previousStepIndex &&
        _currentStepIndex < _navigationSteps.length) {
      final instruction =
          _navigationSteps[_currentStepIndex]['instruction'] as String;
      final audioPath = _getVoiceInstruction(instruction);
      try {
        await _audioPlayer.setAsset(audioPath);
        await _audioPlayer.play();
      } catch (e) {
        if (kDebugMode) {
          print('Error playing voice instruction: $e');
        }
      }
    }

    // Calculate remaining distance and duration
    double remainingDist = 0;
    double remainingDur = 0;
    for (int i = _currentStepIndex; i < _navigationSteps.length; i++) {
      remainingDist += _navigationSteps[i]['distance'];
      remainingDur += _navigationSteps[i]['duration'];
    }

    setState(() {
      _remainingDistance = remainingDist;
      _remainingDuration = remainingDur;
    });

    double bearing = 0;
    if (closestIndex < _routeCoordinates.length - 1) {
      bearing = gl.Geolocator.bearingBetween(
        position.latitude,
        position.longitude,
        _routeCoordinates[closestIndex + 1].lat.toDouble(),
        _routeCoordinates[closestIndex + 1].lng.toDouble(),
      );
    }

    await _mapController!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: _workerPosition!),
        zoom: 15,
        pitch: 30,
        bearing: bearing,
      ),
      mp.MapAnimationOptions(duration: 500),
    );
  }

  double? _getDurationForProfile(String profile) {
    return _durations[profile] != null ? _durations[profile]! / 60 : null;
  }

  Future<void> _fetchAllRoutes() async {
    for (final profile in _profiles) {
      await _fetchRouteForProfile(profile);
    }
  }

  Future<void> _fetchRouteForProfile(String profile) async {
    if (_workerPosition == null) return;

    final start = "${_workerPosition!.lng},${_workerPosition!.lat}";
    final end = "${widget.residentPosition.lng},${widget.residentPosition.lat}";
    final apiKey = dotenv.env['ORS_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      if (kDebugMode) print('ORS API key is missing');
      return;
    }

    final url = "$orsBaseUrl/$profile?api_key=$apiKey&start=$start&end=$end";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feature = data['features'][0];
        final coordinates = feature['geometry']['coordinates'] as List;
        final summary = feature['properties']['summary'];
        setState(() {
          if (profile == _selectedProfile) {
            _routeCoordinates = coordinates
                .map<mp.Position>((coord) => mp.Position(coord[0], coord[1]))
                .toList();
            _routeDistance = summary['distance'];
            _routeDuration = summary['duration'];
          }
          _durations[profile] = summary['duration'];
        });
        if (profile == _selectedProfile) {
          await _drawRoute();
          if (!_isNavigationMode) {
            await _fitCameraToBounds();
          }
        }
      } else {
        if (kDebugMode) print('ORS API error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Exception fetching route: $e');
    }
  }

  Future<Uint8List?> _getResidentMarkerImage(String imageUrl) async {
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
    const shadowBlurRadius = 6.0;

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
      final defaultImage = await DefaultAssetBundle.of(context)
          .load('assets/icons/location_puck.png');
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

    canvas.restore();

    final picture = recorder.endRecording();
    final img =
        await picture.toImage(circleSize.toInt(), overallHeight.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  void _onMapCreated(mp.MapboxMap controller) async {
    _mapController = controller;
    _pointAnnotationManager =
        await controller.annotations.createPointAnnotationManager();

    await controller.style.addSource(mp.GeoJsonSource(id: 'routeSource'));

    await controller.style.addLayer(
      mp.LineLayer(
        id: 'routeShadowLayer',
        sourceId: 'routeSource',
        lineColor: Colors.black.withOpacity(0.3).value,
        lineWidth: 9.0,
        lineOpacity: 0.5,
        lineCap: mp.LineCap.ROUND,
        lineJoin: mp.LineJoin.ROUND,
      ),
    );

    await controller.style.addLayer(
      mp.LineLayer(
        id: 'routeStrokeLayer',
        sourceId: 'routeSource',
        lineColor: Colors.white.value,
        lineWidth: 8.0,
        lineOpacity: 1.0,
        lineCap: mp.LineCap.ROUND,
        lineJoin: mp.LineJoin.ROUND,
      ),
    );

    await controller.style.addLayer(
      mp.LineLayer(
        id: 'routeLayer',
        sourceId: 'routeSource',
        lineColor: Colors.red.value,
        lineWidth: 5.0,
        lineOpacity: 1.0,
        lineCap: mp.LineCap.ROUND,
        lineJoin: mp.LineJoin.ROUND,
      ),
    );

    await controller.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: Colors.redAccent.value,
        puckBearingEnabled: false,
        puckBearing: mp.PuckBearing.COURSE,
        pulsingMaxRadius: 70.0,
      ),
    );
  }

  String _formatDuration(double durationInSeconds) {
    final int hours = (durationInSeconds / 3600).floor();
    final int minutes = ((durationInSeconds % 3600) / 60).round();
    if (hours > 0) {
      return '$hours hr $minutes min';
    } else {
      return '$minutes min';
    }
  }

  IconData _getInstructionIcon(String instruction, bool isCurrentStep) {
    final lowerInstruction = instruction.toLowerCase();
    if (lowerInstruction.contains('turn left')) {
      return Icons.turn_left_rounded;
    } else if (lowerInstruction.contains('turn right')) {
      return Icons.turn_right_rounded;
    } else if (lowerInstruction.contains('continue straight')) {
      return Icons.straight_rounded;
    } else if (lowerInstruction.contains('slight left')) {
      return Icons.turn_slight_left_rounded;
    } else if (lowerInstruction.contains('slight right')) {
      return Icons.turn_slight_right_rounded;
    } else if (lowerInstruction.contains('make a u-turn')) {
      return Icons.u_turn_left_rounded;
    } else if (lowerInstruction.contains('head north') ||
        lowerInstruction.contains('head south') ||
        lowerInstruction.contains('head east') ||
        lowerInstruction.contains('head west') ||
        lowerInstruction.contains('head northeast') ||
        lowerInstruction.contains('head northwest') ||
        lowerInstruction.contains('head southeast') ||
        lowerInstruction.contains('head southwest')) {
      return Icons.directions;
    }
    return isCurrentStep ? Icons.navigation : Icons.directions;
  }

  // New method to get voice instruction audio asset path
  String _getVoiceInstruction(String instruction) {
    final lowerInstruction = instruction.toLowerCase();
    if (lowerInstruction.contains('turn left')) {
      return 'assets/audio/turn_left.mp3';
    } else if (lowerInstruction.contains('turn right')) {
      return 'assets/audio/turn_right.mp3';
    } else if (lowerInstruction.contains('continue straight')) {
      return 'assets/audio/continue_straight.mp3';
    } else if (lowerInstruction.contains('slight left')) {
      return 'assets/audio/turn_left.mp3';
    } else if (lowerInstruction.contains('slight right')) {
      return 'assets/audio/turn_right.mp3';
    } else if (lowerInstruction.contains('make a u-turn')) {
      return 'assets/audio/u_turn.mp3';
    } else if (lowerInstruction.contains('head north')) {
      return 'assets/audio/head_north.mp3';
    } else if (lowerInstruction.contains('head south')) {
      return 'assets/audio/head_south.mp3';
    } else if (lowerInstruction.contains('head east')) {
      return 'assets/audio/head_east.mp3';
    } else if (lowerInstruction.contains('head west')) {
      return 'assets/audio/head_west.mp3';
    } else if (lowerInstruction.contains('head northeast')) {
      return 'assets/audio/head_northeast.mp3';
    } else if (lowerInstruction.contains('head northwest')) {
      return 'assets/audio/head_northwest.mp3';
    } else if (lowerInstruction.contains('head southeast')) {
      return 'assets/audio/head_southeast.mp3';
    } else if (lowerInstruction.contains('head southwest')) {
      return 'assets/audio/head_southwest.mp3';
    }
    return 'assets/audio/proceed.mp3';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        _currentMapStyle == 'mapbox://styles/mapbox/navigation-night-v1';
    final Color cardBackgroundColor = isDarkMode
        ? const ui.Color.fromARGB(255, 20, 20, 20).withOpacity(0.9)
        : const ui.Color.fromARGB(255, 255, 255, 255).withOpacity(0.9);
    final Color iconColor = isDarkMode ? Colors.white : Colors.black;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      body: Stack(
        children: [
          mp.MapWidget(
            key: const ValueKey('routingMapWidget'),
            styleUri: _currentMapStyle,
            onMapCreated: _onMapCreated,
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Navigation Instructions Card (visible in navigation mode)
          if (_isNavigationMode)
            Positioned(
              top: 25,
              left: 15,
              right: 15,
              bottom: _isCardExpanded ? 15 : null,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isCardExpanded = !_isCardExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isCardExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Distance: ${(_remainingDistance / 1000).toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Duration: ${_formatDuration(_remainingDuration)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _navigationSteps.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _navigationSteps.length) {
                                    final arrivalTime = _startTime.add(Duration(
                                        seconds:
                                            (_routeDuration?.toInt() ?? 0)));
                                    return ListTile(
                                      leading: Icon(
                                        Icons.flag,
                                        color: textColor,
                                        size: 24,
                                      ),
                                      title: Text(
                                        'Arrive at destination',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'At ${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: textColor.withOpacity(0.7),
                                        ),
                                      ),
                                    );
                                  }

                                  final step = _navigationSteps[index];
                                  final isCurrentStep =
                                      index == _currentStepIndex;
                                  final estimatedTime =
                                      step['estimatedTime'] as DateTime;
                                  final instructionIcon = _getInstructionIcon(
                                    step['instruction'],
                                    isCurrentStep,
                                  );

                                  return ListTile(
                                    leading: Icon(
                                      isCurrentStep
                                          ? instructionIcon
                                          : Icons.directions,
                                      color: isCurrentStep
                                          ? Colors.redAccent
                                          : textColor,
                                      size: 24,
                                    ),
                                    title: Text(
                                      step['instruction'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textColor,
                                        fontWeight: isCurrentStep
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'In ${step['distance'].toStringAsFixed(0)} m',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor.withOpacity(0.7),
                                          ),
                                        ),
                                        Text(
                                          'At ${estimatedTime.hour.toString().padLeft(2, '0')}:${estimatedTime.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Distance: ${(_remainingDistance / 1000).toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Duration: ${_formatDuration(_remainingDuration)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _currentStepIndex < _navigationSteps.length
                                      ? _getInstructionIcon(
                                          _navigationSteps[_currentStepIndex]
                                              ['instruction'],
                                          _currentStepIndex ==
                                              _currentStepIndex)
                                      : Icons.flag,
                                  color: textColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentStepIndex < _navigationSteps.length
                                        ? _navigationSteps[_currentStepIndex]
                                            ['instruction']
                                        : 'You have arrived!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_currentStepIndex < _navigationSteps.length)
                              Text(
                                'In ${_navigationSteps[_currentStepIndex]['distance'].toStringAsFixed(0)} m',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),

          // Start and End Addresses at the Top with Close and Up-Down Icons
          if (!_isNavigationMode)
            Positioned(
              top: 25,
              left: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 24,
                  right: 16,
                  bottom: 24,
                ),
                decoration: BoxDecoration(
                  color: cardBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location_outlined,
                            color: iconColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _startAddress ?? 'Your Current address...',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, color: textColor),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.redAccent,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    CustomPaint(
                      size: const Size(4, 22),
                      painter: DottedLinePainter(),
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: iconColor, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _endAddress ?? 'Resident address...',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, color: textColor),
                          ),
                        ),
                        const Icon(
                          Icons.swap_vert,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Route Type Selection as Circular Avatars (Vertical List at Bottom-Left)
          if (!_isNavigationMode)
            Positioned(
              bottom: 120,
              left: 10,
              child: Column(
                children: List.generate(_profiles.length, (index) {
                  final profile = _profiles[index];
                  final isSelected = _isSelected[index];
                  final icon = _getIconForProfile(profile);
                  final duration = _getDurationForProfile(profile);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          for (int i = 0; i < _isSelected.length; i++) {
                            _isSelected[i] = i == index;
                          }
                          _selectedProfile = profile;
                        });
                        _getRoute();
                      },
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: isSelected
                            ? Colors.redAccent
                            : Colors.grey.withOpacity(0.8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              color: iconColor,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              duration != null
                                  ? '${duration.toStringAsFixed(0)} min'
                                  : '  ',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Route Distance and Duration at the Bottom
          if (!_isNavigationMode)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  top: 8,
                  right: 12,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(45),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getIconForProfile(_selectedProfile),
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _routeDuration != null
                              ? '${(_routeDuration! / 60).toStringAsFixed(0)} min'
                              : 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _routeDistance != null
                          ? '${(_routeDistance! / 1609).toStringAsFixed(1)} mi'
                          : 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : _startNavigationMode, // Disable when loading
                      child: CircleAvatar(
                        backgroundColor: _isLoading
                            ? Colors.grey[400]
                            : Colors.white, // Grey when disabled
                        radius: 30,
                        child: Icon(
                          Icons.navigation_rounded,
                          color: _isLoading
                              ? Colors.grey[600]
                              : Colors.red, // Grey icon when disabled
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Circle Avatar Button (Bottom-Right) - Fit Camera to Bounds
          if (!_isNavigationMode)
            Positioned(
              bottom: 125,
              right: 20,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.withOpacity(0.8),
                child: IconButton(
                  icon: Icon(
                    Icons.my_location_outlined,
                    color: iconColor,
                    size: 28,
                  ),
                  onPressed: _fitCameraToBounds,
                ),
              ),
            ),

          // Floating Circle Avatar Button (Top-Right) - Compass (Reset to North)
          if (!_isNavigationMode)
            Positioned(
              top: 150,
              right: 10,
              child: IconButton(
                icon: Icon(
                  Icons.explore,
                  color: iconColor,
                  size: 34,
                ),
                onPressed: _resetBearingToNorth,
              ),
            ),

          // Floating Circle Avatar Button (Below Compass) - Style Toggle
          if (!_isNavigationMode)
            Positioned(
              top: 200,
              right: 10,
              child: PopupMenuButton<String>(
                color: cardBackgroundColor,
                onSelected: (String style) {
                  _changeMapStyle(style);
                },
                offset: const Offset(-45, 20),
                child: IconButton(
                  icon: Icon(
                    Icons.layers,
                    color: iconColor,
                    size: 34,
                  ),
                  onPressed: null,
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'mapbox://styles/mapbox/navigation-night-v1',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.dark_mode, color: iconColor),
                          SizedBox(width: 8),
                          Text(
                            'Dark',
                            style: TextStyle(color: iconColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'mapbox://styles/mapbox/navigation-day-v1',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.light_mode, color: iconColor),
                          SizedBox(width: 8),
                          Text(
                            'Light',
                            style: TextStyle(color: iconColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForProfile(String profile) {
    switch (profile) {
      case 'driving-car':
        return Icons.directions_car_rounded;
      case 'cycling-regular':
        return Icons.directions_bike_rounded;
      case 'foot-walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.directions_rounded;
    }
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const double dashHeight = 1;
    const double dashSpace = 3;
    double startY = 3;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(12, startY),
        Offset(12, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
