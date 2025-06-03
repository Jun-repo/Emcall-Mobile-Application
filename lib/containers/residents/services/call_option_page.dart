// // ignore_for_file: deprecated_member_use

// import 'package:emcall/containers/residents/services/call_screen.dart';
// import 'package:emcall/containers/residents/services/stream_video_service.dart';

// import 'package:flutter/material.dart';
// import 'package:stream_video_flutter/stream_video_flutter.dart';

// class CallOptionsPage extends StatelessWidget {
//   final dynamic
//       service; // Adjust type based on your service model (e.g., Service)

//   const CallOptionsPage({super.key, required this.service});

//   Future<void> _startCall(BuildContext context, bool isVideo) async {
//     try {
//       // Initialize StreamVideo if not already initialized
//       await StreamVideoService.instance.initialize();

//       // Create a unique call ID
//       final callId =
//           '${service.serviceType.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';
//       final call = StreamVideoService.instance.client.makeCall(
//         callType: StreamCallType(),
//         id: callId,
//       );

//       // Configure call settings
//       await call.getOrCreate(
//         memberIds: [StreamVideoService.instance.client.currentUser.id],
//         ringing: true,
//       );

//       // Set audio/video settings
//       if (!isVideo) {
//         await call.setCameraEnabled(enabled: false);
//       }

//       // Join the call
//       await call.join();

//       // Navigate to call screen
//       if (context.mounted) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => CallScreen(call: call, isVideo: isVideo),
//           ),
//         );
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to start call: $e'),
//             action: SnackBarAction(
//               label: 'Retry',
//               onPressed: () => _startCall(context, isVideo),
//             ),
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Call ${service.orgName}'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               'Contact ${service.serviceType}',
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             Image.asset(
//               _getServiceImage(service.serviceType),
//               width: 60,
//               height: 60,
//               errorBuilder: (context, error, stackTrace) =>
//                   const Icon(Icons.error, size: 60, color: Colors.red),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               'Hotline: ${service.hotlineNumber}',
//               style: const TextStyle(fontSize: 16, color: Colors.grey),
//             ),
//             const SizedBox(height: 30),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.call),
//               label: const Text('Audio Call'),
//               onPressed: () => _startCall(context, false),
//               style: ElevatedButton.styleFrom(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//             const SizedBox(height: 10),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.videocam),
//               label: const Text('Video Call'),
//               onPressed: () => _startCall(context, true),
//               style: ElevatedButton.styleFrom(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                 backgroundColor: Colors.green,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _getServiceImage(String serviceType) {
//     switch (serviceType.toLowerCase()) {
//       case 'police':
//         return 'assets/images/police.png';
//       case 'rescue':
//         return 'assets/images/rescue.png';
//       case 'firefighter':
//         return 'assets/images/firefighter.png';
//       case 'disaster':
//         return 'assets/images/disaster.png';
//       default:
//         return 'assets/images/default.png';
//     }
//   }
// }
