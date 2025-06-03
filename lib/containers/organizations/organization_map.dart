import 'package:emcall/components/maps/emcall_map.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrganizationMap extends StatefulWidget {
  const OrganizationMap({super.key});

  @override
  OrganizationMapState createState() => OrganizationMapState();
}

class OrganizationMapState extends State<OrganizationMap> {
  late Future<List<Map<String, dynamic>>> _callRecordsFuture;

  @override
  void initState() {
    super.initState();
    _callRecordsFuture = _fetchCallRecords();
  }

  Future<List<Map<String, dynamic>>> _fetchCallRecords() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    String? orgName = prefs.getString("orgName");
    String? filterServiceType;

    if (orgName != null) {
      final orgLower = orgName.toLowerCase();
      if (orgLower.contains("police") || orgLower.contains("pnp")) {
        filterServiceType = 'police';
      } else if (orgLower.contains("rescue")) {
        filterServiceType = 'rescue';
      } else if (orgLower.contains("fire")) {
        filterServiceType = 'firefighter';
      } else if (orgLower.contains("disaster")) {
        filterServiceType = 'disaster_responder';
      }
    }

    // Corrected query building sequence
    var query = supabase.from('service_calls').select(
        'id, shared_location, call_time, residents(first_name, last_name, resident_profile_image, locations(address, latitude, longitude))');

    // Apply filter before ordering
    if (filterServiceType != null) {
      query = query.eq('service_type', filterServiceType);
    }

    // Add ordering after filtering
    query = query.filter('service_type', 'eq', filterServiceType);
    final response = await query;
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> _markServiceDone(int callId) async {
    final supabase = Supabase.instance.client;
    await supabase
        .from('service_calls')
        .update({'shared_location': false}).eq('id', callId);
    setState(() {
      _callRecordsFuture = _fetchCallRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const EmcallMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              color: Colors.white.withOpacity(0.9),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _callRecordsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final calls = snapshot.data!;
                  if (calls.isEmpty) {
                    return const Center(child: Text('No calls recorded yet.'));
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: calls.length,
                    itemBuilder: (context, index) {
                      final call = calls[index];
                      final resident =
                          call['residents'] as Map<String, dynamic>?;
                      final location =
                          resident?['locations'] as Map<String, dynamic>?;

                      final residentName = resident != null
                          ? '${resident['first_name']} ${resident['last_name']}'
                          : 'Unknown Resident';

                      final profileImageUrl = resident != null
                          ? resident['resident_profile_image'] as String?
                          : null;

                      final address = location != null
                          ? location['address'] ?? 'No address'
                          : 'No address';

                      final shared = call['shared_location'] as bool? ?? false;

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 240,
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: profileImageUrl != null
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                    child: profileImageUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          residentName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          address,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (shared)
                                ElevatedButton(
                                  onPressed: () =>
                                      _markServiceDone(call['id'] as int),
                                  child: const Text('Service Done'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
