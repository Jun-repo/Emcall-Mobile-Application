// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, deprecated_member_use

import 'package:emcall/containers/residents/verification_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

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
  static const Duration _snackBarDisplayDuration = Duration(seconds: 3);

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

  OutlineInputBorder get customInputBorder {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(
        color: Color.fromARGB(255, 198, 198, 198),
        width: 0.7,
      ),
    );
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
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showErrorDialog('Map Error', 'Failed to fetch location: $e');
      }
    }
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
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showErrorDialog('Location Error', 'Failed to get location: $e');
      }
    }
  }

  void _showBirthDateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedMonth;
        String? selectedDay;
        String? selectedYear;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Birth Date',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDateDropdown(
                          items: months,
                          value: selectedMonth,
                          hint: selectedMonth ?? 'Month',
                          onChanged: (value) {
                            setDialogState(() {
                              selectedMonth = value;
                            });
                          },
                        ),
                        _buildDateDropdown(
                          items: days,
                          value: selectedDay,
                          hint: selectedDay ?? 'Day',
                          onChanged: (value) {
                            setDialogState(() {
                              selectedDay = value;
                            });
                          },
                        ),
                        _buildDateDropdown(
                          items: years,
                          value: selectedYear,
                          hint: selectedYear ?? 'Year',
                          onChanged: (value) {
                            setDialogState(() {
                              selectedYear = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedMonth != null &&
                            selectedDay != null &&
                            selectedYear != null) {
                          setState(() {
                            birthDateController.text =
                                '$selectedMonth $selectedDay, $selectedYear';
                          });
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateDropdown({
    required List<String> items,
    required String? value,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return DropdownButton<String>(
      hint: Text(
        hint,
        style: const TextStyle(color: Colors.black54),
      ),
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.redAccent),
      underline: const SizedBox(),
    );
  }

  Future<void> _handleNextStep() async {
    if (sitioController.text.isEmpty ||
        barangayController.text.isEmpty ||
        municipalController.text.isEmpty ||
        mapAddressController.text.isEmpty ||
        birthDateController.text.isEmpty ||
        selectedStatus == null ||
        selectedGender == null) {
      _showErrorDialog('Missing Fields', 'Please fill all required fields');
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showNoNetworkSnackBar();
      setState(() => _isLoading = false);
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
      await supabase.from('residents').update({
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
            email: widget.email,
          ),
        ),
      );
    } catch (e) {
      if (e is SocketException) {
        _showNoNetworkSnackBar();
      } else {
        _showErrorDialog('Update Error', 'Failed to save: $e');
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Complete Profile',
            style: TextStyle(fontFamily: 'Gilroy')),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: sitioController,
              cursorColor: Colors.redAccent,
              style: const TextStyle(fontSize: 20, color: Colors.black),
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
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: barangayController,
              cursorColor: Colors.redAccent,
              style: const TextStyle(fontSize: 20, color: Colors.black),
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
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: municipalController,
              cursorColor: Colors.redAccent,
              style: const TextStyle(fontSize: 20, color: Colors.black),
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
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: mapAddressController,
              cursorColor: Colors.redAccent,
              style: const TextStyle(fontSize: 20, color: Colors.black),
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
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
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
                  onTapListener: _handleMapTap,
                  styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reverseGeocode,
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
            const SizedBox(height: 15),
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: birthDateController,
              cursorColor: Colors.redAccent,
              style: const TextStyle(fontSize: 20, color: Colors.black),
              readOnly: true,
              onTap: _showBirthDateDialog,
              decoration: InputDecoration(
                labelText: 'Birth Date',
                hintText: 'Select birth date',
                filled: true,
                fillColor: Colors.grey[100],
                labelStyle:
                    const TextStyle(color: Colors.black54, fontSize: 20),
                prefixIcon: const Icon(Icons.cake_rounded),
                border: customInputBorder,
                enabledBorder: customInputBorder,
                focusedBorder: customInputBorder.copyWith(
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                hintText: 'Select status',
                filled: true,
                fillColor: Colors.grey[100],
                labelStyle:
                    const TextStyle(color: Colors.black54, fontSize: 20),
                prefixIcon: const Icon(Icons.person_rounded),
                border: customInputBorder,
                enabledBorder: customInputBorder,
                focusedBorder: customInputBorder.copyWith(
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              items: statusOptions
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedStatus = value),
              validator: (value) => value == null ? 'Required' : null,
              borderRadius: BorderRadius.circular(8.0),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                hintText: 'Select gender',
                filled: true,
                fillColor: Colors.grey[100],
                labelStyle:
                    const TextStyle(color: Colors.black54, fontSize: 20),
                prefixIcon: const Icon(Icons.person_rounded),
                border: customInputBorder,
                enabledBorder: customInputBorder,
                focusedBorder: customInputBorder.copyWith(
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.0),
                ),
              ),
              items: genderOptions
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedGender = value),
              validator: (value) => value == null ? 'Required' : null,
              borderRadius: BorderRadius.circular(8.0),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.redAccent),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        'Next',
                        style: TextStyle(fontSize: 22, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
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
}
