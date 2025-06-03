// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:emcall/containers/organizations/pages/org_verified_successfully_page.dart';
import 'package:emcall/containers/organizations/pages/organization_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class CreateOrganizationAccountForm extends StatefulWidget {
  final String orgType;
  final String publicOrgName;

  const CreateOrganizationAccountForm({
    super.key,
    required this.orgType,
    required this.publicOrgName,
  });

  @override
  CreateOrganizationAccountFormState createState() =>
      CreateOrganizationAccountFormState();
}

class CreateOrganizationAccountFormState
    extends State<CreateOrganizationAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController orgNameController = TextEditingController();
  final TextEditingController sitioController = TextEditingController();
  final TextEditingController barangayController = TextEditingController();
  final TextEditingController municipalController = TextEditingController();
  final TextEditingController mapAddressController = TextEditingController();
  final TextEditingController hotlineController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  mp.MapboxMap? _mapboxMap;
  mp.PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _pinIcon;
  double? latitude, longitude;
  bool _isLoading = false;
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _loadPinIcon();
  }

  Future<void> _loadPinIcon() async {
    final ByteData data = await rootBundle.load('assets/icons/pin-point.png');
    setState(() => _pinIcon = data.buffer.asUint8List());
  }

  void _onMapCreated(mp.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _mapboxMap?.location
        .updateSettings(mp.LocationComponentSettings(enabled: true));
    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();
  }

  Future<void> _reverseGeocode() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showNoNetworkSnackBar();
      return;
    } else if (result == ConnectivityResult.mobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’re on mobile data. Charges may apply.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    try {
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services disabled';

      gl.LocationPermission permission = await gl.Geolocator.checkPermission();
      if (permission == gl.LocationPermission.denied) {
        permission = await gl.Geolocator.requestPermission();
        if (permission == gl.LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }

      final position = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.best,
      );

      final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;
      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${position.longitude},${position.latitude}.json?access_token=$accessToken&types=address,neighborhood,locality';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final feature = features[0];
          final placeName = feature['place_name'] as String;
          final context = feature['context'] as List<dynamic>?;

          String barangay = '';
          String municipality = '';

          context?.forEach((item) {
            final id = item['id'] as String;
            final text = item['text'] as String;
            if (id.contains('neighborhood')) barangay = text;
            if (id.contains('locality')) municipality = text;
          });

          setState(() {
            mapAddressController.text = placeName;
            barangayController.text = barangay;
            municipalController.text = municipality;
            latitude = position.latitude;
            longitude = position.longitude;
          });

          final currentPoint = mp.Point(
              coordinates: mp.Position(position.longitude, position.latitude));

          await _pointAnnotationManager?.deleteAll();
          await _pointAnnotationManager?.create(
            mp.PointAnnotationOptions(
              geometry: currentPoint,
              image: _pinIcon,
              iconSize: 0.25,
            ),
          );

          await _mapboxMap?.flyTo(
            mp.CameraOptions(center: currentPoint, zoom: 15.0),
            mp.MapAnimationOptions(duration: 2000),
          );
        }
      }
    } catch (e) {
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showErrorDialog('Location Error', 'Failed to get location: $e');
      }
    }
  }

  void _showNoNetworkSnackBar({
    Duration duration = _snackBarDisplayDuration,
    Animation<double>? animation,
  }) {
    final snack = SnackBar(
      content: const Text(
          'No Internet Connection, \nBro! checked your network data/wifi before login...'),
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate() ||
        latitude == null ||
        longitude == null ||
        mapAddressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a location'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final tableNameToEnum = {
      'police': 'police',
      'rescue': 'rescue',
      'firefighter': 'firefighter',
      'disaster_responders': 'disaster_responders',
    };

    try {
      final locationResponse = await supabase
          .from('locations')
          .insert({
            'latitude': latitude,
            'longitude': longitude,
            'address':
                '${sitioController.text.trim()}, ${barangayController.text.trim()}, ${municipalController.text.trim()}',
          })
          .select('id')
          .single();

      final locationId = locationResponse['id'];

      final orgData = {
        'public_org_name': orgNameController.text.trim().toLowerCase(),
        'address':
            '${sitioController.text.trim()}, ${barangayController.text.trim()}, ${municipalController.text.trim()}',
        'hotline_phone_number': hotlineController.text.trim(),
        'gmail_org_account': emailController.text.trim(),
        'org_password_hash':
            BCrypt.hashpw(passwordController.text.trim(), BCrypt.gensalt()),
        'location_id': locationId,
      };

      print('Inserting into table: ${widget.orgType}, with data: $orgData');
      final orgResponse =
          await supabase.from(widget.orgType).insert(orgData).select().single();

      final orgId = orgResponse['id'];

      // Generate product key (example)
      final productKey = 'some-generated-key-${orgId}';
      print('Generating product key for orgType: ${widget.orgType}');
      await supabase.from('product_keys').insert({
        'organization_type': tableNameToEnum[widget.orgType]!,
        'organization_id': orgId,
        'key': productKey,
        'is_used': false,
      });

      await prefs.setBool("loggedIn", true);
      await prefs.setString("userType", "organization");
      await prefs.setString("orgType", widget.orgType);
      await prefs.setInt("orgId", orgId);
      await prefs.setString("orgName", orgNameController.text.trim());
      await prefs.setString("orgAddress",
          '${sitioController.text.trim()}, ${barangayController.text.trim()}, ${municipalController.text.trim()}');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrgVerifiedSuccessfullyPage(
            publicOrgName: orgNameController.text.trim(),
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrganizationHomePage(
            orgName: orgNameController.text.trim(),
            orgAddress:
                '${sitioController.text.trim()}, ${barangayController.text.trim()}, ${municipalController.text.trim()}',
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('Error during signup: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  OutlineInputBorder get customInputBorder {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(
        color: Color.fromARGB(255, 198, 198, 198),
        width: 0.7,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: 0.66,
                backgroundColor: Colors.grey[300],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomePage()),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Skip',
                style: TextStyle(color: Colors.black54, fontFamily: 'Gilroy')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png', height: 25),
                      const SizedBox(width: 5),
                      const Text('Emcall',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Text(
                      'Create ${widget.orgType[0].toUpperCase()}${widget.orgType.substring(1)} Account',
                      style:
                          const TextStyle(fontSize: 35, fontFamily: 'Gilroy')),
                  const Text(
                    'Please fill in the details to continue.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: orgNameController,
                    decoration: InputDecoration(
                      labelText: 'Organization Name',
                      hintText: 'Enter organization name',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.business),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Organization name is required' : null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Address Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: sitioController,
                    decoration: InputDecoration(
                      labelText: 'Sitio',
                      hintText: 'Enter sitio',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Sitio is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: barangayController,
                    decoration: InputDecoration(
                      labelText: 'Barangay',
                      hintText: 'Enter barangay',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Barangay is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: municipalController,
                    decoration: InputDecoration(
                      labelText: 'Municipal',
                      hintText: 'Enter municipal',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Municipal is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: mapAddressController,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Map Address',
                      hintText: 'Select address on map',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.map_rounded),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Map address is required' : null,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    height: 200.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: mp.MapWidget(
                        onMapCreated: _onMapCreated,
                        styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _reverseGeocode,
                      icon: const Icon(Icons.my_location, size: 20),
                      label: const Text('Use Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: hotlineController,
                    decoration: InputDecoration(
                      labelText: 'Hotline Number',
                      hintText: 'Enter hotline number',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.phone),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Hotline number is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    cursorColor: Colors.redAccent,
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter email',
                      filled: true,
                      fillColor: Colors.grey[100],
                      labelStyle:
                          const TextStyle(color: Colors.black54, fontSize: 20),
                      prefixIcon: const Icon(Icons.email),
                      border: customInputBorder,
                      enabledBorder: customInputBorder,
                      focusedBorder: customInputBorder.copyWith(
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.0)),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 20),
                  PasswordField(
                    customInputBorder: customInputBorder,
                    controller: passwordController,
                    validator: (value) =>
                        value!.isEmpty ? 'Password is required' : null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Account',
                              style:
                                  TextStyle(fontSize: 22, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    orgNameController.dispose();
    sitioController.dispose();
    barangayController.dispose();
    municipalController.dispose();
    mapAddressController.dispose();
    hotlineController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

class PasswordField extends StatefulWidget {
  final OutlineInputBorder customInputBorder;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const PasswordField({
    super.key,
    required this.customInputBorder,
    this.controller,
    this.validator,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Colors.redAccent,
      style: const TextStyle(fontSize: 20, color: Colors.black),
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        filled: true,
        fillColor: Colors.grey[100],
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 20),
        prefixIcon: const Icon(Icons.lock_rounded),
        border: widget.customInputBorder,
        enabledBorder: widget.customInputBorder,
        focusedBorder: widget.customInputBorder.copyWith(
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.0)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      validator: widget.validator,
    );
  }
}
