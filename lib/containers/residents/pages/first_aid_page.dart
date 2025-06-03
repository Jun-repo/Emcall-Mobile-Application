// ignore_for_file: public_member_api_docs, sort_constructors_first, unrelated_type_equality_checks, use_build_context_synchronously
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:emcall/containers/residents/pages/comments_bottom_sheet.dart';
import 'package:emcall/containers/residents/share_reel_bottomsheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emcall/containers/residents/workers_stalk_account.dart';

class ReelProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> firstAidReels = [];
  List<Map<String, dynamic>> filteredReels = [];
  bool isLoading = true;
  String? errorMessage;
  ConnectivityResult connectionStatus = ConnectivityResult.none;
  bool isEndLoading = false;
  int? currentResidentId;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final int? initialReelId;
  RealtimeChannel? _commentsSubscription;
  Map<int, int> commentCounts = {};
  String selectedFilter = 'New Videos'; // Default filter
  Set<int> followedWorkerIds = {}; // Cache followed workers

  ReelProvider({this.initialReelId}) {
    _init();
  }

  // Check if the current resident is following a worker
  Future<bool> isFollowing(int workerId) async {
    if (currentResidentId == null) return false;
    return followedWorkerIds.contains(workerId);
  }

  // Fetch followed workers
  Future<void> _fetchFollowedWorkers() async {
    if (currentResidentId == null) return;
    try {
      final response = await supabase
          .from('follows')
          .select('worker_id')
          .eq('resident_id', currentResidentId!);
      followedWorkerIds = response.map((r) => r['worker_id'] as int).toSet();
    } catch (e) {
      followedWorkerIds = {};
    }
  }

  // Follow a worker
  Future<void> follow(int workerId) async {
    if (currentResidentId == null) return;
    try {
      await supabase.from('follows').insert({
        'resident_id': currentResidentId!,
        'worker_id': workerId,
      });
      followedWorkerIds.add(workerId);
      if (selectedFilter == 'Following') {
        await applyFilter(selectedFilter); // Refresh Following filter
      }
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  // Unfollow a worker
  Future<void> unfollow(int workerId) async {
    if (currentResidentId == null) return;
    try {
      await supabase.from('follows').delete().match({
        'resident_id': currentResidentId!,
        'worker_id': workerId,
      });
      followedWorkerIds.remove(workerId);
      if (selectedFilter == 'Following') {
        await applyFilter(selectedFilter); // Refresh Following filter
      }
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  // Toggle follow/unfollow
  Future<void> toggleFollow(int workerId,
      {bool isFollowing = false,
      required BuildContext context,
      String? username}) async {
    if (isFollowing) {
      final shouldUnfollow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.grey, width: 1.5),
          ),
          title: Text(
            'Unfollow from @${username ?? 'user'}?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Unfollow',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldUnfollow != true) return;
      await unfollow(workerId);
    } else {
      await follow(workerId);
    }
  }

  // Record a view for a reel
  Future<void> recordView(int reelId) async {
    if (currentResidentId == null) return;
    try {
      await supabase.from('reels_viewers').upsert({
        'reel_id': reelId,
        'resident_id': currentResidentId!,
      }, onConflict: 'reel_id, resident_id');
      await fetchReelData(reelId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _init() async {
    await _fetchCurrentResidentId();
    await _fetchFollowedWorkers(); // Initialize followed workers
    await _checkConnectivityAndFetch();
    if (initialReelId != null) {
      await fetchReelData(initialReelId!);
    }
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      connectionStatus = result;
      if (result == ConnectivityResult.none) {
        isLoading = false;
        errorMessage =
            'Oops! No Network Available.\nYoure offline!. Check your connection.';
        notifyListeners();
      } else if (errorMessage == 'No Network Available') {
        _fetchReels();
      }
    });
    _setupRealtimeCommentsSubscription();
    await applyFilter(selectedFilter);
  }

  void _setupRealtimeCommentsSubscription() {
    _commentsSubscription = supabase
        .channel('reels_comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reels_comments',
          callback: (payload) async {
            final reelId =
                payload.newRecord['reel_id'] ?? payload.oldRecord['reel_id'];
            if (reelId != null) {
              await fetchReelData(reelId);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchCurrentResidentId() async {
    final prefs = await SharedPreferences.getInstance();
    currentResidentId = prefs.getInt('resident_id');
    notifyListeners();
  }

  Future<void> _checkConnectivityAndFetch() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    connectionStatus = connectivityResult.isNotEmpty
        ? connectivityResult.first
        : ConnectivityResult.none;
    if (connectionStatus == ConnectivityResult.none) {
      errorMessage =
          'Oops! No Network Available.\nYoure offline!. Check your connection.';
      isLoading = false;
      notifyListeners();
    } else {
      await _fetchReels();
    }
  }

  Future<void> _fetchReels() async {
    isLoading = true;
    errorMessage = null;
    try {
      final response = await supabase.from('reels_videos').select('''
        id, title, description, video_url, thumbnail_url, created_at,
        workers (id, first_name, middle_name, last_name, suffix_name, organization_type, profile_image, username, phone, personal_email),
        reels_reactions (reaction_type, resident_id),
        reels_comments (id, comment_text, created_at, parent_comment_id, residents (first_name, middle_name, last_name, suffix_name, profile_image)),
        reels_shares (resident_id),
        reels_bad_reactions (resident_id),
        reels_viewers (resident_id)
      ''').order('created_at', ascending: false);
      firstAidReels = List<Map<String, dynamic>>.from(response);
      await applyFilter(selectedFilter); // Apply filter after fetch
    } catch (e) {
      errorMessage =
          'No internet Connection.\nConnect to the internet and try again.';
      isLoading = false;
    } finally {
      isLoading = false;
      notifyListeners(); // Notify once after all updates
    }
  }

  Future<void> fetchReelData(int reelId) async {
    try {
      final response = await supabase.from('reels_videos').select('''
        id, title, description, video_url, thumbnail_url, created_at,
        workers (id, first_name, middle_name, last_name, suffix_name, organization_type, profile_image, username, phone, personal_email),
        reels_reactions (reaction_type, resident_id),
        reels_comments (id, comment_text, created_at, parent_comment_id, residents (first_name, middle_name, last_name, suffix_name, profile_image)),
        reels_shares (resident_id),
        reels_bad_reactions (resident_id),
        reels_viewers (resident_id)
      ''').eq('id', reelId).single();
      final index = firstAidReels.indexWhere((reel) => reel['id'] == reelId);
      if (index != -1) {
        firstAidReels[index] = response;
      } else {
        firstAidReels.add(response);
      }
      await applyFilter(selectedFilter);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  // Re-fetch and apply filter
  Future<void> reloadAndApplyFilter(String filter) async {
    if (selectedFilter != filter) {
      selectedFilter = filter;
      await _fetchReels(); // Re-fetch reels from Supabase
    }
  }

  Future<void> applyFilter(String filter) async {
    filteredReels.clear();
    switch (filter) {
      case 'New Videos':
        filteredReels = List.from(firstAidReels)
          ..sort((a, b) => b['created_at'].compareTo(a['created_at']));
        break;
      case 'Following':
        filteredReels = firstAidReels
            .where((reel) => followedWorkerIds.contains(reel['workers']['id']))
            .toList();
        break;
      case 'Most Viewed':
        filteredReels = List.from(firstAidReels)
          ..sort((a, b) {
            final aViews = (a['reels_viewers'] as List<dynamic>).length;
            final bViews = (b['reels_viewers'] as List<dynamic>).length;
            return bViews.compareTo(aViews);
          });
        break;
    }
    // Notify listeners only after filter is applied
    notifyListeners();
  }

  void setEndLoading(bool value) {
    isEndLoading = value;
    notifyListeners();
  }

  void openNetworkSettings() {
    AppSettings.openAppSettings(type: AppSettingsType.wifi);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _commentsSubscription?.unsubscribe();
    super.dispose();
  }
}

class FirstAidPage extends StatelessWidget {
  final int? initialReelId;

  const FirstAidPage({super.key, this.initialReelId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReelProvider(initialReelId: initialReelId),
      child: DefaultTabController(
        length: 3, // Number of tabs
        child: Builder(
          builder: (context) {
            final provider = Provider.of<ReelProvider>(context, listen: false);
            final PageController pageController = PageController(
              initialPage:
                  provider.filteredReels.isNotEmpty && initialReelId != null
                      ? provider.filteredReels
                          .indexWhere((reel) => reel['id'] == initialReelId)
                          .clamp(0, provider.filteredReels.length - 1)
                      : 0,
            );

            return WillPopScope(
              onWillPop: () async {
                bool? exit = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    contentPadding: EdgeInsets.zero,
                    title: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Text(
                        'Exit App',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    content: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 24),
                      child: const Text(
                        'Are you sure you want to close the app?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 16,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Exit',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    actionsPadding: const EdgeInsets.only(bottom: 16),
                  ),
                );
                if (exit == true) {
                  SystemNavigator.pop();
                  return true;
                }
                return false;
              },
              child: Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent, // Invisible AppBar
                  elevation: 0,
                  toolbarHeight: 0, // Minimize AppBar height
                ),
                body: Stack(
                  fit: StackFit.expand, // Ensure content fills entire screen
                  children: [
                    Consumer<ReelProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.redAccent),
                          );
                        } else if (provider.errorMessage != null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons/no_internet.png',
                                  width: 140,
                                  height: 140,
                                ),
                                Text(
                                  provider.errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: provider.errorMessage ==
                                          'Oops! No Network Available.\nYoure offline!. Check your connection.'
                                      ? provider.openNetworkSettings
                                      : provider._checkConnectivityAndFetch,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    provider.errorMessage ==
                                            'Oops! No Network Available.\nYoure offline!. Check your connection.'
                                        ? 'CONNECT NETWORK'
                                        : 'RETRY',
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontFamily: 'Gilroy'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (provider.filteredReels.isEmpty) {
                          return Center(
                            child: Text(
                              provider.selectedFilter == 'Following'
                                  ? 'Follow workers to see their reels'
                                  : 'No Reels',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Gilroy',
                              ),
                            ),
                          );
                        } else {
                          return PageView.builder(
                            scrollDirection: Axis.vertical,
                            itemCount: provider.filteredReels.length + 1,
                            controller: pageController,
                            onPageChanged: (index) {
                              if (index == provider.filteredReels.length) {
                                provider.setEndLoading(true);
                                Future.delayed(const Duration(seconds: 1), () {
                                  provider.setEndLoading(false);
                                });
                              }
                            },
                            itemBuilder: (context, index) {
                              if (index == provider.filteredReels.length) {
                                return Center(
                                  child: provider.isEndLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.redAccent)
                                      : const Text(
                                          'No More Reels',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontFamily: 'Gilroy',
                                          ),
                                        ),
                                );
                              }
                              final reel = provider.filteredReels[index];
                              return VideoPlayerItem(
                                reelId: reel['id'],
                              );
                            },
                          );
                        }
                      },
                    ),
                    Positioned(
                      top: 1,
                      left: 35,
                      right: 35,
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        isScrollable: true,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white,
                        labelStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 5.0,
                              color: Colors.black54,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              blurRadius: 5.0,
                              color: Colors.black54,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                        indicator: PaddedIndicatorDecoration(
                          boxDecoration: BoxDecoration(
                            color: const Color.fromARGB(144, 255, 82, 82),
                            borderRadius: BorderRadius.circular(54),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: -8, vertical: 8),
                        ),
                        tabs: const [
                          Tab(text: 'New Videos'),
                          Tab(text: 'Following'),
                          Tab(text: 'Most Viewed'),
                        ],
                        onTap: (index) async {
                          final filters = [
                            'New Videos',
                            'Following',
                            'Most Viewed'
                          ];
                          await provider.reloadAndApplyFilter(filters[index]);
                          if (pageController.hasClients) {
                            pageController.jumpToPage(0);
                          }
                        },
                      ),
                    ),
                    if (initialReelId != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 5.0,
                                color: Colors.black54,
                                offset: Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PaddedIndicatorDecoration extends Decoration {
  final BoxDecoration boxDecoration;
  @override
  final EdgeInsets padding;

  const PaddedIndicatorDecoration({
    required this.boxDecoration,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PaddedIndicatorPainter(boxDecoration, padding, onChanged);
  }
}

class _PaddedIndicatorPainter extends BoxPainter {
  final BoxDecoration boxDecoration;
  final EdgeInsets padding;

  _PaddedIndicatorPainter(this.boxDecoration, this.padding,
      [VoidCallback? onChanged]);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Size size = configuration.size!;
    // Calculate the padded area
    final Rect rect = Offset(
          offset.dx + padding.left,
          offset.dy + padding.top,
        ) &
        Size(
          size.width - padding.horizontal,
          size.height - padding.vertical,
        );
    // Draw the BoxDecoration within the padded rect
    final Paint paint = Paint()
      ..color = boxDecoration.color ?? Colors.transparent;
    final BorderRadius? borderRadius =
        boxDecoration.borderRadius?.resolve(TextDirection.ltr);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, borderRadius?.topLeft ?? Radius.zero),
      paint,
    );
  }
}

class VideoPlayerItem extends StatelessWidget {
  final int reelId;

  const VideoPlayerItem({
    super.key,
    required this.reelId,
  });

  void _showDescriptionBottomSheet(BuildContext context, String description) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'Gilroy',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReelProvider>(context, listen: false);
    final reel = provider.filteredReels.firstWhere((r) => r['id'] == reelId);
    final worker = reel['workers'] as Map<String, dynamic>;
    final workerId = worker['id'] as int;
    final description = reel['description'] ?? '';
    final viewCount =
        (reel['reels_viewers'] as List<dynamic>).length; // Get view count
    const maxDescriptionLength = 30;

    // Record view when the reel is displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.recordView(reelId);
    });

    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlaybackWidget(
          videoUrl: reel['video_url'],
          viewCount: viewCount, // Pass view count
        ),
        Positioned(
          bottom: 10,
          left: 16,
          right: 16,
          child: Consumer<ReelProvider>(
            builder: (context, provider, child) {
              final reelData =
                  provider.filteredReels.firstWhere((r) => r['id'] == reelId);
              final worker = reelData['workers'] as Map<String, dynamic>;
              final username = worker['username'] ?? 'user';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkersStalkAccount(
                                workerId: workerId,
                                supabase: provider.supabase,
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: worker['profile_image'] != null
                              ? NetworkImage(worker['profile_image'])
                              : null,
                          child: worker['profile_image'] == null
                              ? const Icon(Icons.person,
                                  size: 24, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '@$username (${worker['organization_type']})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gilroy',
                          shadows: [
                            Shadow(
                                blurRadius: 5.0,
                                color: Colors.black54,
                                offset: Offset(1.0, 1.0)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          FutureBuilder<bool>(
                            future: provider.isFollowing(workerId),
                            builder: (context, snapshot) {
                              final isFollowing = snapshot.data ?? false;
                              return GestureDetector(
                                onTap: () async {
                                  await provider.toggleFollow(
                                    workerId,
                                    isFollowing: isFollowing,
                                    context: context,
                                    username: username,
                                  );
                                },
                                child: Card(
                                  color: isFollowing
                                      ? const Color.fromARGB(108, 103, 103, 103)
                                      : Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(54),
                                      bottomLeft: Radius.circular(54),
                                      topRight: Radius.circular(54),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: isFollowing
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reelData['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Gilroy',
                      shadows: [
                        Shadow(
                            blurRadius: 10.0,
                            color: Colors.black54,
                            offset: Offset(2.0, 2.0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  description.length > maxDescriptionLength
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${description.substring(0, maxDescriptionLength)}...',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontFamily: 'Gilroy',
                                  shadows: [
                                    Shadow(
                                        blurRadius: 5.0,
                                        color: Colors.black54,
                                        offset: Offset(1.0, 1.0)),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showDescriptionBottomSheet(
                                  context, description),
                              child: const Text(
                                'show more',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 5.0,
                                        color: Colors.black54,
                                        offset: Offset(1.0, 1.0)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontFamily: 'Gilroy',
                            shadows: [
                              Shadow(
                                  blurRadius: 5.0,
                                  color: Colors.black54,
                                  offset: Offset(1.0, 1.0)),
                            ],
                          ),
                        ),
                ],
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 150,
          child: ReelInteractionWidget(
            reelId: reelId,
          ),
        ),
      ],
    );
  }
}

class VideoPlaybackWidget extends StatefulWidget {
  final String videoUrl;
  final int viewCount;

  const VideoPlaybackWidget({
    super.key,
    required this.videoUrl,
    required this.viewCount,
  });

  @override
  State<VideoPlaybackWidget> createState() => _VideoPlaybackWidgetState();
}

class _VideoPlaybackWidgetState extends State<VideoPlaybackWidget>
    with SingleTickerProviderStateMixin {
  late CachedVideoPlayerPlusController _controller;
  bool _showIcon = false;
  String? _iconType; // 'play', 'pause', 'rewind', 'fast_forward'
  Timer? _hideTimer;
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  bool _isAnimationInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize video controller
    _controller = CachedVideoPlayerPlusController.networkUrl(
      Uri.parse(widget.videoUrl),
      invalidateCacheIfOlderThan: const Duration(days: 1),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });
    _controller.setLooping(true);

    // Initialize animation controller
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );

      _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController!,
          curve: const Interval(0.0, 0.5, curve: Curves.bounceOut),
          reverseCurve: const Interval(0.0, 0.5, curve: Curves.easeIn),
        ),
      );

      _isAnimationInitialized = true;
    } catch (e) {
      _isAnimationInitialized = false;
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _iconType = 'pause';
      } else {
        _controller.play();
        _iconType = 'play';
      }
      _showIcon = true;
      if (_isAnimationInitialized && _animationController != null) {
        _animationController!.reset();
        _animationController!.forward();
      }
      _startHideTimer();
    });
  }

  void _seekBackward() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      _iconType = 'rewind';
      _showIcon = true;
      final currentPosition = _controller.value.position;
      final newPosition = currentPosition - const Duration(seconds: 3);
      _controller
          .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
      if (_isAnimationInitialized && _animationController != null) {
        _animationController!.reset();
        _animationController!.forward();
      }
      _startHideTimer();
    });
  }

  void _seekForward() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      _iconType = 'fast_forward';
      _showIcon = true;
      final currentPosition = _controller.value.position;
      final duration = _controller.value.duration;
      final newPosition = currentPosition + const Duration(seconds: 3);
      _controller.seekTo(newPosition > duration ? duration : newPosition);
      if (_isAnimationInitialized && _animationController != null) {
        _animationController!.reset();
        _animationController!.forward();
      }
      _startHideTimer();
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isAnimationInitialized && _animationController != null) {
        _animationController!.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showIcon = false;
              _iconType = null;
            });
          }
        });
      } else if (mounted) {
        setState(() {
          _showIcon = false;
          _iconType = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTapDown: (TapDownDetails details) {
              final screenWidth = MediaQuery.of(context).size.width;
              final tapPositionX = details.localPosition.dx;
              if (tapPositionX < screenWidth / 2) {
                // Left half: Seek backward
                _seekBackward();
              } else {
                // Right half: Seek forward
                _seekForward();
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                CachedVideoPlayerPlus(_controller),
                _showIcon &&
                        _isAnimationInitialized &&
                        _animationController != null
                    ? ScaleTransition(
                        scale: _scaleAnimation!,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.redAccent.withOpacity(0.3),
                          child: Icon(
                            _iconType == 'pause'
                                ? Icons.pause_outlined
                                : _iconType == 'play'
                                    ? Icons.play_arrow_rounded
                                    : _iconType == 'rewind'
                                        ? Icons.fast_rewind_outlined
                                        : Icons.fast_forward_outlined,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : _showIcon
                        ? CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.redAccent.withOpacity(0.5),
                            child: Icon(
                              _iconType == 'pause'
                                  ? Icons.pause_outlined
                                  : _iconType == 'play'
                                      ? Icons.play_arrow_rounded
                                      : _iconType == 'rewind'
                                          ? Icons.fast_rewind_outlined
                                          : Icons.fast_forward_outlined,
                              size: 50,
                              color: Colors.white,
                            ),
                          )
                        : const SizedBox.shrink(),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      backgroundColor: Colors.black,
                      bufferedColor: Colors.grey,
                      playedColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}

class ReelInteractionWidget extends StatelessWidget {
  final int reelId;

  const ReelInteractionWidget({
    super.key,
    required this.reelId,
  });

  void _openComments(BuildContext context) {
    final provider = Provider.of<ReelProvider>(context, listen: false);
    final reel = provider.firstAidReels.firstWhere((r) => r['id'] == reelId);
    final workerUsername = reel['workers']['username'] ?? 'user';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.5),
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CommentsBottomSheet(
          reelId: reel['id'],
          initialComments: reel['reels_comments'] as List<dynamic>,
          supabase: provider.supabase,
          workerUsername: workerUsername, // Pass worker's username
        );
      },
    );
  }

  Future<void> _toggleReaction(BuildContext context) async {
    final provider = Provider.of<ReelProvider>(context, listen: false);
    final residentId = provider.currentResidentId;
    if (residentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to react')),
      );
      return;
    }
    final reel = provider.firstAidReels.firstWhere((r) => r['id'] == reelId);
    final reactions = reel['reels_reactions'] as List<dynamic>;
    final userReaction = reactions.firstWhere(
      (r) => r['resident_id'] == residentId,
      orElse: () => null,
    );
    try {
      if (userReaction != null) {
        await provider.supabase.from('reels_reactions').delete().match({
          'reel_id': reelId,
          'resident_id': residentId,
        });
      } else {
        await provider.supabase.from('reels_reactions').insert({
          'reel_id': reelId,
          'resident_id': residentId,
          'reaction_type': 'like',
        });
      }
      await provider.fetchReelData(reelId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling reaction: $e')),
      );
    }
  }

  Future<void> _onSelectReaction(
      BuildContext context, String reactionType) async {
    final provider = Provider.of<ReelProvider>(context, listen: false);
    final residentId = provider.currentResidentId;
    if (residentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to react')),
      );
      return;
    }
    try {
      await provider.supabase.from('reels_reactions').upsert({
        'reel_id': reelId,
        'resident_id': residentId,
        'reaction_type': reactionType,
      }, onConflict: 'reel_id, resident_id');
      await provider.fetchReelData(reelId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting reaction: $e')),
      );
    }
  }

  Future<void> _toggleBadReaction(BuildContext context) async {
    final provider = Provider.of<ReelProvider>(context, listen: false);
    final residentId = provider.currentResidentId;
    if (residentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to react')),
      );
      return;
    }
    final reel = provider.firstAidReels.firstWhere((r) => r['id'] == reelId);
    final badReactions = reel['reels_bad_reactions'] as List<dynamic>;
    final userBadReaction = badReactions.firstWhere(
      (r) => r['resident_id'] == residentId,
      orElse: () => null,
    );
    try {
      if (userBadReaction != null) {
        await provider.supabase.from('reels_bad_reactions').delete().match({
          'reel_id': reelId,
          'resident_id': residentId,
        });
      } else {
        await provider.supabase.from('reels_bad_reactions').insert({
          'reel_id': reelId,
          'resident_id': residentId,
        });
      }
      await provider.fetchReelData(reelId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling bad reaction: $e')),
      );
    }
  }

  void _showShareBottomSheet(BuildContext context) {
    final provider = Provider.of<ReelProvider>(context, listen: false);
    final reel = provider.firstAidReels.firstWhere((r) => r['id'] == reelId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareReelBottomSheet(
        videoUrl: reel['video_url'],
        videoTitle: reel['title'] ?? 'First Aid Reel',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, provider, child) {
        final reel =
            provider.firstAidReels.firstWhere((r) => r['id'] == reelId);
        final worker = reel['workers'] as Map<String, dynamic>;
        final reactions = reel['reels_reactions'] as List<dynamic>;
        final badReactions = reel['reels_bad_reactions'] as List<dynamic>;
        final userReaction = reactions.firstWhere(
          (r) => r['resident_id'] == provider.currentResidentId,
          orElse: () => null,
        );
        badReactions.firstWhere(
          (r) => r['resident_id'] == provider.currentResidentId,
          orElse: () => null,
        );
        final String? currentReactionType = userReaction?['reaction_type'];
        final int totalCount = reactions.length;
        final int badCount = badReactions.length;
        final int commentCount = reel['reels_comments'].length;

        return Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () {
                    final int? workerId =
                        reel['worker_id'] ?? reel['workers']?['id'];
                    if (workerId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkersStalkAccount(
                            workerId: workerId,
                            supabase: provider.supabase,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Worker ID not available')),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 25,
                    backgroundImage: worker['profile_image'] != null
                        ? NetworkImage(worker['profile_image'])
                        : null,
                    child: worker['profile_image'] == null
                        ? const Icon(Icons.person,
                            size: 30, color: Colors.white)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: -8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ReactionButton(
              currentReactionType: currentReactionType,
              totalCount: totalCount,
              onToggle: () => _toggleReaction(context),
              onSelectReaction: (reactionType) =>
                  _onSelectReaction(context, reactionType),
            ),
            const SizedBox(height: 2),
            Text(
              formatNumber(totalCount), // Use formatNumber for reactions
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Gilroy',
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    'assets/icons/dislike.png',
                    width: 30,
                    height: 30,
                  ),
                  onPressed: () => _toggleBadReaction(context),
                ),
                const SizedBox(height: 2),
                Text(
                  formatNumber(badCount), // Use formatNumber for bad reactions
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    'assets/icons/comment.png',
                    width: 35,
                    height: 35,
                  ),
                  onPressed: () => _openComments(context),
                ),
                const SizedBox(height: 2),
                Text(
                  formatNumber(commentCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    'assets/icons/share.png',
                    width: 30,
                    height: 30,
                  ),
                  onPressed: () => _showShareBottomSheet(context),
                  tooltip: 'Share',
                ),
                const SizedBox(height: 2),
                const Text(
                  "Share",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Gilroy',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ReactionButton extends StatefulWidget {
  final String? currentReactionType;
  final int totalCount;
  final VoidCallback onToggle;
  final Function(String) onSelectReaction;

  const ReactionButton({
    super.key,
    required this.currentReactionType,
    required this.totalCount,
    required this.onToggle,
    required this.onSelectReaction,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  String _getReactionEmoji(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'hahaha':
        return '😂';

      case 'angry':
        return '😡';
      default:
        return '💭'; // Default emoji for no reaction
    }
  }

  void _showReactionOverlay(Offset iconPosition) {
    // Remove any existing overlay
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay, // Close overlay when tapping outside
        child: Stack(
          children: [
            Positioned(
              top: iconPosition.dy + 40, // Align vertically with the icon
              left: iconPosition.dx - 200, // Position to the left
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Card(
                      color: const Color.fromARGB(255, 240, 242, 245),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(36),
                          bottomLeft: Radius.circular(36),
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(36),
                        ),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildReactionButton('like', '👍'),
                            const SizedBox(width: 10),
                            _buildReactionButton('love', '❤️'),
                            const SizedBox(width: 10),
                            _buildReactionButton('hahaha', '😂'),
                            const SizedBox(width: 10),
                            _buildReactionButton('angry', '😡'),
                          ],
                        ),
                      ),
                    ),
                    // Bubble 1: Top-right
                    Positioned(
                      top: -5,
                      right: -10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 240, 242, 245),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController?.forward(); // Start bubble animation
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animationController?.stop(); // Stop bubble animation
  }

  Widget _buildReactionButton(String reactionType, String emoji) {
    return Semantics(
      label: reactionType,
      button: true,
      child: GestureDetector(
        onTap: () {
          widget.onSelectReaction(reactionType);
          _removeOverlay();
        },
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onLongPress: () {
            // Get the position of the reaction icon
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero);
            _showReactionOverlay(position);
          },
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Semantics(
              label: 'Reaction: ${widget.currentReactionType ?? "none"}',
              child: Text(
                _getReactionEmoji(widget.currentReactionType),
                style: const TextStyle(
                  fontSize: 35,
                ),
              ),
            ),
            onPressed: widget.onToggle,
          ),
        ),
      ],
    );
  }
}

String formatNumber(int number) {
  if (number < 1000) {
    return number.toString();
  } else if (number < 1000000) {
    double value = number / 1000;
    return value % 1 == 0
        ? '${value.toInt()}K'
        : '${value.toStringAsFixed(1)}K';
  } else if (number < 1000000000) {
    double value = number / 1000000;
    return value % 1 == 0
        ? '${value.toInt()}M'
        : '${value.toStringAsFixed(1)}M';
  } else {
    double value = number / 1000000000;
    return value % 1 == 0
        ? '${value.toInt()}B'
        : '${value.toStringAsFixed(1)}B';
  }
}
