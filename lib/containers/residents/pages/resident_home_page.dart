// resident_home_page.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emcall/containers/residents/pages/resident_emergency_map_page.dart';
import 'package:emcall/containers/residents/pages/resident_profile_page.dart';
import 'package:emcall/containers/residents/resident_map.dart';
import 'package:emcall/pages/services/service_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Profile info
  String fullName = '';
  String? username;
  String? profileImageUrl;
  bool isNewUser = true;

  // Animation controllers and animations.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _pulseController2; // Second pulse controller
  late Animation<double> _pulseAnimation2; // Second pulse animation
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _waveController2; // Second wave controller
  late Animation<double> _waveAnimation2; // Second wave animation
  late AnimationController _waveController3; // Third wave controller
  late Animation<double> _waveAnimation3; // Third wave animation

  // For the bouncing dialog animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _isLocationPermissionGranted = false;
  // Subscription for realtime location updates.
  StreamSubscription<Position>? _positionStreamSubscription;

  // To track the selected tab in the bottom navigation bar
  int _selectedIndex = 0;
  Widget _buildNavIcon(
      IconData selectedIcon, IconData unselectedIcon, int index) {
    bool isSelected = _selectedIndex == index;
    return isSelected
        ? Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(30.0, 30.0)),
              color: Color.fromARGB(179, 255, 139, 131),
            ),
            child: Icon(
              selectedIcon,
            ),
          )
        : Icon(
            unselectedIcon,
          );
  }

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
    _loadProfileData();
    _fetchServices();
    _initUserLocation();
    _subscribeToLocationUpdates();
    _checkAndRequestLocationPermission();

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
      duration: const Duration(seconds: 2), // Same duration as the first
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
    // Start the first pulse immediately
    _pulseController.repeat(reverse: true);

    // Start the second pulse after 100ms
    Future.delayed(const Duration(milliseconds: 100), () {
      _pulseController2.repeat(reverse: true);
    });

    // Start the first wave immediately
    _waveController.repeat();

    // Start the second wave after 100ms
    Future.delayed(const Duration(milliseconds: 100), () {
      _waveController2.repeat();
    });

    // Start the third wave after 200ms (100ms after the second)
    Future.delayed(const Duration(milliseconds: 200), () {
      _waveController3.repeat();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pulseController2.dispose(); // Dispose of the second pulse controller
    _waveController.dispose();
    _waveController2.dispose(); // Dispose of the second wave controller
    _waveController3.dispose(); // Dispose of the third wave controller
    _bounceController.dispose(); // Dispose of the bounce controller
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Check if the user is new by looking at SharedPreferences
  Future<void> _checkIfNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isNew = prefs.getBool('isNewUser');
    if (isNew == null || isNew) {
      setState(() {
        isNewUser = true;
      });
      await prefs.setBool('isNewUser', false);
    } else {
      setState(() {
        isNewUser = false;
      });
    }
  }

  // Check and request location permission, show dialog if not granted
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

    setState(() {
      _isLocationPermissionGranted = true;
    });
    _initUserLocation();
    _subscribeToLocationUpdates();
  }

  // Show a persistent dialog with bouncing animation
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
                              setState(() {
                                _isLocationPermissionGranted = true;
                              });
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
    String? email = prefs.getString('personal_email');

    if (email == null) {
      if (kDebugMode) {
        print("Error: No 'personal_email' found in SharedPreferences.");
      }
      setState(() => fullName =
          '${widget.firstName} ${widget.middleName}. ${widget.lastName} ${widget.suffix}');
      return;
    }

    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('residents')
          .select(
              'id, first_name, middle_name, last_name, suffix_name, profile_image, address, location_id, username')
          .eq('personal_email', email)
          .maybeSingle();

      if (response == null) {
        if (kDebugMode) {
          print("No resident found with email: $email");
        }
        setState(() => fullName =
            '${widget.firstName} ${widget.middleName[0]}. ${widget.lastName} ${widget.suffix}');
        return;
      }

      String firstName = response['first_name'] ?? '';
      String middleName = response['middle_name'] ?? '';
      String lastName = response['last_name'] ?? '';
      String suffix = response['suffix_name'] ?? '';
      userAddress = response['address'] ?? '';
      userLocationId = response['location_id'];
      profileImageUrl = response['profile_image'];
      username = response['username'] ?? '';

      String computedName = firstName;
      if (middleName.isNotEmpty) computedName += ' ${middleName[0]}.';
      computedName += ' $lastName';
      if (suffix.isNotEmpty) computedName += ' $suffix';

      setState(() {
        fullName = computedName.trim();
        userAddress = response['address'];
        final rawImageUrl = response['profile_image']?.toString() ?? '';
        profileImageUrl = rawImageUrl.isNotEmpty
            ? rawImageUrl.startsWith('http')
                ? rawImageUrl
                : 'https://$rawImageUrl'
            : null;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading profile data: $e");
      }
      setState(() => fullName =
          '${widget.firstName} ${widget.middleName[0]}. ${widget.lastName} ${widget.suffix}');
    }
  }

  Future<void> _recordServiceCall(ServiceInfo service) async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    int? residentId = prefs.getInt('resident_id');
    if (residentId == null) {
      if (kDebugMode) {
        print("Resident ID not found!");
      }
      return;
    }

    if (service.id == null) {
      if (kDebugMode) {
        print("Service id is null");
      }
    } else {
      if (kDebugMode) {
        print("Recording service call for service id: ${service.id}");
      }
    }

    final response = await supabase.from('service_calls').insert({
      'resident_id': residentId,
      'service_type': service.serviceType.toLowerCase(),
      'service_id': service.id,
      'shared_location': true,
    }).maybeSingle();

    if (response == null) {
      if (kDebugMode) {
        print('Insert error: $response');
      }
    } else {
      if (kDebugMode) {
        print('Service call recorded successfully: $response');
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
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ));
      setState(() {
        currentPosition = position;
      });
      final address =
          await _reverseGeocode(position.latitude, position.longitude);
      setState(() {
        _currentAddress = address;
      });
      await _saveOrUpdateLocation(
          position.latitude, position.longitude, address);
    } catch (e) {
      if (kDebugMode) {
        print("Error getting location: $e");
      }
    }
  }

  void _subscribeToLocationUpdates() {
    DateTime lastUpdate = DateTime.now();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        timeLimit: null,
      ),
    ).listen((Position position) async {
      String address =
          await _reverseGeocode(position.latitude, position.longitude);
      setState(() {
        currentPosition = position;
        _currentAddress = address;
      });
      if (DateTime.now().difference(lastUpdate).inMilliseconds >= 500) {
        await _saveOrUpdateLocation(
            position.latitude, position.longitude, address);
        lastUpdate = DateTime.now();
      }
    }, onError: (e) {
      if (kDebugMode) {
        print("Location stream error: $e");
      }
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
      if (kDebugMode) {
        print("Reverse geocode error: $e");
      }
    }
    return 'Unknown location';
  }

  Future<void> _saveOrUpdateLocation(
      double lat, double lng, String address) async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('personal_email');

    try {
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
        setState(() {
          userLocationId = response['id'];
        });
        if (email != null) {
          await supabase.from('residents').update(
              {'location_id': userLocationId}).eq('personal_email', email);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error saving location: $e");
      }
    }
  }

  Future<void> _fetchServices() async {
    final supabase = Supabase.instance.client;
    try {
      final policeResponse = await supabase
          .from('police')
          .select('public_org_name, hotline_phone_number');
      for (var item in policeResponse) {
        _services.add(
          ServiceInfo(
            'Police',
            orgName: item['public_org_name'] ?? 'Police Department',
            hotlineNumber: item['hotline_phone_number'] ?? '',
          ),
        );
      }
      final rescueResponse = await supabase
          .from('rescue')
          .select('public_org_name, hotline_phone_number');
      for (var item in rescueResponse) {
        _services.add(
          ServiceInfo(
            'Rescue',
            orgName: item['public_org_name'] ?? 'Rescue Team',
            hotlineNumber: item['hotline_phone_number'] ?? '',
          ),
        );
      }
      final firefighterResponse = await supabase
          .from('firefighter')
          .select('public_org_name, hotline_phone_number');
      for (var item in firefighterResponse) {
        _services.add(
          ServiceInfo(
            'Firefighter',
            orgName: item['public_org_name'] ?? 'Fire Department',
            hotlineNumber: item['hotline_phone_number'] ?? '',
          ),
        );
      }
      final disasterResponse = await supabase
          .from('disaster_responders')
          .select('public_org_name, hotline_phone_number');
      for (var item in disasterResponse) {
        _services.add(
          ServiceInfo(
            'Disaster',
            orgName: item['public_org_name'] ?? 'Disaster Responders',
            hotlineNumber: item['hotline_phone_number'] ?? '',
          ),
        );
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Failed to load emergency services. Please check connection'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _fetchServices,
          ),
        ),
      );
    }
  }

  Future<void> _launchCaller(String number) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch call to $number')),
      );
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
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Press the button below and help will reach you shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontFamily: 'RobotoMono',
            ),
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
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: Text(
                    _currentAddress ?? 'Detecting location...',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Your current address'),
                  trailing: const Icon(Icons.map),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ResidentMap()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you in an Emergency?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a service to call or view your location on the map',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _services.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return Card(
                            child: InkWell(
                              onTap: () async {
                                if (service.hotlineNumber.isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('No hotline number available'),
                                    backgroundColor: Colors.red,
                                  ));
                                  return;
                                }
                                await _showCustomCallDialog(service);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone, color: Colors.red),
                                    const SizedBox(height: 8),
                                    Text(
                                      service.orgName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      service.serviceType,
                                      style:
                                          const TextStyle(color: Colors.grey),
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
          ),
        );
      },
    );
  }

  // Handle bottom navigation bar taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Map tab

        break;
      case 1: // Call Emergency tab

        break;
      case 2: // Basic First Aid Tutorials tab

        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          // First wave animation (outermost ripple effect)
                          AnimatedBuilder(
                            animation: _waveAnimation,
                            builder: (context, child) {
                              double size = 100 + (_waveAnimation.value * 200);
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withOpacity(1.0 - _waveAnimation.value),
                                ),
                              );
                            },
                          ),
                          // Second wave animation (slightly delayed)
                          AnimatedBuilder(
                            animation: _waveAnimation2,
                            builder: (context, child) {
                              double size = 125 + (_waveAnimation2.value * 200);
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withOpacity(1.0 - _waveAnimation2.value),
                                ),
                              );
                            },
                          ),
                          // Third wave animation (delayed further)
                          AnimatedBuilder(
                            animation: _waveAnimation3,
                            builder: (context, child) {
                              double size = 150 + (_waveAnimation3.value * 200);
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withOpacity(1.0 - _waveAnimation3.value),
                                ),
                              );
                            },
                          ),
                          // Second pulse animation (slightly larger)
                          ScaleTransition(
                            scale: _pulseAnimation2,
                            child: Container(
                              width:
                                  175, // Slightly larger than the main button
                              height: 175,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white
                                    .withOpacity(0.2), // Semi-transparent
                              ),
                            ),
                          ),
                          // First pulse animation (innermost)
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 150, // Main button size
                              height: 150,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.phone,
                                  size: 70,
                                  color: Colors.redAccent,
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
              Container(
                color: Colors.grey.withOpacity(0.5),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.only(
              top: 0.0, right: 0.0, left: 0.0, bottom: 12.0),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(
                      top: 0.0, right: 4.0, left: 4.0, bottom: 6.0),
                  child:
                      _buildNavIcon(Icons.map_rounded, Icons.map_outlined, 0),
                ),
                label: 'Emcall Map',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(
                      top: 0.0, right: 4.0, left: 4.0, bottom: 6.0),
                  child: _buildNavIcon(
                      Icons.phone_rounded, Icons.phone_outlined, 1),
                ),
                label: 'Call Emergency',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(
                      top: 0.0, right: 4.0, left: 4.0, bottom: 6.0),
                  child: _buildNavIcon(Icons.medical_services_rounded,
                      Icons.medical_services_outlined, 2),
                ),
                label: 'First Aid',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            backgroundColor: Colors.white,
            selectedIconTheme:
                const IconThemeData(size: 26, color: Colors.black),
            unselectedIconTheme:
                const IconThemeData(size: 24, color: Colors.black),
            showUnselectedLabels: true,
            elevation: 0.0,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Colors.redAccent,
      ),
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
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'RobotoMono',
                    color: Colors.white,
                  ),
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
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              ).then((_) {
                _loadProfileData();
              });
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
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.red,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.red,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomCallDialog(ServiceInfo service) async {
    Timer? countdownTimer;
    int secondsRemaining = 59;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            void startTimer() {
              countdownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                if (secondsRemaining <= 0) {
                  timer.cancel();
                  Navigator.of(dialogContext).pop();
                  _launchCaller(service.hotlineNumber);
                } else {
                  setState(() {
                    secondsRemaining--;
                  });
                }
              });
            }

            if (countdownTimer == null) {
              startTimer();
            }
            return Dialog(
              backgroundColor: Colors.white,
              elevation: 0,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 60),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            'Emergency Help Needed?',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Gilroy',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${service.orgName} is always ready to help you!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.grey.shade400, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            child: Text(
                              '${secondsRemaining}s',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                countdownTimer?.cancel();
                                Navigator.pop(dialogContext);
                              },
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.grey[800],
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.red, size: 32),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                countdownTimer?.cancel();
                                await _recordServiceCall(service);
                                _launchCaller(service.hotlineNumber);
                                Navigator.of(dialogContext).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ResidentEmergencyMapPage(
                                      initialPosition: currentPosition,
                                      serviceType:
                                          service.serviceType.toLowerCase(),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.grey[800],
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.green, size: 32),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.blueGrey,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blueGrey,
                      child: Icon(Icons.phone, color: Colors.white, size: 48),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
    });
  }
}

// Placeholder page for Basic First Aid Tutorials
class BasicFirstAidTutorialsPage extends StatelessWidget {
  const BasicFirstAidTutorialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic First Aid Tutorials'),
        backgroundColor: Colors.redAccent,
      ),
      body: const Center(
        child: Text(
          'Basic First Aid Tutorials Page\n(Placeholder)',
          style: TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
