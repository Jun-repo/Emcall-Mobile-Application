// import 'package:flutter/material.dart';
// import 'package:stream_video_flutter/stream_video_flutter.dart';

// class CallScreen extends StatefulWidget {
//   final Call call;
//   final bool isVideo;

//   const CallScreen({super.key, required this.call, required this.isVideo});

//   @override
//   State<CallScreen> createState() => _CallScreenState();
// }

// class _CallScreenState extends State<CallScreen> {
//   String _callStatus = 'Connecting...';

//   @override
//   void initState() {
//     super.initState();
//     _listenToCallState();
//   }

//   void _listenToCallState() {
//     widget.call.state.listen((state) {
//       if (mounted) {
//         setState(() {
//           if (state.status.isDisconnected) {
//             _callStatus = 'Call Ended';
//             Future.delayed(const Duration(seconds: 1), () {
//               if (mounted) Navigator.pop(context);
//             });
//           } else if (state.status.isConnecting) {
//             _callStatus = 'Connecting...';
//           } else if (state.status.isConnected) {
//             _callStatus = 'Connected';
//           } else if (state.status.isReconnecting) {
//             _callStatus = 'Reconnecting...';
//           }
//         });
//       }
//     });
//   }

//   @override
//   void dispose() {
//     widget.call.leave();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: StreamCallContainer(
//         call: widget.call,
//         callContentBuilder: (context, call, callState) {
//           final localParticipant = callState.localParticipant;
//           if (localParticipant == null) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           return Stack(
//             children: [
//               StreamCallContent(
//                 call: call,
//                 callState: callState,
//                 callControlsBuilder: (context, call, callState) {
//                   return StreamCallControls(
//                     options: [
//                       if (widget.isVideo)
//                         FlipCameraOption(
//                           call: call,
//                           localParticipant: localParticipant,
//                         ),
//                       if (widget.isVideo)
//                         ToggleCameraOption(
//                           call: call,
//                           localParticipant: localParticipant,
//                         ),
//                       ToggleMicrophoneOption(
//                         call: call,
//                         localParticipant: localParticipant,
//                       ),
//                       LeaveCallOption(
//                         call: call,
//                         onLeaveCallTap: () {
//                           call.leave();
//                           Navigator.pop(context);
//                         },
//                       ),
//                     ],
//                   );
//                 },
//               ),
//               Positioned(
//                 top: 20,
//                 left: 20,
//                 child: Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.black54,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     _callStatus,
//                     style: const TextStyle(color: Colors.white, fontSize: 14),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
