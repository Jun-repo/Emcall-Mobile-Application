// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:shared_preferences/shared_preferences.dart';
import 'route_info_page.dart';

/// A full-screen Mapbox map widget with user location centering, follow functionality,
/// and long-press annotation with a bubble card for action buttons.
class EmcallMap extends StatefulWidget {
  const EmcallMap({Key? key}) : super(key: key);

  @override
  _EmcallMapState createState() => _EmcallMapState();
}

class _EmcallMapState extends State<EmcallMap> with TickerProviderStateMixin {
  mb.MapboxMap? _mapboxMap;
  StreamSubscription<gl.Position>? _positionStreamSubscription;
  mb.PointAnnotationManager? _pointAnnotationManager;

  // Bubble & animations
  mb.Position? _pendingDestination;
  bool _showBubble = false;
  bool _showSearchIcon = false;
  mb.ScreenCoordinate? _currentBubblePosition;
  Timer? _bubbleTimer;
  AnimationController? _bubbleScaleController;
  Animation<double>? _bubbleScaleAnimation;
  AnimationController? _bounceController;
  Animation<double>? _bounceAnimation;
  bool _isLoadingRoute = false;

  // FAB animations
  AnimationController? _fabSlideController;
  Animation<Offset>? _fabSlideAnimation;

  // Map-view button animations
  AnimationController? _mapViewSlideController;
  Animation<Offset>? _mapViewSlideAnimation;

  // Bottom sheet slide for search
  AnimationController? _bottomSheetSlideController;
  Animation<Offset>? _bottomSheetSlideAnimation;

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Settings state
  bool _editorModeExpanded = false;
  String _viewMode = 'Auto';
  String _editorChoice = 'Day';
  String _typeChoice = 'Default';
  String _distanceUnit = 'KM';
  bool _keepNorth = true;
  bool _autoZoom = true;

  // Location info
  String endLocationName = 'Destination';
  String roadName = 'Unnamed road';

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _bubbleScaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bubbleScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bubbleScaleController!, curve: Curves.elasticInOut),
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _bounceController!, curve: Curves.elasticInOut),
    );

    _fabSlideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fabSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.5, 0.0),
    ).animate(
        CurvedAnimation(parent: _fabSlideController!, curve: Curves.easeInOut));

    _mapViewSlideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _mapViewSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.5, 0.0),
    ).animate(CurvedAnimation(
        parent: _mapViewSlideController!, curve: Curves.easeInOut));

    _bottomSheetSlideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bottomSheetSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 2.0),
    ).animate(CurvedAnimation(
        parent: _bottomSheetSlideController!, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapboxMap?.addListener(_onCameraChangeListener);
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapboxMap?.removeListener(_onCameraChangeListener);
    _stopBubbleTimer();
    _bubbleScaleController?.dispose();
    _bounceController?.dispose();
    _fabSlideController?.dispose();
    _mapViewSlideController?.dispose();
    _bottomSheetSlideController?.dispose();

    _searchController.dispose();
    super.dispose();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _viewMode = prefs.getString('map_view') ?? 'Auto';
      _editorChoice = prefs.getString('map_mode') ?? 'Day';
      _typeChoice = prefs.getString('map_type') ?? 'Default';
      _distanceUnit = prefs.getString('distance_unit') ?? 'KM';
      _keepNorth = prefs.getBool('keep_north_up') ?? true;
      _autoZoom = prefs.getBool('auto_zoom') ?? true;
    });
    await _applyViewMode();
    await _applyEditorMode();
    await _applyMapType();
    await _applyKeepNorth();
    await _applyAutoZoom();
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_view', _viewMode);
    await prefs.setString('map_mode', _editorChoice);
    await prefs.setString('map_type', _typeChoice);
    await prefs.setString('distance_unit', _distanceUnit);
    await prefs.setBool('keep_north_up', _keepNorth);
    await prefs.setBool('auto_zoom', _autoZoom);
  }

  // Apply Map View (2D, Auto, 3D)
  Future<void> _applyViewMode() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    double pitch = cameraState.pitch;
    double bearing = _keepNorth ? 0.0 : cameraState.bearing;

    switch (_viewMode) {
      case '2D':
        pitch = 0.0;
        break;
      case '3D':
        pitch = 45.0;
        break;
      case 'Auto':
        pitch = cameraState.pitch;
        break;
    }

    _mapboxMap?.easeTo(
      mb.CameraOptions(
        pitch: pitch,
        bearing: bearing,
        zoom: cameraState.zoom,
        center: cameraState.center,
      ),
      mb.MapAnimationOptions(duration: 500),
    );
  }

  // Apply Editor Mode (Day, Night)
  Future<void> _applyEditorMode() async {
    if (_mapboxMap == null) return;
    final styleUri = _editorChoice == 'Day'
        ? 'mapbox://styles/mapbox/navigation-day-v1'
        : 'mapbox://styles/mapbox/navigation-night-v1';
    await _mapboxMap?.style.setStyleURI(styleUri);
  }

  // Apply Map Type (Default, Map editor)
  Future<void> _applyMapType() async {
    if (_mapboxMap == null) return;
    final styleUri = _typeChoice == 'Default'
        ? (_editorChoice == 'Day'
            ? 'mapbox://styles/mapbox/navigation-day-v1'
            : 'mapbox://styles/mapbox/navigation-night-v1')
        : 'mapbox://styles/mapbox/satellite-streets-v12';
    await _mapboxMap?.style.setStyleURI(styleUri);
  }

  // Apply Keep North
  Future<void> _applyKeepNorth() async {
    if (_mapboxMap == null) return;
    if (_keepNorth) {
      final cameraState = await _mapboxMap!.getCameraState();
      _mapboxMap?.easeTo(
        mb.CameraOptions(
          bearing: 0.0,
          pitch: cameraState.pitch,
          zoom: cameraState.zoom,
          center: cameraState.center,
        ),
        mb.MapAnimationOptions(duration: 500),
      );
    }
  }

  // Apply Auto Zoom
  Future<void> _applyAutoZoom() async {
    if (_mapboxMap == null || !_autoZoom) return;
    _startLocationUpdates();
  }

  // Update Map View setting
  void _updateViewMode(String mode) {
    setState(() {
      _viewMode = mode;
    });
    _applyViewMode();
    _saveSettings();
  }

  // Update Editor Mode setting
  void _updateEditorMode(String mode) {
    setState(() {
      _editorChoice = mode;
    });
    _applyEditorMode();
    _applyMapType();
    _saveSettings();
  }

  // Update Type setting
  void _updateType(String type) {
    setState(() {
      _typeChoice = type;
    });
    _applyMapType();
    _saveSettings();
  }

  // Update Distance Unit setting
  void _updateDistanceUnit(String unit) {
    setState(() {
      _distanceUnit = unit;
    });
    _saveSettings();
  }

  // Update Keep North setting
  void _updateKeepNorth(bool value) {
    setState(() {
      _keepNorth = value;
    });
    _applyKeepNorth();
    _saveSettings();
  }

  // Update Auto Zoom setting
  void _updateAutoZoom(bool value) {
    setState(() {
      _autoZoom = value;
    });
    _applyAutoZoom();
    _saveSettings();
  }

// Start location updates for Auto Zoom and Auto View Mode
  void _startLocationUpdates() {
    _positionStreamSubscription?.cancel();
    if (_autoZoom || _viewMode == 'Auto') {
      const locationSettings = gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 5,
      );
      _positionStreamSubscription =
          gl.Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (gl.Position position) async {
          if (_mapboxMap == null) return;
          if (_autoZoom) {
            double zoom = 14.0;
            final speedKmh = position.speed * 3.6;
            if (speedKmh > 60) {
              zoom = 12.0;
            } else if (speedKmh < 10) {
              zoom = 15.0;
            }
            _mapboxMap?.easeTo(
              mb.CameraOptions(
                zoom: zoom,
                center: mb.Point(
                  coordinates: mb.Position(
                    position.longitude,
                    position.latitude,
                  ),
                ),
                bearing: _keepNorth ? 0.0 : position.heading,
                pitch: _viewMode == '3D'
                    ? 45.0
                    : _viewMode == '2D'
                        ? 0.0
                        : (speedKmh > 30 ? 30.0 : 0.0),
              ),
              mb.MapAnimationOptions(duration: 500),
            );
          } else if (_viewMode == 'Auto') {
            double pitch = position.speed * 3.6 > 30 ? 30.0 : 0.0;
            final cameraState = await _mapboxMap!.getCameraState();
            _mapboxMap?.easeTo(
              mb.CameraOptions(
                pitch: pitch,
                bearing: _keepNorth ? 0.0 : position.heading,
                zoom: cameraState.zoom,
                center: mb.Point(
                  coordinates: mb.Position(
                    position.longitude,
                    position.latitude,
                  ),
                ),
              ),
              mb.MapAnimationOptions(duration: 500),
            );
          }
        },
        onError: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location error: $e')),
          );
        },
      );
    }
  }

  void _showMapViewModalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        );
                      },
                      child: !_editorModeExpanded
                          ? _buildMapViewSelector(setState)
                          : _buildEditorModeSelector(setState),
                    ),
                    const SizedBox(height: 16),
                    _buildEditorModeToggle(setState),
                    _buildTypeSelector(setState),
                    _buildDistanceUnitSelector(setState),
                    _buildKeepNorthToggle(setState),
                    _buildAutoZoomToggle(setState),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(_loadSettings);
  }

  Widget _buildMapViewSelector(StateSetter setState) {
    return Row(
      key: const ValueKey('viewModes'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['2D', 'Auto', '3D'].map((mode) {
        return GestureDetector(
          onTap: () {
            setState(() => _updateViewMode(mode));
          },
          child: Card(
            color: _viewMode == mode ? Colors.redAccent : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                mode,
                style: TextStyle(
                  color: _viewMode == mode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditorModeSelector(StateSetter setState) {
    return Row(
      key: const ValueKey('editorChoices'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['Day', 'Night'].map((choice) {
        return GestureDetector(
          onTap: () {
            setState(() => _updateEditorMode(choice));
          },
          child: Card(
            color: _editorChoice == choice ? Colors.redAccent : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                choice,
                style: TextStyle(
                  color: _editorChoice == choice ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditorModeToggle(StateSetter setState) {
    return ListTile(
      title: const Text('Editor Mode'),
      trailing: Icon(
        _editorModeExpanded ? Icons.expand_less : Icons.expand_more,
      ),
      onTap: () {
        setState(() {
          _editorModeExpanded = !_editorModeExpanded;
        });
      },
    );
  }

  Widget _buildTypeSelector(StateSetter setState) {
    return ListTile(
      title: const Text('Type'),
      subtitle: Text(_typeChoice),
      onTap: () {
        setState(() {
          _updateType(_typeChoice == 'Default' ? 'Map editor' : 'Default');
        });
      },
    );
  }

  Widget _buildDistanceUnitSelector(StateSetter setState) {
    return ListTile(
      title: const Text('Distance Unit'),
      subtitle: Text(_distanceUnit),
      onTap: () {
        setState(() {
          _updateDistanceUnit(_distanceUnit == 'KM' ? 'Miles' : 'KM');
        });
      },
    );
  }

  Widget _buildKeepNorthToggle(StateSetter setState) {
    return SwitchListTile(
      title: const Text('Keep North'),
      value: _keepNorth,
      onChanged: (value) {
        setState(() => _updateKeepNorth(value));
      },
    );
  }

  Widget _buildAutoZoomToggle(StateSetter setState) {
    return SwitchListTile(
      title: const Text('Auto Zoom'),
      value: _autoZoom,
      onChanged: (value) {
        setState(() => _updateAutoZoom(value));
      },
    );
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    await _mapboxMap?.location.updateSettings(
      mb.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingMaxRadius: 100,
        pulsingColor: Colors.blue.value,
        puckBearingEnabled: false,
        puckBearing: mb.PuckBearing.COURSE,
      ),
    );

    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();

    await _applyViewMode();
    await _applyEditorMode();
    await _applyMapType();
    await _applyKeepNorth();
    await _applyAutoZoom();

    _centerUser();
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
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await gl.Geolocator.getCurrentPosition(
      desiredAccuracy: gl.LocationAccuracy.best,
    );
  }

  void _centerUser() async {
    try {
      final position = await _determinePosition();
      final point = mb.Point(
        coordinates: mb.Position(position.longitude, position.latitude),
      );
      _mapboxMap?.easeTo(
        mb.CameraOptions(center: point, zoom: 14.0),
        mb.MapAnimationOptions(duration: 700),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _updateBubblePosition() async {
    if (_pendingDestination == null || !_showBubble || _mapboxMap == null)
      return;

    final screenPoint = await _mapboxMap?.pixelForCoordinate(
      mb.Point(coordinates: _pendingDestination!),
    );
    if (screenPoint != null) {
      setState(() {
        _currentBubblePosition = screenPoint;
      });
    }
  }

  void _startBubbleTimer() {
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer.periodic(
      const Duration(milliseconds: 10),
      (timer) {
        if (!mounted || !_showBubble) {
          timer.cancel();
          return;
        }
        _updateBubblePosition();
      },
    );
  }

  void _stopBubbleTimer() {
    _bubbleTimer?.cancel();
    _bubbleTimer = null;
  }

  void _onMapLongPress(mb.MapContentGestureContext context) async {
    final coords = context.point.coordinates;

    await _pointAnnotationManager?.deleteAll();

    final bytes = await rootBundle.load('assets/icons/location_puck.png');
    final imageData = bytes.buffer.asUint8List();

    await _pointAnnotationManager?.create(
      mb.PointAnnotationOptions(
        geometry: mb.Point(coordinates: coords),
        image: imageData,
        iconSize: 0.5,
        iconOffset: [0.0, -15.0],
      ),
    );

    _mapboxMap?.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: coords),
        zoom: 14.0,
      ),
      mb.MapAnimationOptions(duration: 1000),
    );

    setState(() {
      _pendingDestination = coords;
      _showBubble = true;
      roadName = 'Unnamed road';
    });
    _bubbleScaleController?.reset();
    _bubbleScaleController?.forward();
    _bounceController?.forward();
    _startBubbleTimer();

    _fabSlideController?.forward();
    _mapViewSlideController?.forward();

    _bottomSheetSlideController?.forward();

    await _reverseGeocode(coords);
  }

  void _onMapTap(mb.MapContentGestureContext context) {
    _bubbleScaleController?.reverse().then((_) {
      setState(() {
        _showBubble = false;
        _pendingDestination = null;
        _currentBubblePosition = null;
        roadName = 'Unnamed road';
      });
      _stopBubbleTimer();
      _pointAnnotationManager?.deleteAll();

      _fabSlideController?.reverse();
      _mapViewSlideController?.reverse();
      _bottomSheetSlideController?.reverse();
    });
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
            endLocationName = properties['label'] ?? 'Destination';
            roadName = properties['street'] ?? 'Unnamed road';
          });
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an address to search')),
      );
      return;
    }

    final apiKey = dotenv.env['ORS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ORS API key is missing')),
      );
      return;
    }

    final url = Uri.parse(
        'https://api.openrouteservice.org/geocode/search?api_key=$apiKey&text=${Uri.encodeComponent(query)}&size=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          final coordinates = geometry['coordinates'];
          final position = mb.Position(coordinates[0], coordinates[1]);

          await _pointAnnotationManager?.deleteAll();

          final bytes = await rootBundle.load('assets/icons/location_puck.png');
          final imageData = bytes.buffer.asUint8List();

          await _pointAnnotationManager?.create(
            mb.PointAnnotationOptions(
              geometry: mb.Point(coordinates: position),
              image: imageData,
              iconSize: 0.5,
              iconOffset: [0.0, -15.0],
            ),
          );

          _mapboxMap?.easeTo(
            mb.CameraOptions(
              center: mb.Point(coordinates: position),
              zoom: 14.0,
            ),
            mb.MapAnimationOptions(duration: 1000),
          );

          setState(() {
            _pendingDestination = position;
            _showBubble = true;
            roadName = 'Unnamed road';
          });
          _bubbleScaleController?.reset();
          _bubbleScaleController?.forward();
          _bounceController?.forward();
          _startBubbleTimer();

          _fabSlideController?.forward();
          _mapViewSlideController?.forward();
          _bottomSheetSlideController?.forward();

          await _reverseGeocode(position);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found for the address')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to search address')),
        );
      }
    } catch (e) {
      print('Search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching address')),
      );
    }
  }

  void _showShareBottomSheet() {
    if (_pendingDestination == null) return;

    final shareUrl =
        'https://www.google.com/maps/search/?api=1&query=${_pendingDestination!.lat},${_pendingDestination!.lng}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Share this location: $endLocationName',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: shareUrl),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('URL copied to clipboard')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _onCameraChangeListener() {
    _updateBubblePosition();
  }

  Widget _buildSearchBottomSheet() {
    return SlideTransition(
      position: _bottomSheetSlideAnimation!,
      child: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _showSearchIcon = value.isNotEmpty;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search address...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _bottomSheetSlideController!,
                curve: Curves.easeInOut,
              )),
              child: _showSearchIcon
                  ? Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _searchAddress(_searchController.text);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              mb.MapWidget(
                key: const ValueKey("mapWidget"),
                styleUri: _typeChoice == 'Map editor'
                    ? 'mapbox://styles/mapbox/satellite-streets-v12'
                    : (_editorChoice == 'Day'
                        ? 'mapbox://styles/mapbox/navigation-day-v1'
                        : 'mapbox://styles/mapbox/navigation-night-v1'),
                mapOptions: mb.MapOptions(
                  pixelRatio: MediaQuery.of(context).devicePixelRatio,
                ),
                onMapCreated: _onMapCreated,
                onLongTapListener: _onMapLongPress,
                onTapListener: _onMapTap,
                cameraOptions: mb.CameraOptions(
                  zoom: 10.0,
                  center: mb.Point(coordinates: mb.Position(-122.084, 37.422)),
                ),
              ),
              Positioned(
                bottom: 120,
                right: 30,
                child: SlideTransition(
                  position: _fabSlideAnimation!,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 70,
                        width: 70,
                        child: FloatingActionButton(
                          elevation: 8,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(54)),
                          heroTag: 'centerUser',
                          onPressed: _centerUser,
                          child: const Icon(
                            Icons.my_location_rounded,
                            size: 38,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 220,
                right: 30,
                child: SlideTransition(
                  position: _mapViewSlideAnimation!,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 70,
                        width: 70,
                        child: FloatingActionButton(
                          elevation: 8,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(54)),
                          heroTag: 'mapView',
                          onPressed: _showMapViewModalSheet,
                          child: const Icon(
                            Icons.map_rounded,
                            size: 38,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showBubble &&
                  _pendingDestination != null &&
                  _currentBubblePosition != null)
                Positioned(
                  left: _currentBubblePosition!.x - 125,
                  top:
                      _currentBubblePosition!.y - 190 - _bounceAnimation!.value,
                  child: AnimatedBuilder(
                    animation: _bounceAnimation!,
                    builder: (context, child) {
                      return ScaleTransition(
                        scale: _bubbleScaleAnimation!,
                        child: Column(
                          children: [
                            Container(
                              width: 250,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          endLocationName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    roadName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(
                                    color: Colors.grey.withOpacity(0.3),
                                    thickness: 1,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _showShareBottomSheet,
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Colors.grey),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            minimumSize:
                                                const Size(double.infinity, 0),
                                          ),
                                          child: const Text(
                                            'Share',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (_pendingDestination != null) {
                                              setState(() {
                                                _isLoadingRoute = true;
                                              });

                                              await Future.delayed(
                                                  const Duration(seconds: 2));

                                              setState(() {
                                                _isLoadingRoute = false;
                                              });

                                              await Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context,
                                                          animation,
                                                          secondaryAnimation) =>
                                                      RouteInfoPage(
                                                    startLocation:
                                                        'Your Location',
                                                    endLocation:
                                                        endLocationName,
                                                    endPosition:
                                                        _pendingDestination!,
                                                    initialProfile:
                                                        'driving-car',
                                                  ),
                                                  transitionsBuilder: (context,
                                                      animation,
                                                      secondaryAnimation,
                                                      child) {
                                                    const begin =
                                                        Offset(1.0, 0.0);
                                                    const end = Offset.zero;
                                                    const curve =
                                                        Curves.easeInOut;

                                                    var tween = Tween(
                                                            begin: begin,
                                                            end: end)
                                                        .chain(CurveTween(
                                                            curve: curve));
                                                    var offsetAnimation =
                                                        animation.drive(tween);

                                                    return SlideTransition(
                                                      position: offsetAnimation,
                                                      child: child,
                                                    );
                                                  },
                                                  transitionDuration:
                                                      const Duration(
                                                          milliseconds: 700),
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            minimumSize:
                                                const Size(double.infinity, 0),
                                          ),
                                          child: const Text(
                                            'Routes',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            CustomPaint(
                              painter: BubbleTailPainter(),
                              child: const SizedBox(
                                width: 30,
                                height: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildSearchBottomSheet(),
              ),
              if (_isLoadingRoute)
                Container(
                  color: Colors.white.withOpacity(0.7),
                  child: Center(
                    child: SizedBox(
                      width: 60.0,
                      height: 60.0,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.redAccent),
                        strokeWidth: 6.0,
                        strokeCap: StrokeCap.round,
                        semanticsLabel: 'Route...',
                        semanticsValue: 'In progress',
                        value: null,
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

/// Painter to draw the reverse triangle (tail) at the bottom of the bubble
class BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.8), 3.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class MapSettingsPage extends StatefulWidget {
  const MapSettingsPage({super.key});

  @override
  MapSettingsPageState createState() => MapSettingsPageState();
}

class MapSettingsPageState extends State<MapSettingsPage> {
  String _mapView = 'Auto';
  bool _keepNorthUp = true;
  bool _autoZoom = true;
  String _mode = 'Day';
  String _mapType = 'Default';
  String _distanceUnit = 'KM';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mapView = prefs.getString('map_view') ?? 'Auto';
      _keepNorthUp = prefs.getBool('keep_north_up') ?? true;
      _autoZoom = prefs.getBool('auto_zoom') ?? true;
      _mode = prefs.getString('map_mode') ?? 'Day';
      _mapType = prefs.getString('map_type') ?? 'Default';
      _distanceUnit = prefs.getString('distance_unit') ?? 'KM';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_view', _mapView);
    await prefs.setBool('keep_north_up', _keepNorthUp);
    await prefs.setBool('auto_zoom', _autoZoom);
    await prefs.setString('map_mode', _mode);
    await prefs.setString('map_type', _mapType);
    await prefs.setString('distance_unit', _distanceUnit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Map Settings',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map View',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: [
                  _mapView == '3D',
                  _mapView == 'Auto',
                  _mapView == '2D',
                ],
                onPressed: (index) {
                  setState(() {
                    if (index == 0) _mapView = '3D';
                    if (index == 1) _mapView = 'Auto';
                    if (index == 2) _mapView = '2D';
                  });
                  _saveSettings();
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.redAccent,
                color: Colors.black54,
                constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
                children: const [
                  Text('3D'),
                  Text('Auto'),
                  Text('2D'),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Keep North Up',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  Switch(
                    value: _keepNorthUp,
                    activeColor: Colors.redAccent,
                    onChanged: (value) {
                      setState(() {
                        _keepNorthUp = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Auto Zoom',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  Switch(
                    value: _autoZoom,
                    activeColor: Colors.redAccent,
                    onChanged: (value) {
                      setState(() {
                        _autoZoom = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Mode',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                subtitle: Text(
                  _mode,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () async {
                  final selectedMode = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ModeSelectionPage(currentMode: _mode),
                    ),
                  );
                  if (selectedMode != null) {
                    setState(() {
                      _mode = selectedMode;
                    });
                    _saveSettings();
                  }
                },
              ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Type',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                subtitle: Text(
                  _mapType,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () async {
                  final selectedType = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TypeSelectionPage(currentType: _mapType),
                    ),
                  );
                  if (selectedType != null) {
                    setState(() {
                      _mapType = selectedType;
                    });
                    _saveSettings();
                  }
                },
              ),
              const Divider(),
              const Text(
                'Navigation Units',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'KM',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      value: 'KM',
                      groupValue: _distanceUnit,
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setState(() {
                          _distanceUnit = value!;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Miles',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      value: 'Miles',
                      groupValue: _distanceUnit,
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setState(() {
                          _distanceUnit = value!;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModeSelectionPage extends StatelessWidget {
  final String currentMode;

  const ModeSelectionPage({Key? key, required this.currentMode})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mode'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: ['Day', 'Night'].map((mode) {
          return ListTile(
            title: Text(mode),
            trailing: currentMode == mode
                ? const Icon(Icons.check)
                : const SizedBox(),
            onTap: () {
              Navigator.pop(context, mode);
            },
          );
        }).toList(),
      ),
    );
  }
}

class TypeSelectionPage extends StatelessWidget {
  final String currentType;

  const TypeSelectionPage({Key? key, required this.currentType})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Type'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: ['Default', 'Map editor'].map((type) {
          return ListTile(
            title: Text(type),
            trailing: currentType == type
                ? const Icon(Icons.check)
                : const SizedBox(),
            onTap: () {
              Navigator.pop(context, type);
            },
          );
        }).toList(),
      ),
    );
  }
}
