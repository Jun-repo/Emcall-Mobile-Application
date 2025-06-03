import 'package:emcall/containers/residents/pages/first_aid_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkersStalkAccount extends StatefulWidget {
  final int workerId;
  final SupabaseClient supabase;

  const WorkersStalkAccount({
    super.key,
    required this.workerId,
    required this.supabase,
  });

  @override
  State<WorkersStalkAccount> createState() => _WorkersStalkAccountState();
}

class _WorkersStalkAccountState extends State<WorkersStalkAccount> {
  Map<String, dynamic>? workerData;
  List<Map<String, dynamic>> workerVideos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkerData();
    _fetchWorkerVideos();
  }

  Future<void> _fetchWorkerData() async {
    try {
      final response = await widget.supabase
          .from('workers')
          .select(
              'id, first_name, middle_name, last_name, suffix_name, organization_type, profile_image, username, phone, personal_email')
          .eq('id', widget.workerId)
          .single();
      if (mounted) {
        setState(() {
          workerData = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching worker data: $e')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWorkerVideos() async {
    try {
      final response = await widget.supabase
          .from('reels_videos')
          .select('''
              id, title, description, video_url, thumbnail_url, created_at,
              reels_viewers (resident_id)
              ''')
          .eq('worker_id', widget.workerId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          workerVideos = List<Map<String, dynamic>>.from(response).map((video) {
            return {
              ...video,
              'view_count': (video['reels_viewers'] as List<dynamic>).length,
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching videos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : workerData == null
                  ? const Center(child: Text('No data available'))
                  : CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 250.0,
                          floating: false,
                          pinned: true,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Padding(
                              padding: const EdgeInsets.only(
                                  top: 56.0, bottom: 16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color.fromARGB(
                                        255, 212, 212, 212),
                                    radius: 50,
                                    backgroundImage:
                                        workerData!['profile_image'] != null
                                            ? NetworkImage(
                                                workerData!['profile_image'])
                                            : null,
                                    child: workerData!['profile_image'] == null
                                        ? const Icon(Icons.person,
                                            size: 50, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    [
                                      workerData!['first_name'],
                                      workerData!['middle_name']?.isNotEmpty ==
                                              true
                                          ? '${workerData!['middle_name'][0]}.'
                                          : '',
                                      workerData!['last_name'],
                                      workerData!['suffix_name']?.isNotEmpty ==
                                              true
                                          ? workerData!['suffix_name']
                                          : '',
                                    ]
                                        .where((part) => part.isNotEmpty)
                                        .join(' '),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Gilroy',
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '(${workerData!['username']})',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color.fromARGB(255, 74, 74, 77),
                                      fontFamily: 'Gilroy',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildListDelegate([
                            Container(
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(0.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (workerData!['phone'] != null)
                                      ListTile(
                                        leading: const Icon(Icons.phone),
                                        title: Text(workerData!['phone']),
                                      ),
                                    workerVideos.isEmpty
                                        ? const Text(
                                            'No videos available',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                              fontFamily: 'Gilroy',
                                            ),
                                          )
                                        : GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 1,
                                              mainAxisSpacing: 1,
                                              childAspectRatio: 9 / 16,
                                            ),
                                            itemCount: workerVideos.length,
                                            itemBuilder: (context, index) {
                                              final video = workerVideos[index];
                                              final viewCount =
                                                  video['view_count'] ?? 0;
                                              return GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          FirstAidPage(
                                                              initialReelId:
                                                                  video['id']),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    child: Stack(
                                                      fit: StackFit.expand,
                                                      children: [
                                                        Image.network(
                                                          video['thumbnail_url'] ??
                                                              'https://via.placeholder.com/150',
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) =>
                                                              const Icon(
                                                            Icons.videocam_off,
                                                            size: 50,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                        // Title at the bottom
                                                        Positioned(
                                                          bottom: 0,
                                                          left: 0,
                                                          right: 0,
                                                          child: Container(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.6),
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4.0),
                                                            child: Text(
                                                              video['title'] ??
                                                                  'Untitled',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .white,
                                                                fontFamily:
                                                                    'Gilroy',
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                        // View count with play icon at top-right
                                                        Positioned(
                                                          top: 4,
                                                          right: 4,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Icon(
                                                                  Icons
                                                                      .play_arrow_outlined,
                                                                  size: 22,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  formatNumber(
                                                                      viewCount),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }
}
