// resident_home_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/containers/residents/pages/home_navigation_page.dart';
import 'package:emcall/containers/residents/pages/resident_emergency_map_page.dart';
import 'package:emcall/containers/residents/pages/resident_profile_page.dart';
import 'package:emcall/pages/services/service_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentHomePage extends StatefulWidget {
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String? address;

  const ResidentHomePage({
    super.key,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    this.address,
  });

  @override
  ResidentHomePageState createState() => ResidentHomePageState();
}

class ResidentHomePageState extends State<ResidentHomePage>
    with TickerProviderStateMixin {
  final List<ServiceInfo> _services = [];
  Position? currentPosition;
  String? _currentAddress;
  String? userAddress;

  // For storing the location record ID from the locations table.
  int? userLocationId;
  StreamSubscription<List<Map<String, dynamic>>>? _locationSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isSubscriptionSetUp = false;
  final int selectedIndex = 0;

  // Profile info
  String fullName = '';
  String? username;
  String? profileImageUrl;
  bool isNewUser = true;
  int? residentId;

  // Animation controllers and animations.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _pulseController2;
  late Animation<double> _pulseAnimation2;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _waveController2;
  late Animation<double> _waveAnimation2;
  late AnimationController _waveController3;
  late Animation<double> _waveAnimation3;

  // For the bouncing dialog animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _isLocationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
    _loadProfileData();
    _fetchServices();
    _initUserLocation();
    _subscribeToLocationUpdates();
    _checkAndRequestLocationPermission();

    // Check resident_id in SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final email = prefs.getString('personal_email');
      residentId = prefs.getInt('resident_id');
      if (kDebugMode) {
        print(
            'SharedPreferences personal_email: $email, resident_id: $residentId');
      }
      if (email == null && residentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No user session found. Please log in again.')),
        );
        // Optionally redirect to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    });

    Future.wait([_loadProfileData(), _initUserLocation()]).then((_) {
      if (userLocationId != null && !_isSubscriptionSetUp) {
        _setupLocationSubscription();
        _isSubscriptionSetUp = true;
      }
    });
    _subscribeToLocationUpdates();
    // First pulse animation for the SOS button.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Second pulse animation (slightly larger).
    _pulseController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation2 = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController2, curve: Curves.easeInOut),
    );

    // First wave animation for the expanding ripple effect.
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    // Second wave animation (slightly delayed).
    _waveController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _waveAnimation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController2, curve: Curves.easeOut),
    );

    // Third wave animation (delayed further).
    _waveController3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _waveAnimation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController3, curve: Curves.easeOut),
    );

    // Bouncing animation for the dialog
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Start the animations with a 100ms delay between each
    _startAnimations();
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 100), () {
      _pulseController2.repeat(reverse: true);
    });
    _waveController.repeat();
    Future.delayed(const Duration(milliseconds: 100), () {
      _waveController2.repeat();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _waveController3.repeat();
    });
  }

  @override
  void dispose() {
// Stop and dispose all animation controllers
    _pulseController.stop();
    _pulseController.dispose();
    _pulseController2.stop();
    _pulseController2.dispose();
    _waveController.stop();
    _waveController.dispose();
    _waveController2.stop();
    _waveController2.dispose();
    _waveController3.stop();
    _waveController3.dispose();
    _bounceController.stop();
    _bounceController.dispose();
    _locationSubscription?.cancel(); // Cancel the Supabase subscription
    _positionStreamSubscription?.cancel(); // Cancel the position stream
    // Cancel the location stream subscription
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

// Method to set up the real-time subscription to the locations table
  void _setupLocationSubscription() {
    _locationSubscription = Supabase.instance.client
        .from('locations')
        .stream(primaryKey: ['id'])
        .eq('id', userLocationId!)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty && mounted) {
            final location = data.first;
            setState(() {
              currentPosition = Position(
                latitude: location['latitude'],
                longitude: location['longitude'],
                timestamp:
                    DateTime.now(), // Placeholder, adjust if timestamp is in DB
                accuracy: 0.0, // Placeholder, adjust as needed
                altitude: 0.0,
                altitudeAccuracy: 0.0, // Placeholder, adjust as needed
                heading: 0.0,
                headingAccuracy: 0.0, // Placeholder, adjust as needed
                speed: 0.0,
                speedAccuracy: 0.0,
              );
              _currentAddress = location['address'];
            });
          }
        });
  }

  Future<void> _checkIfNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isNew = prefs.getBool('isNewUser');
    if (mounted) {
      // Check if widget is still mounted
      setState(() {
        isNewUser = isNew == null || isNew;
      });
    }
    await prefs.setBool('isNewUser', false);
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationPermissionDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showLocationPermissionDialog();
      return;
    }

    setState(() => _isLocationPermissionGranted = true);
    _initUserLocation();
    _subscribeToLocationUpdates();
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Location Permission Required',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'In order to use this app properly, please enable your location permission.',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            bool serviceEnabled =
                                await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              await Geolocator.openLocationSettings();
                              return;
                            }

                            LocationPermission permission =
                                await Geolocator.requestPermission();
                            if (permission ==
                                LocationPermission.deniedForever) {
                              await Geolocator.openAppSettings();
                              return;
                            }

                            if (permission == LocationPermission.whileInUse ||
                                permission == LocationPermission.always) {
                              setState(
                                  () => _isLocationPermissionGranted = true);
                              Navigator.of(dialogContext).pop();
                              _initUserLocation();
                              _subscribeToLocationUpdates();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.redAccent,
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('personal_email');
    residentId = prefs.getInt('resident_id');

    // Prefer resident_id if available
    final supabase = Supabase.instance.client;
    try {
      Map<String, dynamic>? response;
      if (residentId != null) {
        response = await supabase
            .from('residents')
            .select(
                'id, first_name, middle_name, last_name, suffix_name, profile_image, address, location_id, username')
            .eq('id', residentId!)
            .maybeSingle();
      } else if (email != null) {
        response = await supabase
            .from('residents')
            .select(
                'id, first_name, middle_name, last_name, suffix_name, profile_image, address, location_id, username')
            .eq('personal_email', email)
            .maybeSingle();
      } else {
        throw Exception('No resident_id or personal_email found');
      }

      if (kDebugMode) {
        print('Supabase response: $response');
      }

      if (response == null) {
        if (kDebugMode) {
          print(
              'No resident found with ${residentId != null ? 'resident_id: $residentId' : 'email: $email'}');
        }
        if (mounted) {
          setState(() {
            fullName =
                '${widget.firstName} ${widget.middleName.isNotEmpty ? widget.middleName[0] + '.' : ''} ${widget.lastName} ${widget.suffix}';
            username = widget.firstName;
            profileImageUrl = null;
            userAddress = widget.address;
          });
        }
        return;
      }

      String firstName = response['first_name'] ?? widget.firstName;
      String middleName = response['middle_name'] ?? widget.middleName;
      String lastName = response['last_name'] ?? widget.lastName;
      String suffix = response['suffix_name'] ?? widget.suffix;
      userAddress = response['address'] ?? widget.address;
      userLocationId = response['location_id'];
      profileImageUrl = response['profile_image'];
      username = response['username'] ?? firstName;
      residentId = response['id']; // Store residentId for future queries

      String computedName = firstName;
      if (middleName.isNotEmpty) computedName += ' ${middleName[0]}.';
      computedName += ' $lastName';
      if (suffix.isNotEmpty) computedName += ' $suffix';

      if (mounted) {
        setState(() {
          fullName = computedName.trim();
          userAddress = response?['address'] ?? widget.address;
          profileImageUrl = response?['profile_image']?.toString();
          username = response?['username'] ?? firstName;
          if (kDebugMode) {
            print('Processed profileImageUrl: $profileImageUrl');
          }
        });
        // Save resident_id to SharedPreferences
        if (residentId != null) {
          prefs.setInt('resident_id', residentId!);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error loading profile data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load profile data'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadProfileData,
            ),
          ),
        );
        setState(() {
          fullName =
              '${widget.firstName} ${widget.middleName.isNotEmpty ? widget.middleName[0] + '.' : ''} ${widget.lastName} ${widget.suffix}';
          username = widget.firstName;
          profileImageUrl = null;
          userAddress = widget.address;
        });
      }
    }
  }

  Future<void> _initUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best, distanceFilter: 2));
      if (mounted) {
        // Check if widget is still mounted
        setState(() => currentPosition = position);
      }
      final address =
          await _reverseGeocode(position.latitude, position.longitude);
      if (mounted) {
        // Check if widget is still mounted
        setState(() => _currentAddress = address);
      }
      await _saveOrUpdateLocation(
          position.latitude, position.longitude, address);
    } catch (e) {
      if (kDebugMode) print("Error getting location: $e");
    }
  }

  void _subscribeToLocationUpdates() {
    DateTime lastUpdate = DateTime.now();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Trigger updates only after 5 meters of movement
      ),
    ).listen((Position position) async {
      String address =
          await _reverseGeocode(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          currentPosition = position;
          _currentAddress = address;
        });
      }
      // Update database only if 1 second has passed since the last update
      if (DateTime.now().difference(lastUpdate).inSeconds >= 1) {
        await _saveOrUpdateLocation(
            position.latitude, position.longitude, address);
        lastUpdate = DateTime.now();
      }
    }, onError: (e) {
      if (kDebugMode) print("Location stream error: $e");
    });
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final mapboxAccessToken = dotenv.env["MAPBOX_ACCESS_TOKEN"] ?? "";
    final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$mapboxAccessToken');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          return features[0]['place_name'] ?? 'Unknown location';
        }
      }
    } catch (e) {
      if (kDebugMode) print("Reverse geocode error: $e");
    }
    return 'Unknown location';
  }

  Future<void> _saveOrUpdateLocation(
      double lat, double lng, String address) async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('personal_email');

    try {
      // Retrieve the resident's ID using the email
      final residentResponse = await supabase
          .from('residents')
          .select('id')
          .eq('personal_email', email!)
          .single();

      final residentId = residentResponse['id'];

      if (residentId == null) {
        if (kDebugMode) print("Error: Resident ID not found for email: $email");
        return;
      }

      // Update or insert the location
      if (userLocationId != null) {
        await supabase.from('locations').update({
          'latitude': lat,
          'longitude': lng,
          'address': address,
        }).eq('id', userLocationId!);
      } else {
        final response = await supabase
            .from('locations')
            .insert({
              'latitude': lat,
              'longitude': lng,
              'address': address,
            })
            .select()
            .single();
        setState(() => userLocationId = response['id']);
      }

      // Update the resident's location_id using the resident's ID
      await supabase.from('residents').update({
        'location_id': userLocationId,
      }).eq('id', residentId);

      // Set up subscription if not already done
      if (!_isSubscriptionSetUp) {
        _setupLocationSubscription();
        _isSubscriptionSetUp = true;
      }
    } catch (e) {
      if (kDebugMode) print("Error saving location: $e");
    }
  }

  Future<void> _fetchServices() async {
    final supabase = Supabase.instance.client;
    try {
      // Fetch police services
      final policeResponse = await supabase.from('police').select(
          'id, public_org_name, address, hotline_phone_number, gmail_org_account, locations!inner(latitude, longitude)');
      for (var item in policeResponse) {
        _services.add(ServiceInfo(
          serviceType: 'Police',
          id: item['id'],
          orgName: item['public_org_name'] ?? 'Police Department',
          address: item['address'] ?? '',
          hotlineNumber: item['hotline_phone_number'] ?? '',
          email: item['gmail_org_account'] ?? '',
          latitude: item['locations']['latitude'] as double,
          longitude: item['locations']['longitude'] as double,
        ));
      }

      // Repeat for rescue, firefighter, disaster_responders with similar structure
      final rescueResponse = await supabase.from('rescue').select(
          'id, public_org_name, address, hotline_phone_number, gmail_org_account, locations!inner(latitude, longitude)');
      for (var item in rescueResponse) {
        _services.add(ServiceInfo(
          serviceType: 'Rescue',
          id: item['id'],
          orgName: item['public_org_name'] ?? 'Rescue Team',
          address: item['address'] ?? '',
          hotlineNumber: item['hotline_phone_number'] ?? '',
          email: item['gmail_org_account'] ?? '',
          latitude: item['locations']['latitude'] as double,
          longitude: item['locations']['longitude'] as double,
        ));
      }
      // Fetch firefighter services
      final firefighterResponse = await supabase.from('firefighter').select(
          'id, public_org_name, address, hotline_phone_number, gmail_org_account, locations!inner(latitude, longitude)');
      for (var item in firefighterResponse) {
        _services.add(ServiceInfo(
          serviceType: 'Firefighter',
          id: item['id'],
          orgName: item['public_org_name'] ?? 'Firefighter Department',
          address: item['address'] ?? '',
          hotlineNumber: item['hotline_phone_number'] ?? '',
          email: item['gmail_org_account'] ?? '',
          latitude: item['locations']['latitude'] as double,
          longitude: item['locations']['longitude'] as double,
        ));
      }

      // disaster_responders
      final disasterResponse = await supabase.from('disaster_responders').select(
          'id, public_org_name, address, hotline_phone_number, gmail_org_account, locations!inner(latitude, longitude)');
      for (var item in disasterResponse) {
        _services.add(ServiceInfo(
          serviceType: 'Disaster',
          id: item['id'],
          orgName: item['public_org_name'] ?? 'Disaster Responders',
          address: item['address'] ?? '',
          hotlineNumber: item['hotline_phone_number'] ?? '',
          email: item['gmail_org_account'] ?? '',
          latitude: item['locations']['latitude'] as double,
          longitude: item['locations']['longitude'] as double,
        ));
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Failed to load emergency services. Please check connection'),
            action: SnackBarAction(label: 'Retry', onPressed: _fetchServices),
          ),
        );
      }
    }
  }

  Widget _buildInstructionsSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          Text(
            'Are you in an Emergency?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy',
                color: Colors.white),
          ),
          SizedBox(height: 14),
          Text(
            'Press the button below and help will reach you shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, color: Colors.white, fontFamily: 'RobotoMono'),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showEmergencySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(width: 1, color: Colors.grey),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/map_background.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      _currentAddress ?? 'Detecting location...',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Your current address'),
                    trailing: Image.asset(
                      'assets/images/map.png',
                      width: 56,
                      height: 56,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.map, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeNavigationPage(
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Are you in an Emergency?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Select a service to call or view your location on the map',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Expanded(
                child: _services.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          String imageAsset;
                          switch (service.serviceType.toLowerCase()) {
                            case 'police':
                              imageAsset = 'assets/images/police.png';
                              break;
                            case 'rescue':
                              imageAsset = 'assets/images/rescue.png';
                              break;
                            case 'firefighter':
                              imageAsset = 'assets/images/firefighter.png';
                              break;
                            case 'disaster':
                              imageAsset =
                                  'assets/images/disaster_responders.png';
                              break;
                            default:
                              imageAsset = 'assets/images/default.png';
                          }

                          return Card(
                            elevation: 0,
                            color: const Color.fromARGB(65, 255, 134, 134),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: const BorderSide(
                                    width: 1, color: Colors.redAccent)),
                            child: InkWell(
                              onTap: () {
                                if (service.hotlineNumber.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('No hotline number available'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation,
                                            secondaryAnimation) =>
                                        ResidentEmergencyMapPage(
                                      service: service,
                                      initialPosition: currentPosition,
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
                                          child: child);
                                    },
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      imageAsset,
                                      width: 80,
                                      height: 80,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.phone,
                                                  color: Colors.red, size: 80),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      service.orgName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 20,
                                          fontFamily: 'Gilroy'),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.redAccent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildCustomHeader(),
                  _buildInstructionsSection(),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _isLocationPermissionGranted
                            ? _showEmergencySheet
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _waveAnimation,
                              builder: (context, child) {
                                double size =
                                    100 + (_waveAnimation.value * 200);
                                return Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(
                                        1.0 - _waveAnimation.value),
                                  ),
                                );
                              },
                            ),
                            AnimatedBuilder(
                              animation: _waveAnimation2,
                              builder: (context, child) {
                                double size =
                                    125 + (_waveAnimation2.value * 200);
                                return Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(
                                        1.0 - _waveAnimation2.value),
                                  ),
                                );
                              },
                            ),
                            AnimatedBuilder(
                              animation: _waveAnimation3,
                              builder: (context, child) {
                                double size =
                                    150 + (_waveAnimation3.value * 200);
                                return Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(
                                        1.0 - _waveAnimation3.value),
                                  ),
                                );
                              },
                            ),
                            ScaleTransition(
                              scale: _pulseAnimation2,
                              child: Container(
                                width: 175,
                                height: 175,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                            ),
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white),
                                child: const Center(
                                  child: Text(
                                    'EmCall',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
              if (!_isLocationPermissionGranted)
                Container(color: Colors.grey.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(color: Colors.redAccent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isNewUser ? 'Hello!' : 'Welcome back!',
                  style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'RobotoMono',
                      color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  username ?? 'Loading...',
                  style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'RobotoMono',
                      color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const ResidentProfilePage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                        position: offsetAnimation, child: child);
                  },
                ),
              ).then((_) => _loadProfileData());
            },
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white38,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                child: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: profileImageUrl!,
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                                image: imageProvider, fit: BoxFit.cover),
                          ),
                        ),
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.red),
                      )
                    : const Icon(Icons.person, size: 40, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
