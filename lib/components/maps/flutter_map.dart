// // ignore_for_file: use_build_context_synchronously, unused_element, library_private_types_in_public_api, deprecated_member_use

// import 'dart:async';
// import 'dart:convert';
// import 'dart:ui' as ui;
// import 'package:emcall/components/maps/route_info_page.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart' as gl;
// import 'package:http/http.dart' as http;
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class FullMap extends StatefulWidget {
//   const FullMap({super.key});

//   @override
//   State<FullMap> createState() => _FullMapState();
// }

// class EmergencyOrganization {
//   final int id;
//   final String name;
//   final String serviceType;
//   final String profileImageUrl;

//   EmergencyOrganization({
//     required this.id,
//     required this.name,
//     required this.serviceType,
//     required this.profileImageUrl,
//   });
// }

// class EmergencyOrganizationsBottomSheet extends StatefulWidget {
//   const EmergencyOrganizationsBottomSheet({super.key});

//   @override
//   _EmergencyOrganizationsBottomSheetState createState() =>
//       _EmergencyOrganizationsBottomSheetState();
// }

// class _EmergencyOrganizationsBottomSheetState
//     extends State<EmergencyOrganizationsBottomSheet> {
//   late Future<Map<String, List<EmergencyOrganization>>> _futureGroupedOrgs;

//   @override
//   void initState() {
//     super.initState();
//     _futureGroupedOrgs = _fetchEmergencyOrganizations();
//   }

//   Future<Map<String, List<EmergencyOrganization>>>
//       _fetchEmergencyOrganizations() async {
//     const serviceTypes = [
//       'police',
//       'rescue',
//       'firefighter',
//       'disaster_responder'
//     ];
//     final futures = serviceTypes
//         .map((type) => _fetchOrganizationsWithWorkers(type))
//         .toList();
//     final results = await Future.wait(futures);
//     final allOrgs = results.expand((x) => x).toList();
//     final groupedOrgs = <String, List<EmergencyOrganization>>{};
//     for (var org in allOrgs) {
//       groupedOrgs.putIfAbsent(org.serviceType, () => []).add(org);
//     }
//     return groupedOrgs;
//   }

//   Future<List<EmergencyOrganization>> _fetchOrganizationsWithWorkers(
//       String serviceType) async {
//     final orgsResponse = await Supabase.instance.client
//         .from(serviceType == 'disaster_responder'
//             ? 'disaster_responders'
//             : serviceType)
//         .select('id, public_org_name');
//     final orgs = orgsResponse as List<dynamic>;
//     final emergencyOrgs = <EmergencyOrganization>[];

//     for (var org in orgs) {
//       final workersResponse = await Supabase.instance.client
//           .from('workers')
//           .select('profile_image')
//           .eq('organization_type', serviceType)
//           .eq('organization_id', org['id'])
//           .limit(1);
//       String profileImageUrl = workersResponse.isNotEmpty &&
//               workersResponse[0]['profile_image'] != null
//           ? workersResponse[0]['profile_image']
//           : '';
//       emergencyOrgs.add(EmergencyOrganization(
//         id: org['id'],
//         name: org['public_org_name'],
//         serviceType: serviceType,
//         profileImageUrl: profileImageUrl,
//       ));
//     }
//     return emergencyOrgs;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: FutureBuilder<Map<String, List<EmergencyOrganization>>>(
//         future: _futureGroupedOrgs,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return const Center(child: Text('Error fetching organizations'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text('No organizations found'));
//           } else {
//             final groupedOrgs = snapshot.data!;
//             return ListView(
//               children: groupedOrgs.entries.map((entry) {
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(entry.key.toUpperCase(),
//                         style: const TextStyle(
//                             fontSize: 18, fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 8),
//                     SizedBox(
//                       height: 80,
//                       child: ListView.builder(
//                         scrollDirection: Axis.horizontal,
//                         itemCount: entry.value.length,
//                         itemBuilder: (context, index) {
//                           final org = entry.value[index];
//                           return Padding(
//                             padding: const EdgeInsets.only(right: 8.0),
//                             child: CircleAvatar(
//                               radius: 30,
//                               backgroundImage: org.profileImageUrl.isNotEmpty
//                                   ? NetworkImage(org.profileImageUrl)
//                                   : null,
//                               child: org.profileImageUrl.isEmpty
//                                   ? const Icon(Icons.business)
//                                   : null,
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                   ],
//                 );
//               }).toList(),
//             );
//           }
//         },
//       ),
//     );
//   }
// }

// class _FullMapState extends State<FullMap> with TickerProviderStateMixin {
//   mp.MapboxMap? mapboxMap;
//   mp.PointAnnotationManager? pointAnnotationManager;
//   mp.PolylineAnnotationManager? polylineAnnotationManager;
//   Uint8List? hqMarkerImage;
//   StreamSubscription<gl.Position>? usersPositionStream;
//   String? destinationRegionName;
//   String? destinationRoadName;
//   bool _isInitialGeocodingDone = false;

//   mp.Position? userPosition;
//   mp.Position? destinationPosition;
//   bool _isCameraCentered = false;
//   List<mp.Position> routeCoordinates = [];
//   bool hasDestination = false;
//   bool isFollowingUser = false;
//   bool showRoutePanel = false;
//   bool _hasAnimatedRoute = false;
//   bool _routeConfirmed = false;
//   bool isNavigationActive = false;
//   bool _isLoadingRoute = false;

//   double? userBearing;
//   Uint8List? userLocationImage;
//   bool isPitchEnabled = false;
//   bool _isNavigationPuckActive = false;

//   String startLocationName = 'Your Location';
//   String endLocationName = 'Destination';
//   double? routeDistance;
//   double? routeDuration;
//   double? averageSpeed;

//   String selectedProfile = 'driving-car';
//   final Map<String, IconData> routeProfiles = {
//     'driving-car': Icons.local_taxi,
//     'cycling-regular': Icons.pedal_bike,
//     'foot-walking': Icons.hiking,
//   };
//   final Map<String, Color> routeColors = {
//     'driving-car': Colors.indigo,
//     'cycling-regular': Colors.teal,
//     'foot-walking': Colors.deepOrange,
//   };

//   static const String orsBaseUrl =
//       'https://api.openrouteservice.org/v2/directions';
//   static const String orsApiKey =
//       '5b3ce3597851110001cf6248f55d7a31499e40848c6848d7de8fa624';

//   AnimationController? controller;
//   Animation<double>? animation;
//   AnimationController? _bounceController;
//   Animation<double>? _bounceAnimation;
//   AnimationController? _bubbleScaleController;
//   Animation<double>? _bubbleScaleAnimation;

//   bool showRouteProfiles = true;
//   bool showNavigationInfoPanel = false;
//   bool _showBubble = false;
//   bool _isBottomSheetOpen = false;
//   bool _isLoadingRoutesInBubble = false;

//   Timer? _positionUpdateTimer;
//   mp.ScreenCoordinate? _currentBubblePosition;
//   bool _isToggling = false;
//   String viaText = 'Via bridge QUEZON';

//   String _mapView = 'Auto'; // Options: '3D', 'Auto', '2D'
//   String _mode =
//       'Default'; // Options: 'Off', 'Night', 'Day', 'Same as Phone Settings'
//   String _mapType = 'Default'; // Options: 'Default', 'Map Editors'
//   bool _keepNorthUp = true;
//   bool _autoZoom = true;
//   double _lastZoomLevel = 16.0; // Track last zoom level for auto-zoom

//   // Animation controller for sliding pages in the bottom sheet
//   late AnimationController _slideController;
//   late Animation<Offset> _slideAnimation;

//   // State for managing bottom sheet pages
//   int _currentPage = 0; // 0: Main, 1: Mode, 2: Type

//   @override
//   void initState() {
//     super.initState();
//     _requestLocationPermission();
//     _loadSettings();

//     _bounceController = AnimationController(
//         duration: const Duration(milliseconds: 1000), vsync: this)
//       ..repeat(reverse: true);
//     _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
//         CurvedAnimation(parent: _bounceController!, curve: Curves.easeInOut));

//     _bubbleScaleController = AnimationController(
//         duration: const Duration(milliseconds: 500), vsync: this);
//     _bubbleScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//         CurvedAnimation(
//             parent: _bubbleScaleController!, curve: Curves.easeInOut));

//     _positionUpdateTimer =
//         Timer.periodic(const Duration(milliseconds: 10), (timer) {
//       if (_showBubble && destinationPosition != null && mapboxMap != null) {
//         _updateBubblePosition();
//       }
//     });

//     // Initialize slide animation for bottom sheet
//     _slideController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//     _slideAnimation = Tween<Offset>(
//       begin: Offset.zero,
//       end: const Offset(-1.0, 0.0),
//     ).animate(CurvedAnimation(
//       parent: _slideController,
//       curve: Curves.easeInOut,
//     ));
//   }

//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _mapView = prefs.getString('map_view') ?? 'Auto';
//       _mode = prefs.getString('map_mode') ?? 'Default';
//       _mapType = prefs.getString('map_type') ?? 'Default';
//       _keepNorthUp = prefs.getBool('keep_north_up') ?? true;
//       _autoZoom = prefs.getBool('auto_zoom') ?? true;
//     });
//     _applyMapSettings();
//   }

//   Future<void> _saveMapViewSetting(String mapView) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('map_view', mapView);
//     setState(() {
//       _mapView = mapView;
//     });
//     _applyMapSettings();
//   }

//   Future<void> _saveModeSetting(String mode) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('map_mode', mode);
//     setState(() {
//       _mode = mode;
//     });
//     _applyMapSettings();
//   }

//   Future<void> _saveTypeSetting(String mapType) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('map_type', mapType);
//     setState(() {
//       _mapType = mapType;
//     });
//     _applyMapSettings();
//   }

//   void _applyMapSettings() {
//     if (mapboxMap == null) return;

//     // Apply Map View (Pitch)
//     double pitch;
//     if (_mapView == '3D') {
//       pitch = 65.0;
//       isPitchEnabled = true;
//     } else if (_mapView == 'Auto') {
//       pitch = 45.0;
//       isPitchEnabled = true;
//     } else {
//       pitch = 0.0;
//       isPitchEnabled = false;
//     }
//     mapboxMap!.flyTo(
//       mp.CameraOptions(pitch: pitch),
//       mp.MapAnimationOptions(duration: 700, startDelay: 0),
//     );

//     // Apply Mode (Map Style)
//     String? styleUri;
//     if (_mode == 'Night') {
//       styleUri =
//           "mapbox://styles/mapbox/dark-v11"; // Mapbox Dark style for Night
//     } else if (_mode == 'Day') {
//       styleUri =
//           "mapbox://styles/mapbox/light-v11"; // Mapbox Light style for Day
//     } else if (_mode == 'Same as Phone Settings') {
//       styleUri = MediaQuery.of(context).platformBrightness == Brightness.dark
//           ? "mapbox://styles/mapbox/dark-v11"
//           : "mapbox://styles/mapbox/light-v11";
//     } else {
//       styleUri =
//           "mapbox://styles/buddyapp01/cm988908900g601pg0tyd9tjj"; // Default style
//     }
//     mapboxMap!.style.setStyleURI(styleUri);

//     // Apply Type (Map Type)
//     if (_mapType == 'Map Editors') {
//       mapboxMap!.style.setStyleLayerProperty(
//         "mapbox-satellite",
//         "visibility",
//         "visible",
//       );
//     } else {
//       mapboxMap!.style.setStyleLayerProperty(
//         "mapbox-satellite",
//         "visibility",
//         "none",
//       );
//     }

//     // Apply Keep North Up
//     if (_keepNorthUp && !isNavigationActive) {
//       mapboxMap!.easeTo(
//         mp.CameraOptions(bearing: 0),
//         mp.MapAnimationOptions(duration: 700),
//       );
//     }
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     precacheImage(const AssetImage('assets/icons/aim_enabled.png'), context);
//     precacheImage(const AssetImage('assets/icons/aim_disable.png'), context);
//     precacheImage(const AssetImage('assets/icons/north_arrow.png'), context);
//   }

//   void _showLoadingOverlay(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return const Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
//           ),
//         );
//       },
//     );
//   }

//   void _hideLoadingOverlay() {
//     if (Navigator.canPop(context)) {
//       Navigator.pop(context);
//     }
//   }

//   @override
//   void dispose() {
//     _bounceController?.dispose();
//     _bubbleScaleController?.dispose();
//     _positionUpdateTimer?.cancel();
//     usersPositionStream?.cancel();
//     controller?.dispose();
//     _slideController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         alignment: Alignment.center,
//         children: [
//           _buildMapWidget(),
//           if (_showBubble && destinationPosition != null)
//             _buildBouncingMarkerWithBubble(),
//           _buildMapStyleButton(),
//           _buildFollowUserButton(),
//           _buildMapControls(),
//           if (showNavigationInfoPanel) _buildNavigationInfoPanel(),
//         ],
//       ),
//     );
//   }

//   // Helper method for Map Widget
//   Widget _buildMapWidget() {
//     return mp.MapWidget(
//       key: const ValueKey("mapWidget"),
//       styleUri: "mapbox://styles/buddyapp01/cm988908900g601pg0tyd9tjj",
//       onMapCreated: _onMapCreated,
//       onLongTapListener: (event) => _handleLongTap(event.point),
//       onTapListener: (event) => _handleTap(event.point),
//     );
//   }

//   // Helper method for Map Style Button
//   Widget _buildMapStyleButton() {
//     return Positioned(
//       bottom: 90,
//       left: 20,
//       child: Container(
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white.withOpacity(0.9),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.4),
//               blurRadius: 4,
//               offset: const Offset(4, 6),
//             ),
//           ],
//         ),
//         child: IconButton(
//           icon: const Icon(
//             Icons.layers,
//             color: Colors.black,
//             size: 30,
//           ),
//           onPressed: _showMapSettingsBottomSheet,
//         ),
//       ),
//     );
//   }

//   // Helper method to show the Map Settings bottom sheet
//   void _showMapSettingsBottomSheet() {
//     _currentPage = 0;
//     _isBottomSheetOpen = true;
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (BuildContext context) {
//         return DraggableScrollableSheet(
//           initialChildSize: 0.4, // Adjusted initial height
//           minChildSize: 0.2, // Minimum height
//           maxChildSize: 0.6, // Maximum height
//           builder: (BuildContext context, ScrollController scrollController) {
//             return Container(
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//               ),
//               child: Stack(
//                 children: [
//                   SlideTransition(
//                     position: _slideAnimation,
//                     child: _buildMainSettingsPage(scrollController),
//                   ),
//                   AnimatedBuilder(
//                     animation: _slideController,
//                     builder: (context, child) {
//                       return Transform.translate(
//                         offset: Offset(
//                             _currentPage == 1
//                                 ? 0
//                                 : _currentPage == 0
//                                     ? MediaQuery.of(context).size.width
//                                     : -MediaQuery.of(context).size.width,
//                             0),
//                         child: child,
//                       );
//                     },
//                     child: _buildModeSelectionPage(scrollController),
//                   ),
//                   AnimatedBuilder(
//                     animation: _slideController,
//                     builder: (context, child) {
//                       return Transform.translate(
//                         offset: Offset(
//                             _currentPage == 2
//                                 ? 0
//                                 : _currentPage == 0
//                                     ? MediaQuery.of(context).size.width
//                                     : -MediaQuery.of(context).size.width,
//                             0),
//                         child: child,
//                       );
//                     },
//                     child: _buildTypeSelectionPage(scrollController),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     ).whenComplete(() {
//       _currentPage = 0;
//       _slideController.reset();
//       _isBottomSheetOpen = false;
//     });
//   }

//   // Main Settings Page in Bottom Sheet
//   Widget _buildMainSettingsPage(ScrollController scrollController) {
//     return SingleChildScrollView(
//       controller: scrollController,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Map Settings',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Map View',
//               style: TextStyle(fontSize: 16, color: Colors.black87),
//             ),
//             const SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildMapViewCard('3D', _mapView == '3D'),
//                 _buildMapViewCard('Auto', _mapView == 'Auto'),
//                 _buildMapViewCard('2D', _mapView == '2D'),
//               ],
//             ),
//             const Divider(),
//             ListTile(
//               title: const Text(
//                 'Mode',
//                 style: TextStyle(fontSize: 16, color: Colors.black87),
//               ),
//               subtitle: Text(
//                 _mode,
//                 style: const TextStyle(fontSize: 14, color: Colors.black54),
//               ),
//               trailing: const Icon(Icons.chevron_right, color: Colors.black54),
//               onTap: () {
//                 setState(() {
//                   _currentPage = 1;
//                   _slideController.forward();
//                 });
//               },
//             ),
//             const Divider(),
//             ListTile(
//               title: const Text(
//                 'Type',
//                 style: TextStyle(fontSize: 16, color: Colors.black87),
//               ),
//               subtitle: Text(
//                 _mapType,
//                 style: const TextStyle(fontSize: 14, color: Colors.black54),
//               ),
//               trailing: const Icon(Icons.chevron_right, color: Colors.black54),
//               onTap: () {
//                 setState(() {
//                   _currentPage = 2;
//                   _slideController.forward();
//                 });
//               },
//             ),
//             const SizedBox(height: 16),
//           ],
//         ),
//       ),
//     );
//   }

//   // Mode Selection Page in Bottom Sheet
//   Widget _buildModeSelectionPage(ScrollController scrollController) {
//     return SingleChildScrollView(
//       controller: scrollController,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.arrow_back_ios_rounded,
//                       color: Colors.black54),
//                   onPressed: () {
//                     setState(() {
//                       _currentPage = 0;
//                       _slideController.reverse();
//                     });
//                   },
//                 ),
//                 const Text(
//                   'Select Mode',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             ListTile(
//               title: const Text('Off',
//                   style: TextStyle(fontSize: 16, color: Colors.black87)),
//               trailing: _mode == 'Off'
//                   ? const Icon(Icons.check, color: Colors.redAccent)
//                   : null,
//               onTap: () {
//                 _saveModeSetting('Off');
//                 setState(() {
//                   _currentPage = 0;
//                   _slideController.reverse();
//                 });
//               },
//             ),
//             ListTile(
//               title: const Text('Night',
//                   style: TextStyle(fontSize: 16, color: Colors.black87)),
//               trailing: _mode == 'Night'
//                   ? const Icon(Icons.check, color: Colors.redAccent)
//                   : null,
//               onTap: () {
//                 _saveModeSetting('Night');
//                 setState(() {
//                   _currentPage = 0;
//                   _slideController.reverse();
//                 });
//               },
//             ),
//             ListTile(
//               title: const Text('Day',
//                   style: TextStyle(fontSize: 16, color: Colors.black87)),
//               trailing: _mode == 'Day'
//                   ? const Icon(Icons.check, color: Colors.redAccent)
//                   : null,
//               onTap: () {
//                 _saveModeSetting('Day');
//                 setState(() {
//                   _currentPage = 0;
//                   _slideController.reverse();
//                 });
//               },
//             ),
//             ListTile(
//               title: const Text('Same as Phone Settings',
//                   style: TextStyle(fontSize: 16, color: Colors.black87)),
//               trailing: _mode == 'Same as Phone Settings'
//                   ? const Icon(Icons.check, color: Colors.redAccent)
//                   : null,
//               onTap: () {
//                 _saveModeSetting('Same as Phone Settings');
//                 setState(() {
//                   _currentPage = 0;
//                   _slideController.reverse();
//                 });
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Type Selection Page in Bottom Sheet
//   Widget _buildTypeSelectionPage(ScrollController scrollController) {
//     return SingleChildScrollView(
//       controller: scrollController,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.arrow_back_ios_rounded,
//                       color: Colors.black54),
//                   onPressed: () {
//                     setState(() {
//                       _currentPage = 0;
//                       _slideController.reverse();
//                     });
//                   },
//                 ),
//                 const Text(
//                   'Select Type',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             ListTile(
//               title: const Text('Default',
//                   style: TextStyle(fontSize: 16, color: Colors.black87)),
//               trailing: _mapType == 'Default'
//                   ? const Icon(Icons.check, color: Colors.redAccent)
//                   : null,
//               onTap: () {
//                 _saveTypeSetting('Default');
//                 setState(() {
//                   _currentPage = 0;
//                   _slideController.reverse();
//                 });
//               },
//             ),
//             ListTile(
//               title: const Text('Map Editors',
//                   style: TextStyle(fontSize: 16, color: Colors.black87)),
//               trailing: _mapType == 'Map Editors'
//                   ? const Icon(Icons.check, color: Colors.redAccent)
//                   : null,
//               onTap: () {
//                 _saveTypeSetting('Map Editors');
//                 setState(() {
//                   _currentPage = 0;
//                   _slideController.reverse();
//                 });
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Helper method to build a map view card
//   Widget _buildMapViewCard(String view, bool isSelected) {
//     String assetPath;
//     switch (view) {
//       case '3D':
//         assetPath = 'assets/icons/3d_map.png';
//         break;
//       case 'Auto':
//         assetPath = 'assets/icons/auto_map.png';
//         break;
//       case '2D':
//         assetPath = 'assets/icons/2d_map.png';
//         break;
//       default:
//         assetPath = 'assets/icons/auto_map.png';
//     }

//     return GestureDetector(
//       onTap: () {
//         _saveMapViewSetting(view);
//       },
//       child: Card(
//         elevation: isSelected ? 8 : 2,
//         color: isSelected ? Colors.redAccent.withOpacity(0.1) : Colors.white,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//           side: BorderSide(
//             color: isSelected ? Colors.redAccent : Colors.grey.shade300,
//             width: 2,
//           ),
//         ),
//         child: Container(
//           width: 100,
//           height: 100,
//           padding: const EdgeInsets.all(8),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Image.asset(
//                 assetPath,
//                 width: 40,
//                 height: 40,
//                 color: isSelected ? Colors.redAccent : Colors.grey,
//                 errorBuilder: (context, error, stackTrace) =>
//                     const Icon(Icons.error),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 view,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                   color: isSelected ? Colors.redAccent : Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Helper method for Follow User Button
//   Widget _buildFollowUserButton() {
//     return Positioned(
//       bottom: 20,
//       left: 20,
//       child: Container(
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: Colors.white.withOpacity(0.9),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.4),
//               blurRadius: 4,
//               offset: const Offset(4, 6),
//             ),
//           ],
//         ),
//         child: IconButton(
//           icon: userPosition == null
//               ? const CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
//                 )
//               : Image.asset(
//                   isFollowingUser
//                       ? 'assets/icons/aim_enabled.png'
//                       : 'assets/icons/aim_disable.png',
//                   width: 50,
//                   height: 50,
//                   errorBuilder: (context, error, stackTrace) =>
//                       const Icon(Icons.error),
//                 ),
//           onPressed: userPosition == null ? null : _toggleFollowUser,
//         ),
//       ),
//     );
//   }

//   void _toggleFollowUser() async {
//     if (_isToggling) return;
//     _isToggling = true;
//     try {
//       setState(() => isFollowingUser = !isFollowingUser);

//       if (isFollowingUser) {
//         if (userPosition == null || mapboxMap == null) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Waiting for location or map...')),
//           );
//           try {
//             final position = await gl.Geolocator.getCurrentPosition(
//               desiredAccuracy: gl.LocationAccuracy.high,
//             );
//             setState(() {
//               userPosition = mp.Position(position.longitude, position.latitude);
//             });
//           } catch (e) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Failed to get location')),
//             );
//             setState(() => isFollowingUser = false);
//             return;
//           }
//         }

//         if (userPosition != null && mapboxMap != null) {
//           _activeCameraOnUser(bearing: userBearing);
//           mapboxMap!.easeTo(
//             mp.CameraOptions(
//               center: mp.Point(coordinates: userPosition!),
//               bearing: _keepNorthUp ? 0 : userBearing ?? 0,
//               zoom: 16.clamp(10.0, 16.0).toDouble(),
//             ),
//             mp.MapAnimationOptions(duration: 1000, startDelay: 0),
//           );
//         }
//       }
//     } finally {
//       _isToggling = false;
//     }
//   }

//   // Helper method for Map Controls (Compass, Zoom)
//   Widget _buildMapControls() {
//     return Positioned(
//       bottom: 20,
//       right: 20,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Compass
//           Container(
//             margin: const EdgeInsets.only(bottom: 8.0),
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white.withOpacity(0.9),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.4),
//                   blurRadius: 4,
//                   offset: const Offset(4, 6),
//                 ),
//               ],
//             ),
//             child: GestureDetector(
//               onTap: () {
//                 mapboxMap?.easeTo(
//                   mp.CameraOptions(bearing: 0),
//                   mp.MapAnimationOptions(duration: 1000),
//                 );
//               },
//               child: Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: Image.asset(
//                   'assets/icons/north_arrow.png',
//                   width: 35,
//                   height: 35,
//                   errorBuilder: (context, error, stackTrace) =>
//                       const Icon(Icons.compass_calibration),
//                 ),
//               ),
//             ),
//           ),
//           // Zoom Controls
//           Container(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12.0),
//               color: Colors.white,
//               border: Border.all(
//                 color: Colors.black38,
//                 width: 3.0,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.5),
//                   spreadRadius: 2,
//                   blurRadius: 5,
//                   offset: const Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 IconButton(
//                   icon: const Icon(
//                     Icons.add_rounded,
//                     color: Color.fromARGB(255, 20, 20, 20),
//                   ),
//                   onPressed: _zoomIn,
//                 ),
//                 IconButton(
//                   icon: const Icon(
//                     Icons.remove_rounded,
//                     color: Color.fromARGB(255, 20, 20, 20),
//                   ),
//                   onPressed: _zoomOut,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _updateBubblePosition() async {
//     if (mapboxMap == null || destinationPosition == null) return;
//     final screenPos = await mapboxMap!
//         .pixelForCoordinate(mp.Point(coordinates: destinationPosition!));
//     setState(() => _currentBubblePosition = screenPos);
//   }

//   void _showEmergencyOrganizations() {
//     showModalBottomSheet(
//         context: context,
//         builder: (context) => const EmergencyOrganizationsBottomSheet());
//   }

//   void _showOptionsBottomSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
//       builder: (BuildContext context) {
//         return Container(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.preview, color: Colors.redAccent),
//                 title: const Text('Preview Location',
//                     style: TextStyle(fontSize: 16)),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _previewLocation();
//                 },
//               ),
//               ListTile(
//                 leading:
//                     const Icon(Icons.report_problem, color: Colors.redAccent),
//                 title: const Text('Mark as your Concern Citizen spot',
//                     style: TextStyle(fontSize: 16)),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _markAsConcernSpot();
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _previewLocation() {
//     if (destinationPosition != null) {
//       mapboxMap?.flyTo(
//         mp.CameraOptions(
//             center: mp.Point(coordinates: destinationPosition!),
//             zoom: 14,
//             pitch: _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0)),
//         mp.MapAnimationOptions(duration: 1000, startDelay: 0),
//       );
//     }
//   }

//   void _markAsConcernSpot() {
//     if (kDebugMode) print('Marked as Concern Citizen spot: $endLocationName');
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Marked "$endLocationName" as a Concern Citizen spot')));
//   }

//   Widget _buildBouncingMarkerWithBubble() {
//     return FutureBuilder<mp.ScreenCoordinate>(
//       future: mapboxMap
//           ?.pixelForCoordinate(mp.Point(coordinates: destinationPosition!)),
//       builder: (context, snapshot) {
//         if (_currentBubblePosition == null) return const SizedBox.shrink();
//         final screenPos = _currentBubblePosition!;
//         return Positioned(
//           left: screenPos.x - 130,
//           top: screenPos.y - 240,
//           child: AnimatedBuilder(
//             animation: _bounceAnimation!,
//             builder: (context, child) {
//               return Transform.translate(
//                 offset: Offset(0, -_bounceAnimation!.value),
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     Column(
//                       children: [
//                         Stack(
//                           children: [
//                             ScaleTransition(
//                               scale: _bubbleScaleAnimation!,
//                               child: Container(
//                                 width: 260,
//                                 padding: const EdgeInsets.all(24),
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(24),
//                                   boxShadow: const [
//                                     BoxShadow(
//                                         color: Colors.black26,
//                                         blurRadius: 4,
//                                         offset: Offset(0, 2))
//                                   ],
//                                 ),
//                                 child: Column(
//                                   mainAxisSize: MainAxisSize.min,
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const SizedBox(height: 8),
//                                     Center(
//                                       child: Text(
//                                         destinationRegionName ??
//                                             'Unknown Region',
//                                         style: const TextStyle(
//                                             fontSize: 22,
//                                             color: Colors.black87,
//                                             fontFamily: 'Gilroy'),
//                                         textAlign: TextAlign.center,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     Center(
//                                       child: Text(
//                                         destinationRoadName ?? 'Unamed Road',
//                                         style: const TextStyle(
//                                             fontSize: 18,
//                                             color: Colors.grey,
//                                             fontFamily: 'Gilroy',
//                                             fontWeight: FontWeight.w200),
//                                         textAlign: TextAlign.center,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 8),
//                                     Divider(
//                                         color: Colors.grey[300], thickness: 1),
//                                     const SizedBox(height: 8),
//                                     Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                       children: [
//                                         Expanded(
//                                           child: ElevatedButton(
//                                             onPressed:
//                                                 _showEmergencyOrganizations,
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.blue[300],
//                                               foregroundColor: Colors.white,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 18,
//                                                       vertical: 10),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(46),
//                                                   side: const BorderSide(
//                                                       color: Colors.blue)),
//                                             ),
//                                             child: const Text("Share",
//                                                 style: TextStyle(
//                                                     fontSize: 18,
//                                                     fontFamily: 'Gilroy')),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 6),
//                                         Expanded(
//                                           child: Expanded(
//                                             child: ElevatedButton(
//                                               onPressed: () async {
//                                                 setState(() {
//                                                   _isLoadingRoutesInBubble =
//                                                       true;
//                                                 });
//                                                 _showLoadingOverlay(
//                                                     context); // Show full-screen loading
//                                                 await _getRouteCoordinates();
//                                                 setState(() {
//                                                   _isLoadingRoutesInBubble =
//                                                       false;
//                                                   _routeConfirmed = true;
//                                                   _showBubble = false;
//                                                   showRoutePanel = true;
//                                                 });
//                                                 _hideLoadingOverlay(); // Hide loading after route is fetched
//                                                 // Navigate to the new page
//                                                 Navigator.push(
//                                                   context,
//                                                   MaterialPageRoute(
//                                                     builder: (context) =>
//                                                         RouteInfoPage(
//                                                       startLocation:
//                                                           startLocationName,
//                                                       endLocation:
//                                                           endLocationName,
//                                                       distance: routeDistance,
//                                                       duration: routeDuration,
//                                                       selectedProfile:
//                                                           selectedProfile,
//                                                       routeCoordinates:
//                                                           routeCoordinates,
//                                                       viaText:
//                                                           viaText, // Pass the dynamic viaText
//                                                       onProfileChanged:
//                                                           (profile) {
//                                                         _updateRouteProfile(
//                                                             profile);
//                                                       },
//                                                       onCancel: _cancelRoute,
//                                                       onNavigate:
//                                                           _startNavigation,
//                                                       routeProfiles:
//                                                           routeProfiles,
//                                                       routeColors: routeColors,
//                                                     ),
//                                                   ),
//                                                 );
//                                               },
//                                               style: ElevatedButton.styleFrom(
//                                                 backgroundColor:
//                                                     Colors.redAccent,
//                                                 foregroundColor: Colors.white,
//                                                 padding:
//                                                     const EdgeInsets.symmetric(
//                                                         horizontal: 18,
//                                                         vertical: 10),
//                                                 shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(46),
//                                                   side: const BorderSide(
//                                                       color: Color.fromARGB(
//                                                           255, 167, 11, 0)),
//                                                 ),
//                                               ),
//                                               child: const Text(
//                                                 "Routes",
//                                                 style: TextStyle(
//                                                     fontSize: 18,
//                                                     fontFamily: 'Gilroy'),
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                             Positioned(
//                               right: 10,
//                               top: 10,
//                               child: ScaleTransition(
//                                 scale: _bubbleScaleAnimation!,
//                                 child: CircleAvatar(
//                                   radius: 24,
//                                   backgroundColor: Colors.grey[200],
//                                   child: IconButton(
//                                     padding: EdgeInsets.zero,
//                                     icon: const Icon(Icons.more_horiz_rounded,
//                                         size: 35),
//                                     color: Colors.grey[800],
//                                     onPressed: () =>
//                                         _showBubbleOptions(context),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         Positioned(
//                           bottom: 16,
//                           child: ScaleTransition(
//                             scale: _bubbleScaleAnimation!,
//                             child: CustomPaint(
//                               painter: BubbleTailPainter(),
//                               size: const Size(40, 30),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (_isLoadingRoutesInBubble)
//                       Container(
//                         width: 260,
//                         height: 200,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.8),
//                           borderRadius: BorderRadius.circular(24),
//                         ),
//                         child: const Center(
//                           child: CircularProgressIndicator(
//                             valueColor:
//                                 AlwaysStoppedAnimation<Color>(Colors.redAccent),
//                             strokeWidth: 8.0,
//                             backgroundColor: Colors.transparent,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   void _showBubbleOptions(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
//       builder: (BuildContext context) {
//         return Container(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.preview, color: Colors.redAccent),
//                 title: const Text('Preview Location',
//                     style: TextStyle(fontSize: 16)),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _previewBubbleLocation();
//                 },
//               ),
//               ListTile(
//                 leading:
//                     const Icon(Icons.report_problem, color: Colors.redAccent),
//                 title:
//                     const Text('Report Issue', style: TextStyle(fontSize: 16)),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _reportBubbleIssue();
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _previewBubbleLocation() {
//     if (destinationPosition != null) {
//       mapboxMap?.flyTo(
//         mp.CameraOptions(
//             center: mp.Point(coordinates: destinationPosition!),
//             zoom: 14,
//             pitch: _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0)),
//         mp.MapAnimationOptions(duration: 1000, startDelay: 0),
//       );
//     }
//   }

//   void _reportBubbleIssue() {
//     if (kDebugMode) print('Reported issue at: $endLocationName');
//     ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Reported issue at "$endLocationName"')));
//   }

//   Widget _buildInfoPanel() {
//     return Positioned(
//       bottom: 20,
//       left: 20,
//       right: 20,
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.9),
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: const [
//                 BoxShadow(color: Colors.black12, blurRadius: 10)
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 _buildLocationRow(Icons.my_location, startLocationName),
//                 const SizedBox(height: 8),
//                 _buildLocationRow(Icons.flag, endLocationName),
//                 if (routeDistance != null) ...[
//                   const Divider(),
//                   _buildMetricRow('Distance',
//                       '${(routeDistance! / 1000).toStringAsFixed(1)} km'),
//                   _buildMetricRow('Duration',
//                       '${(routeDuration! / 60).toStringAsFixed(0)} mins'),
//                 ],
//                 const SizedBox(height: 12),
//                 const Text('Choose Navigation Mode:',
//                     style:
//                         TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: routeProfiles.entries.map((entry) {
//                     return IconButton(
//                       icon: Icon(entry.value),
//                       color: selectedProfile == entry.key
//                           ? routeColors[entry.key]
//                           : Colors.grey,
//                       onPressed: () => _updateRouteProfile(entry.key),
//                     );
//                   }).toList(),
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: _cancelRoute,
//                         style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.grey,
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8))),
//                         child: const Text("Cancel",
//                             style: TextStyle(fontSize: 14)),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: _startNavigation,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red[400],
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8)),
//                         ),
//                         child: const Text("Navigate",
//                             style: TextStyle(fontSize: 14)),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Visibility(
//             visible: _isLoadingRoute,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.8),
//                   borderRadius: BorderRadius.circular(12)),
//               child: const CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
//                   strokeWidth: 8.0),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLocationRow(IconData icon, String text) {
//     return Row(
//       children: [
//         Icon(icon, size: 18, color: Colors.redAccent),
//         const SizedBox(width: 8),
//         Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
//       ],
//     );
//   }

//   Widget _buildMetricRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(color: Colors.grey[600])),
//           Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
//         ],
//       ),
//     );
//   }

//   void _onMapCreated(mp.MapboxMap controller) async {
//     mapboxMap = controller;
//     await _initializeMap(controller);
//     controller.addListener(handleMapInteraction);
//     _toggleFollowUser();
//     _applyMapSettings();
//   }

//   void handleMapInteraction() {
//     if (isFollowingUser) setState(() => isFollowingUser = false);
//   }

//   Future<void> _initializeMap(mp.MapboxMap controller) async {
//     await controller.location.updateSettings(
//       mp.LocationComponentSettings(
//           enabled: true,
//           pulsingEnabled: true,
//           pulsingColor: Colors.blueAccent.value,
//           puckBearingEnabled: true,
//           puckBearing: mp.PuckBearing.COURSE),
//     );

//     hqMarkerImage ??= await _loadHQMarkerImage();
//     pointAnnotationManager =
//         await controller.annotations.createPointAnnotationManager();
//     polylineAnnotationManager =
//         await controller.annotations.createPolylineAnnotationManager();

//     await controller.style
//         .addSource(mp.GeoJsonSource(id: "source", lineMetrics: true));
//     await controller.style.addLayer(
//       mp.LineLayer(
//         id: "layer",
//         sourceId: "source",
//         lineColor: routeColors[selectedProfile]!.value,
//         lineWidth: 10.0,
//         lineOpacity: 0.9,
//         lineBorderColor: routeColors[selectedProfile]!.value,
//         lineBorderWidth: 2,
//         lineCap: mp.LineCap.ROUND,
//         lineJoin: mp.LineJoin.ROUND,
//         lineTrimOffset: [0.0, 1.0],
//       ),
//     );

//     controller.flyTo(
//         mp.CameraOptions(
//           zoom: 10.clamp(10.0, 16.0).toDouble(),
//           pitch: 0,
//           bearing: 0,
//         ),
//         mp.MapAnimationOptions(duration: 700, startDelay: 0));
//   }

//   void _handleLongTap(mp.Point point) async {
//     if (hqMarkerImage == null) return;

//     await _reverseGeocode(point.coordinates, false);

//     setState(() {
//       destinationPosition = point.coordinates;
//       hasDestination = true;
//       isFollowingUser = false;
//       endLocationName = 'Destination';
//       _routeConfirmed = false;
//       _showBubble = true;
//       routeCoordinates.clear();
//       showRoutePanel = false;
//     });

//     pointAnnotationManager?.deleteAll();
//     pointAnnotationManager?.create(mp.PointAnnotationOptions(
//         image: hqMarkerImage, iconSize: 1.0, geometry: point));

//     mapboxMap?.flyTo(
//       mp.CameraOptions(
//           bearing: _keepNorthUp ? 0 : userBearing ?? 0,
//           center: mp.Point(coordinates: point.coordinates),
//           zoom: 16.clamp(10.0, 16.0).toDouble(),
//           pitch: _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0)),
//       mp.MapAnimationOptions(duration: 1000, startDelay: 0),
//     );

//     await _updateBubblePosition();
//     _bubbleScaleController?.reset();
//     _bubbleScaleController?.forward();
//   }

//   void _handleTap(mp.Point point) {
//     if (_isBottomSheetOpen) {
//       Navigator.of(context).pop(); // Close the bottom sheet
//       _isBottomSheetOpen = false;
//     }
//     _bubbleScaleController?.reverse().then((_) {
//       setState(() {
//         _showBubble = false;
//         hasDestination = false;
//         destinationPosition = null;
//         routeCoordinates.clear();
//         showRoutePanel = false;
//         pointAnnotationManager?.deleteAll();
//       });
//     });
//   }

//   void _adjustMapUpward() async {
//     if (mapboxMap == null ||
//         userPosition == null ||
//         destinationPosition == null) return;

//     const double navigationPanelHeight = 150.0;
//     final screenHeight = MediaQuery.of(context).size.height;
//     const topPadding = navigationPanelHeight + 20;

//     final coordinates = [
//       mp.Point(coordinates: userPosition!),
//       mp.Point(coordinates: destinationPosition!),
//     ];

//     final camera = await mapboxMap!.cameraForCoordinates(
//       coordinates,
//       mp.MbxEdgeInsets(
//           top: topPadding, left: 50.0, bottom: screenHeight / 2, right: 50.0),
//       null,
//       _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0),
//     );

//     double newZoom = routeDistance != null
//         ? (routeDistance! < 1000
//             ? 15.0
//             : routeDistance! < 5000
//                 ? 13.0
//                 : routeDistance! < 10000
//                     ? 11.0
//                     : routeDistance! < 50000
//                         ? 9.0
//                         : 7.0)
//         : 14.0;

//     mapboxMap!.flyTo(
//       mp.CameraOptions(
//         center: camera.center,
//         zoom: newZoom.clamp(10.0, 16.0).toDouble(),
//         pitch: _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0),
//         bearing: isNavigationActive
//             ? camera.bearing ?? 0
//             : _keepNorthUp
//                 ? 0
//                 : userBearing ?? 0,
//         padding: mp.MbxEdgeInsets(
//             top: topPadding, left: 50.0, bottom: screenHeight / 2, right: 50.0),
//       ),
//       mp.MapAnimationOptions(duration: 1000, startDelay: 0),
//     );
//   }

//   Future<bool> _getRouteCoordinates({bool useDialogError = false}) async {
//     if (!(hasDestination && _routeConfirmed) ||
//         userPosition == null ||
//         destinationPosition == null) return false;

//     setState(() => _isLoadingRoute = true);
//     final start = "${userPosition!.lng},${userPosition!.lat}";
//     final end = "${destinationPosition!.lng},${destinationPosition!.lat}";

//     try {
//       final response = await http.get(
//           Uri.parse('$orsBaseUrl/$selectedProfile?start=$start&end=$end'),
//           headers: {
//             'Authorization': 'Bearer $orsApiKey',
//             'Accept': 'application/json, application/geo+json'
//           }).timeout(const Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final feature = data['features'][0];
//         final coordinates = feature['geometry']['coordinates'];
//         final properties = feature['properties'];
//         final summary = properties['summary'];

//         // Extract "via" information from segments or steps
//         String dynamicViaText = 'Unknown Route';
//         if (properties.containsKey('segments')) {
//           final segments = properties['segments'] as List<dynamic>;
//           for (var segment in segments) {
//             if (segment.containsKey('steps')) {
//               final steps = segment['steps'] as List<dynamic>;
//               for (var step in steps) {
//                 if (step.containsKey('name') && step['name'] != '-') {
//                   dynamicViaText = step['name'];
//                   break;
//                 }
//               }
//             }
//             if (dynamicViaText != 'Unknown Route') break;
//           }
//         }

//         setState(() {
//           routeCoordinates = coordinates
//               .map<mp.Position>((coord) => mp.Position(
//                   (coord[0] as num).toDouble(), (coord[1] as num).toDouble()))
//               .toList();
//           routeDistance = summary['distance'];
//           routeDuration = summary['duration'];
//           averageSpeed = (routeDistance! / routeDuration!) * 3.6;
//           viaText = 'Via $dynamicViaText'; // Update viaText dynamically
//           _isLoadingRoute = false;
//         });

//         _reverseGeocode(userPosition!, true);
//         _reverseGeocode(destinationPosition!, false);
//         _updateRoutePolyline();
//         return true;
//       }
//     } catch (e) {
//       if (kDebugMode) print('Route calculation error: $e');
//     }

//     setState(() => _isLoadingRoute = false);
//     return false;
//   }

//   void _updateRoutePolyline() async {
//     final source = await mapboxMap?.style.getSource("source");
//     if (routeCoordinates.isEmpty) {
//       if (source is mp.GeoJsonSource) {
//         source.updateGeoJSON(
//             json.encode({"type": "FeatureCollection", "features": []}));
//       }
//       return;
//     }
//     final line = mp.LineString(coordinates: routeCoordinates);
//     if (source is mp.GeoJsonSource) source.updateGeoJSON(json.encode(line));

//     if (!_hasAnimatedRoute) {
//       controller?.stop();
//       controller?.dispose();
//       controller = AnimationController(
//           duration: const Duration(seconds: 2), vsync: this);
//       animation = Tween<double>(begin: 0, end: 1.0).animate(controller!)
//         ..addListener(() => mapboxMap?.style.setStyleLayerProperty(
//             "layer", "line-trim-offset", [animation?.value, 1.0]));
//       controller?.forward().whenComplete(() => _hasAnimatedRoute = true);
//     } else {
//       mapboxMap?.style
//           .setStyleLayerProperty("layer", "line-trim-offset", [1.0, 1.0]);
//     }
//   }

//   void _updateRouteProfile(String profile) async {
//     setState(() {
//       selectedProfile = profile;
//       _hasAnimatedRoute = false;
//     });

//     final layerExists =
//         await mapboxMap?.style.styleLayerExists("layer") ?? false;
//     if (layerExists) {
//       final colorHex =
//           '#${routeColors[selectedProfile]!.value.toRadixString(16).padLeft(8, '0').substring(2)}';
//       mapboxMap?.style.setStyleLayerProperty("layer", "line-color", colorHex);
//       mapboxMap?.style
//           .setStyleLayerProperty("layer", "line-border-color", colorHex);
//     }

//     if (hasDestination && _routeConfirmed) await _getRouteCoordinates();
//   }

//   void _activeCameraOnUser({double? bearing, bool useBottomCenter = false}) {
//     if (userPosition == null) return;
//     if (_isNavigationPuckActive) _changeLocationPuckToNavigation();
//     final anchor = useBottomCenter
//         ? mp.ScreenCoordinate(
//             x: MediaQuery.of(context).size.width / 2,
//             y: MediaQuery.of(context).size.height * 0.9)
//         : mp.ScreenCoordinate(x: 1, y: 1);
//     double zoomLevel = _autoZoom ? _calculateAutoZoom() : _lastZoomLevel;
//     mapboxMap?.flyTo(
//       mp.CameraOptions(
//         center: mp.Point(coordinates: userPosition!),
//         bearing: isNavigationActive
//             ? bearing ?? 0
//             : _keepNorthUp
//                 ? 0
//                 : bearing ?? 0,
//         pitch: _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0),
//         padding: mp.MbxEdgeInsets(top: 400, left: 2, bottom: 4, right: 2),
//         anchor: anchor,
//         zoom: zoomLevel.clamp(10.0, 16.0).toDouble(),
//       ),
//       mp.MapAnimationOptions(duration: 2000, startDelay: 0),
//     );
//     _lastZoomLevel = zoomLevel;
//   }

//   void _centerCameraOnUser({double? bearing, bool useBottomCenter = false}) {
//     if (userPosition == null) return;
//     final anchor = useBottomCenter
//         ? mp.ScreenCoordinate(
//             x: MediaQuery.of(context).size.width / 2,
//             y: MediaQuery.of(context).size.height * 0.9)
//         : mp.ScreenCoordinate(x: 1, y: 1);
//     double zoomLevel = _autoZoom ? _calculateAutoZoom() : _lastZoomLevel;
//     mapboxMap?.flyTo(
//       mp.CameraOptions(
//         center: mp.Point(coordinates: userPosition!),
//         bearing: isNavigationActive
//             ? bearing ?? 0
//             : _keepNorthUp
//                 ? 0
//                 : bearing ?? 0,
//         pitch: _mapView == '3D' ? 65.0 : (_mapView == 'Auto' ? 45.0 : 0.0),
//         padding: mp.MbxEdgeInsets(top: 4, left: 2, bottom: 4, right: 2),
//         anchor: anchor,
//         zoom: zoomLevel,
//       ),
//       mp.MapAnimationOptions(duration: 2000, startDelay: 0),
//     );
//     _lastZoomLevel = zoomLevel;
//   }

//   double _calculateAutoZoom() {
//     if (!isFollowingUser && !isNavigationActive) return _lastZoomLevel;

//     double speed = averageSpeed ?? 0; // Speed in km/h
//     if (isNavigationActive && routeDistance != null) {
//       // Adjust zoom based on remaining distance
//       double remainingDistance = routeDistance!; // in meters
//       for (int i = 0; i < routeCoordinates.length; i++) {
//         double d = gl.Geolocator.distanceBetween(
//           userPosition!.lat.toDouble(),
//           userPosition!.lng.toDouble(),
//           routeCoordinates[i].lat.toDouble(),
//           routeCoordinates[i].lng.toDouble(),
//         );
//         if (d < remainingDistance) remainingDistance = d;
//       }
//       if (remainingDistance < 500) return 16.0; // Close-up view
//       if (remainingDistance < 2000) return 14.0;
//       if (remainingDistance < 5000) return 12.0;
//       return 10.0; // Wide view for long distances
//     }

//     // Adjust zoom based on speed when following user
//     if (speed < 10) return 16.0; // Close-up view for walking
//     if (speed < 40) return 14.0; // Medium view for slow driving
//     if (speed < 80) return 12.0; // Wider view for faster driving
//     return 10.0; // Wide view for high speeds
//   }

//   Future<void> _requestLocationPermission() async {
//     bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) await gl.Geolocator.openLocationSettings();

//     gl.LocationPermission permission = await gl.Geolocator.checkPermission();
//     if (permission == gl.LocationPermission.denied) {
//       permission = await gl.Geolocator.requestPermission();
//       if (permission == gl.LocationPermission.denied) return;
//     }

//     if (permission != gl.LocationPermission.deniedForever) {
//       _startLocationTracking();
//     }
//   }

//   void _startLocationTracking() {
//     const locationSettings = gl.LocationSettings(
//         accuracy: gl.LocationAccuracy.bestForNavigation, distanceFilter: 0);
//     usersPositionStream =
//         gl.Geolocator.getPositionStream(locationSettings: locationSettings)
//             .listen((gl.Position position) async {
//       final newPosition = mp.Position(position.longitude, position.latitude);
//       double routeBearing = _calculateRouteBearing(newPosition);

//       setState(() {
//         userPosition = newPosition;
//         userBearing = routeBearing;
//       });

//       if (!_isInitialGeocodingDone && userPosition != null) {
//         await _reverseGeocode(userPosition!, false);
//         setState(() => _isInitialGeocodingDone = true);
//       }

//       if (!_isCameraCentered && userPosition != null) {
//         _centerCameraOnUser(bearing: routeBearing);
//         _isCameraCentered = true;
//       }

//       if (isFollowingUser && !hasDestination) {
//         _centerCameraOnUser(bearing: routeBearing);
//       }
//       if (hasDestination && _routeConfirmed) _getRouteCoordinates();
//       if (isNavigationActive && routeCoordinates.isNotEmpty) {
//         _updateUpcomingRoute();
//         _activeCameraOnUser(
//             bearing: _calculateRouteBearing(userPosition!),
//             useBottomCenter: true);
//       }
//       _reverseGeocode(newPosition, true);
//     });
//   }

//   void _updateUpcomingRoute() async {
//     if (userPosition == null || routeCoordinates.isEmpty) return;
//     int nearestIndex = 0;
//     double minDistance = double.infinity;
//     for (int i = 0; i < routeCoordinates.length; i++) {
//       final d = gl.Geolocator.distanceBetween(
//         userPosition!.lat.toDouble(),
//         userPosition!.lng.toDouble(),
//         routeCoordinates[i].lat.toDouble(),
//         routeCoordinates[i].lng.toDouble(),
//       );
//       if (d < minDistance) {
//         minDistance = d;
//         nearestIndex = i;
//       }
//     }
//     final upcomingRoute = routeCoordinates.sublist(nearestIndex);
//     final source = await mapboxMap?.style.getSource("source");
//     if (source is mp.GeoJsonSource) {
//       final line = mp.LineString(coordinates: upcomingRoute);
//       source.updateGeoJSON(json.encode(line));
//     }
//   }

//   double _calculateRouteBearing(mp.Position currentPos) {
//     if (routeCoordinates.length < 2) return 0;
//     int nearestIndex = 0;
//     double minDistance = double.infinity;
//     for (int i = 0; i < routeCoordinates.length; i++) {
//       final d = gl.Geolocator.distanceBetween(
//         currentPos.lat.toDouble(),
//         currentPos.lng.toDouble(),
//         routeCoordinates[i].lat.toDouble(),
//         routeCoordinates[i].lng.toDouble(),
//       );
//       if (d < minDistance) {
//         minDistance = d;
//         nearestIndex = i;
//       }
//     }
//     final nextIndex = (nearestIndex + 1 < routeCoordinates.length)
//         ? nearestIndex + 1
//         : nearestIndex;
//     return gl.Geolocator.bearingBetween(
//       currentPos.lat.toDouble(),
//       currentPos.lng.toDouble(),
//       routeCoordinates[nextIndex].lat.toDouble(),
//       routeCoordinates[nextIndex].lng.toDouble(),
//     );
//   }

//   Future<Uint8List> _loadHQMarkerImage() async {
//     final ByteData data =
//         await rootBundle.load('assets/icons/location_puck.png');
//     final Uint8List bytes = data.buffer.asUint8List();
//     final codec = await ui.instantiateImageCodec(bytes,
//         targetWidth: 105, targetHeight: 105);
//     final frame = await codec.getNextFrame();
//     final image = frame.image;
//     final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//     return byteData!.buffer.asUint8List();
//   }

//   Future<void> _changeLocationPuckToNavigation() async {
//     await mapboxMap?.location.updateSettings(
//       mp.LocationComponentSettings(
//         showAccuracyRing: true,
//         accuracyRingColor: const int.fromEnvironment('0xFF005EFF'),
//         accuracyRingBorderColor: const int.fromEnvironment('0xFF008CFF'),
//         pulsingEnabled: true,
//         pulsingColor: Colors.blueAccent.value,
//         pulsingMaxRadius: 80,
//         puckBearingEnabled: true,
//         puckBearing: mp.PuckBearing.HEADING,
//       ),
//     );
//   }

//   Future<void> _reverseGeocode(mp.Position position, bool isStart) async {
//     final url = Uri.parse(
//         'https://api.openrouteservice.org/geocode/reverse?api_key=$orsApiKey&point.lon=${position.lng}&point.lat=${position.lat}');
//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final features = data['features'] as List<dynamic>;
//         if (features.isNotEmpty) {
//           setState(() {
//             final feature = features[0];
//             final properties = feature['properties'];
//             final name = properties['label'] ?? 'Unknown Location';
//             if (isStart) {
//               startLocationName = name;
//             } else {
//               endLocationName = name;
//               destinationRegionName = properties['region'] ?? 'Unknown Region';
//               destinationRoadName = properties['street'] ?? 'Unnamed Road';
//             }
//           });
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) print('Geocoding error: $e');
//     }
//   }

//   Widget _buildNavigationInfoPanel() {
//     const gradient = LinearGradient(
//         colors: [Colors.black, Colors.transparent],
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter);
//     return Positioned(
//       top: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding:
//             const EdgeInsets.only(top: 46, left: 20, right: 20, bottom: 10),
//         decoration: BoxDecoration(
//             gradient: gradient,
//             borderRadius: BorderRadius.circular(0),
//             boxShadow: const [
//               BoxShadow(color: Colors.black12, blurRadius: 10)
//             ]),
//         child: Stack(
//           children: [
//             Positioned(
//               top: 0,
//               right: 0,
//               child: CircleAvatar(
//                   backgroundColor: Colors.white,
//                   child: IconButton(
//                       icon: const Icon(Icons.close, color: Colors.red),
//                       onPressed: _exitNavigationMode)),
//             ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (routeDistance != null)
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text((routeDistance! / 1000).toStringAsFixed(1),
//                           style: const TextStyle(
//                               fontSize: 38,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                               fontFamily: 'Gilroy')),
//                       const Text(' km/h',
//                           style: TextStyle(
//                               fontSize: 26,
//                               color: Colors.white,
//                               fontFamily: 'Gilroy')),
//                     ],
//                   ),
//                 const SizedBox(height: 8),
//                 if (routeDuration != null)
//                   Text(
//                       'Duration: ${(routeDuration! / 60).toStringAsFixed(0)} mins',
//                       style: const TextStyle(
//                           fontSize: 18,
//                           color: Colors.white,
//                           fontFamily: 'Gilroy')),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _startNavigation() {
//     _changeLocationPuckToNavigation();
//     setState(() {
//       showRoutePanel = false;
//       isNavigationActive = true;
//       _isNavigationPuckActive = true;
//       isPitchEnabled = true;
//       showRouteProfiles = true;
//       showNavigationInfoPanel = true;
//       _showBubble = false;
//     });
//     _activeCameraOnUser(
//         bearing: _calculateRouteBearing(userPosition ?? mp.Position(0, 0)),
//         useBottomCenter: true);
//   }

//   void _exitNavigationMode() {
//     setState(() {
//       showNavigationInfoPanel = false;
//       showRouteProfiles = false;
//       routeCoordinates.clear();
//       hasDestination = false;
//       destinationPosition = null;
//       routeDistance = null;
//       routeDuration = null;
//       averageSpeed = null;
//       _routeConfirmed = false;
//       isNavigationActive = false;
//       _showBubble = false;
//       pointAnnotationManager?.deleteAll();
//       _isNavigationPuckActive = false;
//       _updateRoutePolyline();
//     });
//     mapboxMap?.location.updateSettings(mp.LocationComponentSettings(
//         pulsingColor: Colors.red.value,
//         locationPuck:
//             mp.LocationPuck(locationPuck2D: mp.DefaultLocationPuck2D())));
//   }

//   void _cancelRoute() {
//     _bubbleScaleController?.reverse().then((_) {
//       setState(() {
//         showRoutePanel = false;
//         routeCoordinates.clear();
//         hasDestination = false;
//         destinationPosition = null;
//         routeDistance = null;
//         routeDuration = null;
//         averageSpeed = null;
//         _routeConfirmed = false;
//         isNavigationActive = false;
//         _showBubble = false;
//         pointAnnotationManager?.deleteAll();
//         _isNavigationPuckActive = false;
//         _updateRoutePolyline();
//       });
//     });
//     mapboxMap?.location.updateSettings(mp.LocationComponentSettings(
//         pulsingColor: Colors.red.value,
//         locationPuck:
//             mp.LocationPuck(locationPuck2D: mp.DefaultLocationPuck2D())));
//   }

//   void _zoomIn() async {
//     final currentZoom = (await mapboxMap?.getCameraState())?.zoom ?? 0;
//     const maxZoom = 16.0;
//     if (currentZoom < maxZoom) {
//       double newZoom = (currentZoom + 1).clamp(10.0, maxZoom).toDouble();
//       mapboxMap?.flyTo(
//         mp.CameraOptions(zoom: newZoom),
//         mp.MapAnimationOptions(duration: 500, startDelay: 0),
//       );
//       _lastZoomLevel = newZoom;
//     }
//   }

//   Future<void> _zoomOut() async {
//     final currentZoom = (await mapboxMap?.getCameraState())?.zoom ?? 0;
//     const minZoom = 10.0;
//     if (currentZoom > minZoom) {
//       double newZoom = (currentZoom - 1).clamp(minZoom, 16.0).toDouble();
//       mapboxMap?.flyTo(
//         mp.CameraOptions(zoom: newZoom),
//         mp.MapAnimationOptions(duration: 500, startDelay: 0),
//       );
//       _lastZoomLevel = newZoom;
//     }
//   }
// }

// class BubbleTailPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.white
//       ..style = PaintingStyle.fill;

//     final path = Path()
//       ..moveTo(0, 0)
//       ..lineTo(size.width, 0)
//       ..lineTo(size.width / 2, size.height)
//       ..close();

//     canvas.drawShadow(
//       path,
//       Colors.black.withOpacity(0.8),
//       10.0,
//       true,
//     );

//     canvas.drawPath(path, paint);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
