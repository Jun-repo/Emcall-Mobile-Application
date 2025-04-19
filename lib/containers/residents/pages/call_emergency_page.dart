// call_emergency_page.dart

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
    if (residentId == null) return;

    try {
      await supabase.from('service_calls').insert({
        'resident_id': residentId,
        'service_type': widget.service.serviceType.toLowerCase(),
        'service_id': widget.service.id,
        'shared_location': true,
      });

      // Update live_locations
      await supabase.from('live_locations').upsert({
        'resident_id': residentId,
        'latitude': widget.currentPosition?.latitude ?? 0.0,
        'longitude': widget.currentPosition?.longitude ?? 0.0,
        'is_sharing': true,
      });
    } catch (e) {
      debugPrint("Error recording service call: $e");
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
                    Text(
                      'Emergency Help Needed?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Gilroy',
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
                              Navigator.of(this.context).pop();
                              Navigator.push(
                                this.context,
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
