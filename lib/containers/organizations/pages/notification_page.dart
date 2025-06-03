import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  final String userType;

  NotificationPage({required this.userType});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _expandedIndex = -1; // Track which notification is expanded for buttons

  Future<List<Map<String, dynamic>>> fetchUnseenCalls() async {
    final response =
        await Supabase.instance.client.from('service_calls').select('''
          id, call_time, service_type, is_seen,
          residents!inner(first_name, last_name, profile_image)
        ''').eq('service_type', widget.userType).eq('is_seen', false);
    return response;
  }

  Future<void> markCallAsSeen(int callId, bool isSeen) async {
    await Supabase.instance.client
        .from('service_calls')
        .update({'is_seen': isSeen}).eq('id', callId);
    setState(() {
      _expandedIndex = -1; // Collapse buttons after action
    });
  }

  Future<void> markAllAsRead() async {
    final callIds =
        (await fetchUnseenCalls()).map((call) => call['id']).toList();
    if (callIds.isNotEmpty) {
      await Supabase.instance.client
          .from('service_calls')
          .update({'is_seen': true}).inFilter('id', callIds);
      setState(() {
        _expandedIndex = -1; // Collapse any expanded buttons
      });
    }
  }

  String getRelativeTime(DateTime callTime) {
    final now = DateTime.now();
    final difference = now.difference(callTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your notifications'),
            GestureDetector(
              onTap: markAllAsRead,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: Text(
                  'Seen All',
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                      fontFamily: 'Gilroy'),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchUnseenCalls(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No unseen calls'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final call = snapshot.data![index];
                    final resident = call['residents'];
                    final callTime = DateTime.parse(call['call_time']);
                    final formattedTime =
                        DateFormat('EEEE h:mma').format(callTime);
                    final relativeTime = getRelativeTime(callTime);
                    final username =
                        '@${resident['first_name'].toLowerCase()}${resident['last_name'].toLowerCase()}';

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _expandedIndex = _expandedIndex == index ? -1 : index;
                        });
                      },
                      onTap: () async {
                        await markCallAsSeen(call['id'], true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: resident['profile_image'] !=
                                          null &&
                                      resident['profile_image'].isNotEmpty
                                  ? NetworkImage(resident['profile_image'])
                                  : AssetImage(
                                          'assets/images/profile_placeholder.png')
                                      as ImageProvider,
                              onBackgroundImageError: (exception, stackTrace) {
                                print('Image load error: $exception');
                              },
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: username,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black),
                                            ),
                                            TextSpan(
                                              text: ' Reaching you',
                                              style: TextStyle(
                                                  color: Colors.black),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(relativeTime,
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                          SizedBox(width: 8),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(formattedTime,
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  if (_expandedIndex ==
                                      index) // Show buttons on long press
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              await markCallAsSeen(
                                                  call['id'], false);
                                            },
                                            child: Text('Wait',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              await markCallAsSeen(
                                                  call['id'], true);
                                            },
                                            child: Text('Accept',
                                                style: TextStyle(
                                                    color: Colors.blue)),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
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
        ],
      ),
    );
  }
}
