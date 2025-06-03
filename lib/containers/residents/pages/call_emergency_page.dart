// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:emcall/pages/services/service_info.dart';
import 'package:emcall/containers/residents/pages/resident_emergency_map_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CallEmergencyPage extends StatefulWidget {
  final ServiceInfo service;
  final Position? currentPosition;

  const CallEmergencyPage({
    super.key,
    required this.service,
    this.currentPosition,
  });

  @override
  CallEmergencyPageState createState() => CallEmergencyPageState();
}

class CallEmergencyPageState extends State<CallEmergencyPage> {
  int _secondsRemaining = 59;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    debugPrint(
        "Current position: lat=${widget.currentPosition?.latitude}, lng=${widget.currentPosition?.longitude}");
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _launchCaller();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _launchCaller() async {
    final Uri launchUri =
        Uri(scheme: 'tel', path: widget.service.hotlineNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Could not launch call to ${widget.service.hotlineNumber}')),
        );
      }
    }
  }

  Future<void> _recordServiceCall() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    int? residentId = prefs.getInt('resident_id');
    if (residentId == null) {
      debugPrint("Resident ID not found in SharedPreferences.");
      return;
    }

    // Log authentication status
    final user = Supabase.instance.client.auth.currentUser;
    debugPrint("Current user ID: ${user?.id}, residentId: $residentId");

    double latitude = 0.0;
    double longitude = 0.0;
    if (widget.currentPosition != null) {
      latitude = widget.currentPosition!.latitude;
      longitude = widget.currentPosition!.longitude;
      debugPrint("Using passed position: lat=$latitude, lng=$longitude");
    } else {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
        latitude = position.latitude;
        longitude = position.longitude;
        debugPrint("Fetched position: lat=$latitude, lng=$longitude");
      } catch (e) {
        debugPrint("Error fetching position: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    }

    try {
      await Supabase.instance.client.from('service_calls').upsert(
        {
          'resident_id': residentId,
          'service_type': widget.service.serviceType.toLowerCase(),
          'service_id': widget.service.id,
          'shared_location': true,
          'call_time': DateTime.now().toIso8601String(),
        },
        onConflict:
            'resident_id,service_type', // ← comma-separated string, not a List
      ).select();

      debugPrint("Inserted into service_calls successfully");

      final existingLocation = await supabase
          .from('live_locations')
          .select()
          .eq('resident_id', residentId)
          .maybeSingle();
      debugPrint("Existing location: $existingLocation");

      if (existingLocation == null) {
        await supabase.from('live_locations').insert({
          'resident_id': residentId,
          'latitude': latitude,
          'longitude': longitude,
          'is_sharing': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint("Inserted new live_locations row with is_sharing: true");
      } else {
        await supabase.from('live_locations').update({
          'is_sharing': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('resident_id', residentId);
        debugPrint("Updated live_locations with is_sharing: true");
      }

      debugPrint("Successfully updated live_locations with is_sharing: true");
    } catch (e) {
      debugPrint("Error recording service call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording service call: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 65,
                      backgroundColor: Colors.white70,
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.phone_in_talk_rounded,
                            color: Colors.grey, size: 60),
                      ),
                    ),
                    const SizedBox(height: 70),
                    Center(
                      child: Text(
                        'Emergency Help Needed?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gilroy',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${widget.service.orgName} is always ready to help you!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 12),
                        child: Text(
                          '${_secondsRemaining}s',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _countdownTimer?.cancel();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.black,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.red, size: 32),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            _countdownTimer?.cancel();
                            await _recordServiceCall();
                            await _launchCaller();
                            if (mounted) {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ResidentEmergencyMapPage(
                                    initialPosition: widget.currentPosition,
                                    serviceType: widget.service.serviceType
                                        .toLowerCase(),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.black,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.green, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
