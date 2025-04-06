// create_organization_account_form.dart
// ignore_for_file: use_build_context_synchronously

import 'package:bcrypt/bcrypt.dart';
import 'package:emcall/containers/organizations/pages/org_verified_successfully_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emcall/containers/organizations/pages/organization_home_page.dart';

class CreateOrganizationAccountForm extends StatefulWidget {
  final String orgType;
  final String publicOrgName; // New parameter

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
  final TextEditingController addressController = TextEditingController();
  final TextEditingController hotlineController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  mp.MapboxMap? _mapboxMap;
  mp.PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _pinIcon;
  double? latitude, longitude;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    orgNameController.text =
        widget.publicOrgName; // Auto-fill with publicOrgName
    _loadPinIcon();
  }

  Future<void> _loadPinIcon() async {
    final ByteData data = await rootBundle.load('assets/icons/pin-point.png');
    setState(() => _pinIcon = data.buffer.asUint8List());
  }

  void _onMapCreated(mp.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();
  }

  void _handleMapTap(details) async {
    final point = details.point;
    setState(() {
      latitude = point.coordinates.lat;
      longitude = point.coordinates.lng;
    });
    await _pointAnnotationManager?.deleteAll();
    await _pointAnnotationManager?.create(
      mp.PointAnnotationOptions(
        geometry: point,
        image: _pinIcon,
        iconSize: 0.25,
      ),
    );
  }

  Future<void> _handleSignUp() async {
    // Validate the form and ensure location coordinates are provided
    if (!_formKey.currentState!.validate() ||
        latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a location'),
        ),
      );
      return;
    }

    // Set loading state to true
    setState(() => _isLoading = true);

    // Initialize Supabase client and SharedPreferences
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    try {
      // Step 1: Insert location data into the 'locations' table
      final locationResponse = await supabase
          .from('locations')
          .insert({
            'latitude': latitude,
            'longitude': longitude,
            'address': addressController.text.trim(),
          })
          .select('id')
          .single();

      final locationId = locationResponse['id'];

      // Step 2: Prepare organization data and insert into the appropriate table
      final orgData = {
        'public_org_name': orgNameController.text.trim(),
        'address': addressController.text.trim(),
        'hotline_phone_number': hotlineController.text.trim(),
        'gmail_org_account': emailController.text.trim(),
        'org_password_hash':
            BCrypt.hashpw(passwordController.text.trim(), BCrypt.gensalt()),
        'location_id': locationId,
      };

      final orgResponse = await supabase
          .from(widget.orgType) // e.g., 'police', 'rescue'
          .insert(orgData)
          .select()
          .single();

      final orgId =
          orgResponse['id']; // Retrieve the newly created organization ID

      // Step 3: Store organization details in SharedPreferences
      await prefs.setBool("loggedIn", true);
      await prefs.setString("userType", "organization");
      await prefs.setString("orgType", widget.orgType);
      await prefs.setInt("orgId", orgId);
      await prefs.setString("orgName", orgNameController.text.trim());
      await prefs.setString("orgAddress", addressController.text.trim());

      // Step 4: Navigate to the verified success page.
      // This page will display the animated bouncing dialog with the appropriate
      // network image based on the public_org_name.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrgVerifiedSuccessfullyPage(
            publicOrgName: orgNameController.text.trim(),
          ),
        ),
      );

      // Step 5: After closing the verified success page, navigate to the Organization Home Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrganizationHomePage(
            orgName: orgNameController.text.trim(),
            orgAddress: addressController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      // Handle any errors during the signup process
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // Reset loading state
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Create ${widget.orgType[0].toUpperCase()}${widget.orgType.substring(1)} Account'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: orgNameController,
                decoration:
                    const InputDecoration(labelText: 'Organization Name *'),
                readOnly: true, // Make it read-only since it's pre-filled
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: hotlineController,
                decoration:
                    const InputDecoration(labelText: 'Hotline Number *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password *'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: mp.MapWidget(
                  onMapCreated: _onMapCreated,
                  onTapListener: _handleMapTap,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    orgNameController.dispose();
    addressController.dispose();
    hotlineController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
