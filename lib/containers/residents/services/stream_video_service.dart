// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:stream_video/stream_video.dart' as stream_video;
// import 'package:stream_video_flutter/stream_video_flutter.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class StreamVideoService {
//   static StreamVideoService? _instance;
//   StreamVideo? _client;
//   bool _isInitialized = false;

//   StreamVideoService._();

//   // Singleton instance
//   static StreamVideoService get instance {
//     _instance ??= StreamVideoService._();
//     return _instance!;
//   }

//   // Initialize StreamVideo with API key from .env
//   Future<void> initialize() async {
//     if (_isInitialized) return;

//     final apiKey = dotenv.env['STREAM_VIDEO_API_KEY'];
//     if (apiKey == null || apiKey.isEmpty) {
//       throw Exception('StreamVideo API key is missing in .env');
//     }

//     try {
//       final user = await _getCurrentUser();
//       final userToken = await _fetchUserToken(user.id);

//       _client = StreamVideo(
//         apiKey,
//         user: stream_video.User.regular(
//           userId: user.id,
//           role: user.role,
//           name: user.name,
//         ),
//         userToken: userToken,
//       );
//       _isInitialized = true;
//     } catch (e) {
//       _isInitialized = false;
//       throw Exception('Failed to initialize StreamVideo: $e');
//     }
//   }

//   // Get the initialized client
//   StreamVideo get client {
//     if (!_isInitialized || _client == null) {
//       throw Exception('StreamVideo is not initialized');
//     }
//     return _client!;
//   }

//   // Fetch current user from SharedPreferences
//   Future<_StreamUser> _getCurrentUser() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userId = prefs.getString('residentId') ?? 'unknown_user';
//     final userType = prefs.getString('userType') ?? 'resident';
//     final name = prefs.getString('username') ?? 'User';

//     return _StreamUser(
//       id: userId,
//       role: userType,
//       name: name,
//     );
//   }

//   // Simulate fetching user token (replace with actual backend call)
//   // In your StreamVideoService class
//   Future<String> _fetchUserToken(String userId) async {
//     final response = await Supabase.instance.client.functions.invoke(
//       'stream_token',
//       body: {'userId': userId},
//     );

//     if (response.status != 200 || response.data['token'] == null) {
//       throw Exception(
//           'Failed to fetch token: ${response.data['error'] ?? 'Unknown error'}');
//     }

//     return response.data['token'];
//   }

//   // Clean up
//   void dispose() {
//     stream_video.StreamVideo.reset();
//     _isInitialized = false;
//   }
// }

// // Helper class for user data
// class _StreamUser {
//   final String id;
//   final String role;
//   final String name;

//   _StreamUser({required this.id, required this.role, required this.name});
// }
