// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:emcall/containers/residents/verification_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;

class CompleteResidentAccountForm extends StatefulWidget {
  final int residentId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String email;

  const CompleteResidentAccountForm({
    super.key,
    required this.residentId,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.email,
  });

  @override
  _CompleteResidentAccountFormState createState() =>
      _CompleteResidentAccountFormState();
}

class _CompleteResidentAccountFormState
    extends State<CompleteResidentAccountForm> {
  final TextEditingController sitioController = TextEditingController();
  final TextEditingController barangayController = TextEditingController();
  final TextEditingController municipalController = TextEditingController();
  final TextEditingController mapAddressController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  String? selectedStatus;
  String? selectedGender;
  bool _isLoading = false;
  mp.MapboxMap? _mapboxMap;
  mp.PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _pinIcon;
  bool _isButtonPressed = false;

  // Design constants
  static const _primaryColor = Color(0xFF2962FF);
  static const _inputBorderRadius = 12.0;
  static const _buttonBorderRadius = 15.0;
  static const _animationDuration = Duration(milliseconds: 200);
  static const _mapHeight = 200.0;

  final List<String> statusOptions = [
    'Single',
    'Married',
    'Divorced',
    'Widowed'
  ];
  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final List<String> days = List.generate(31, (i) => (i + 1).toString());
  final List<String> years = List.generate(
    DateTime.now().year - 1960 + 1,
    (i) => (1960 + i).toString(),
  );

  InputDecoration _inputDecoration(String label, {bool isRequired = true}) {
    return InputDecoration(
      labelText: '$label${isRequired ? ' *' : ''}',
      labelStyle: const TextStyle(color: _primaryColor),
      floatingLabelStyle: const TextStyle(color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

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

  void _handleMapTap(details) => _processMapTap(details.point);

  Future<void> _processMapTap(mp.Point point) async {
    if (_mapboxMap == null ||
        _pointAnnotationManager == null ||
        _pinIcon == null) return;

    final lat = point.coordinates.lat;
    final lng = point.coordinates.lng;
    final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;
    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$accessToken&types=address,neighborhood,locality';

    try {
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
          });

          await _pointAnnotationManager?.deleteAll();
          await _pointAnnotationManager?.create(
            mp.PointAnnotationOptions(
              geometry: point,
              image: _pinIcon,
              iconSize: 0.25,
            ),
          );

          await _mapboxMap?.flyTo(
            mp.CameraOptions(center: point, zoom: 15.0),
            mp.MapAnimationOptions(duration: 2000),
          );
        }
      }
    } catch (e) {
      _showErrorDialog('Map Error', 'Failed to fetch location: $e');
    }
  }

  Future<void> _reverseGeocode() async {
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
        // ignore: deprecated_member_use
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
          });

          final currentPoint = mp.Point(
              coordinates: mp.Position(position.longitude, position.latitude));

          await _pointAnnotationManager?.deleteAll();
          await _pointAnnotationManager?.create(
            mp.PointAnnotationOptions(
              geometry: currentPoint,
              image: _pinIcon,
              iconSize: 0.3,
            ),
          );

          await _mapboxMap?.flyTo(
            mp.CameraOptions(center: currentPoint, zoom: 15.0),
            mp.MapAnimationOptions(duration: 2000),
          );
        }
      }
    } catch (e) {
      _showErrorDialog('Location Error', 'Failed to get location: $e');
    }
  }

  void _showBirthDateDialog() {
    String? selectedMonth, selectedDay, selectedYear;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Birth Date',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDateDropdown(months, selectedMonth, 'Month',
                      (value) => selectedMonth = value),
                  _buildDateDropdown(
                      days, selectedDay, 'Day', (value) => selectedDay = value),
                  _buildDateDropdown(years, selectedYear, 'Year',
                      (value) => selectedYear = value),
                ],
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  if (selectedMonth != null &&
                      selectedDay != null &&
                      selectedYear != null) {
                    birthDateController.text =
                        '$selectedMonth $selectedDay, $selectedYear';
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_buttonBorderRadius),
                  ),
                ),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateDropdown(List<String> items, String? value, String hint,
      Function(String?) onChanged) {
    return DropdownButton<String>(
      hint: Text(hint),
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: (value) => onChanged(value),
    );
  }

  Future<void> _handleNextStep() async {
    if (sitioController.text.isEmpty ||
        barangayController.text.isEmpty ||
        municipalController.text.isEmpty ||
        birthDateController.text.isEmpty ||
        selectedStatus == null ||
        selectedGender == null) {
      _showErrorDialog('Missing Fields', 'Please fill all required fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('residents').update({
        'address': '${sitioController.text}, '
            '${barangayController.text}, '
            '${municipalController.text}',
        'birth_date': birthDateController.text,
        'status': selectedStatus,
        'gender': selectedGender,
      }).eq('id', widget.residentId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationForm(
            residentId: widget.residentId,
            firstName: widget.firstName,
            middleName: widget.middleName,
            lastName: widget.lastName,
            suffix: widget.suffix,
            email: widget.email, // Pass the email here
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Update Error', 'Failed to save: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  void dispose() {
    sitioController.dispose();
    barangayController.dispose();
    municipalController.dispose();
    mapAddressController.dispose();
    birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Address Information'),
            _buildInputField(sitioController, 'Sitio'),
            const SizedBox(height: 15),
            _buildInputField(barangayController, 'Barangay'),
            const SizedBox(height: 15),
            _buildInputField(municipalController, 'Municipal'),
            const SizedBox(height: 15),
            _buildInputField(mapAddressController, 'Map Address',
                isEnabled: false),
            _buildSectionTitle('Location'),
            Container(
              height: _mapHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_inputBorderRadius),
                border: Border.all(color: _primaryColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_inputBorderRadius),
                child: mp.MapWidget(
                  onMapCreated: _onMapCreated,
                  onTapListener: _handleMapTap,
                  styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildLocationButton(),
            _buildSectionTitle('Personal Information'),
            _buildDateInputField(),
            const SizedBox(height: 15),
            _buildDropdown('Status', statusOptions, selectedStatus,
                (value) => selectedStatus = value),
            const SizedBox(height: 15),
            _buildDropdown('Gender', genderOptions, selectedGender,
                (value) => selectedGender = value),
            const SizedBox(height: 40),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label,
      {bool isEnabled = true}) {
    return TextFormField(
      controller: controller,
      enabled: isEnabled,
      decoration: _inputDecoration(label),
    );
  }

  Widget _buildLocationButton() {
    return ElevatedButton.icon(
      onPressed: _reverseGeocode,
      icon: const Icon(Icons.my_location, size: 20),
      label: const Text('Use Current Location'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
        ),
      ),
    );
  }

  Widget _buildDateInputField() {
    return TextFormField(
      controller: birthDateController,
      readOnly: true,
      onTap: _showBirthDateDialog,
      decoration: _inputDecoration('Birth Date'),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: (value) => setState(() => onChanged(value)),
      icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
      borderRadius: BorderRadius.circular(_inputBorderRadius),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isButtonPressed = true),
      onTapUp: (_) => setState(() => _isButtonPressed = false),
      onTapCancel: () => setState(() => _isButtonPressed = false),
      child: AnimatedContainer(
        duration: _animationDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
          boxShadow: _isButtonPressed
              ? []
              : [
                  BoxShadow(
                      color: _primaryColor.withOpacity(0.3), blurRadius: 8)
                ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleNextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_buttonBorderRadius),
            ),
            elevation: _isButtonPressed ? 0 : 4,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Next Step', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
