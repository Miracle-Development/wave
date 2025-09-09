import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_mic_button.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:callkeep/callkeep.dart' show FlutterCallkeep;
import 'package:wave/models/call_state.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({
    super.key,
    this.isInitialMuted = false,
    this.disposableManager,
  });

  final bool isInitialMuted;
  final WebRTCManager? disposableManager;

  @override
  Widget build(BuildContext context) {
    final manager = disposableManager ?? Provider.of<WebRTCManager>(context);

    final mics = manager.devices.where((d) => d.kind == 'audioinput').toList();
    final outs = manager.devices.where((d) => d.kind == 'audiooutput').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 48.0),
          child: WaveDivider(
            type: _resolveDividerType(manager.callState),
            label: _resolveDividerText(manager.callState),
          ),
        ),
        WaveChatBubble(
          type: WaveChatBubbleType.bubbleMessageInfo,
          label:
              'Your call will be end-to-end encrypted.\nAre you ready to start?',
        ),
        SizedBox(height: 20),

        // Participants list (presence)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WaveText('Participants', type: WaveTextType.subtitle),
            SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: 160),
              child: ListView(
                shrinkWrap: true,
                children: manager.participantsList.map((p) {
                  return ListTile(
                    leading: Icon(p.inCall ? Icons.person : Icons.person_off,
                        color: p.inCall ? Colors.green : Colors.grey),
                    title: Text(p.id == manager.localId
                        ? (p.name == null ? 'You' : '${p.name} (you)')
                        : (p.name ?? 'Peer')),
                    subtitle: Text(p.inCall ? 'In call' : 'Not in call'),
                    trailing: Icon(p.muted ? Icons.mic_off : Icons.mic,
                        color: p.muted ? Colors.red : Colors.blue),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),

        SizedBox(height: 20),
        WaveText(manager.formattedCallDuration,
            type: WaveTextType.title,
            weight: WaveTextWeight.regular,
            textAlign: TextAlign.center),
        SizedBox(height: 20),

        // Device selection
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(children: [
            WaveText('Microphone:', type: WaveTextType.subtitle),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String?>(
                value: manager.selectedMicId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default')),
                  ...mics.map((d) => DropdownMenuItem(
                      value: d.deviceId, child: Text(d.label ?? 'Mic'))),
                ],
                onChanged: (v) => manager.selectMic(v),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(children: [
            WaveText('Speaker:', type: WaveTextType.subtitle),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String?>(
                value: manager.selectedSpeakerId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default')),
                  ...outs.map((d) => DropdownMenuItem(
                      value: d.deviceId, child: Text(d.label ?? 'Speaker'))),
                ],
                onChanged: (v) => manager.selectSpeaker(v),
              ),
            ),
          ]),
        ),

        SizedBox(height: 20),
        WaveSimpleButton(
          label: manager.muted ? 'Muted' : 'Mute',
          onPressed: () async {
            await manager.toggleMicMute();
            try {
              final ck = FlutterCallkeep();
              if (manager.callKeepUUID != null) {
                try {
                  await ck.setMutedCall(
                      uuid: manager.callKeepUUID!, shouldMute: manager.muted);
                } catch (_) {
                  try {
                    await ck.setMutedCall(
                        uuid: manager.callKeepUUID!, shouldMute: manager.muted);
                  } catch (e) {
                    // ignore if API mismatch
                  }
                }
              }
            } catch (e) {
              // ignore callkeep issues
            }
          },
        ),
        // Controls
        // WaveMicButton(
        //   isMuted: manager.muted,
        //   onTap: () async {
        //     await manager.toggleMicMute();
        //     try {
        //       final ck = FlutterCallkeep();
        //       if (manager.callKeepUUID != null) {
        //         try {
        //           await ck.setMutedCall(
        //               uuid: manager.callKeepUUID!, shouldMute: manager.muted);
        //         } catch (_) {
        //           try {
        //             await ck.setMutedCall(
        //                 uuid: manager.callKeepUUID!, shouldMute: manager.muted);
        //           } catch (e) {
        //             // ignore if API mismatch
        //           }
        //         }
        //       }
        //     } catch (e) {
        //       // ignore callkeep issues
        //     }
        //   },
        // ),

        SizedBox(height: 16),

        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            WaveSimpleButton(
              label: manager.inCall ? 'Leave Call' : 'Start Call',
              onPressed: () async {
                if (manager.inCall) {
                  await manager.leaveCall();
                } else {
                  try {
                    await manager.startCall();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Start call failed: $e')));
                  }
                }
              },
            ),
            WaveSimpleButton(
              label: 'Toggle Video',
              onPressed: () async {
                if (manager.localRenderer.srcObject != null) {
                  await manager.disableVideo();
                } else {
                  try {
                    await manager.enableVideo();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Camera error: $e')));
                  }
                }
              },
            ),
            WaveSimpleButton(
              label: 'Close',
              onPressed: () async {
                await manager.closeAll();
              },
            ),
          ],
        ),

        SizedBox(height: 200),
      ],
    );
  }

  WaveDividerType _resolveDividerType(CallState state) {
    switch (state) {
      case CallState.connected:
        return WaveDividerType.positive;
      case CallState.failed:
        return WaveDividerType.negative;
      case CallState.connecting:
        return WaveDividerType.brand;
      default:
        return WaveDividerType.disabled;
    }
  }

  String _resolveDividerText(CallState state) {
    switch (state) {
      case CallState.connected:
        return 'Connected';
      case CallState.failed:
        return 'Call Failed';
      case CallState.connecting:
        return 'Connecting...';
      default:
        return 'Ready to call';
    }
  }
}

// // call_screen.dart
// import 'package:flutter/material.dart';
// import 'package:md_ui_kit/md_ui_kit.dart';
// import 'package:md_ui_kit/widgets/wave_mic_button.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:callkeep/callkeep.dart'
//     show
//         FlutterCallkeep; // if your package exports different symbol, adapt here
// import 'package:wave/models/call_state.dart';
// import 'package:wave/src/core/webrtc_manager.dart';

// class CallScreen extends StatelessWidget {
//   const CallScreen({
//     super.key,
//     this.isInitialMuted = false,
//     this.disposableManager,
//   });

//   final bool isInitialMuted;
//   final WebRTCManager? disposableManager;

//   @override
//   Widget build(BuildContext context) {
//     final manager = disposableManager ?? Provider.of<WebRTCManager>(context);

//     final mics = manager.devices.where((d) => d.kind == 'audioinput').toList();
//     final outs = manager.devices.where((d) => d.kind == 'audiooutput').toList();

//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 48.0),
//           child: WaveDivider(
//             type: _resolveDividerType(manager.callState),
//             label: _resolveDividerText(manager.callState),
//           ),
//         ),
//         WaveChatBubble(
//           type: WaveChatBubbleType.bubbleMessageInfo,
//           label:
//               'Your call will be end-to-end encrypted.\nAre you ready to start?',
//         ),
//         SizedBox(height: 20),

//         // Participants list (presence)
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 36.0),
//           child:
//               Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             WaveText('Participants', type: WaveTextType.subtitle),
//             SizedBox(height: 8),
//             Container(
//               constraints: BoxConstraints(maxHeight: 160),
//               child: ListView(
//                 shrinkWrap: true,
//                 children: manager.participantsList.map((p) {
//                   return ListTile(
//                     leading: Icon(p.inCall ? Icons.person : Icons.person_off,
//                         color: p.inCall ? Colors.green : Colors.grey),
//                     title: Text(p.id == manager.localId
//                         ? (p.name == null ? 'You' : '${p.name} (you)')
//                         : (p.name ?? 'Peer')),
//                     subtitle: Text(p.inCall ? 'In call' : 'Not in call'),
//                     trailing: Icon(p.muted ? Icons.mic_off : Icons.mic,
//                         color: p.muted ? Colors.red : Colors.blue),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ]),
//         ),

//         SizedBox(height: 20),
//         WaveText(manager.formattedCallDuration,
//             type: WaveTextType.title,
//             weight: WaveTextWeight.regular,
//             textAlign: TextAlign.center),
//         SizedBox(height: 20),

//         // Device selection
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
//           child: Row(children: [
//             WaveText('Microphone:', type: WaveTextType.subtitle),
//             SizedBox(width: 10),
//             Expanded(
//               child: DropdownButton<String?>(
//                 value: manager.selectedMicId,
//                 isExpanded: true,
//                 items: [
//                   const DropdownMenuItem(value: null, child: Text('Default')),
//                   ...mics.map((d) => DropdownMenuItem(
//                       value: d.deviceId, child: Text(d.label ?? 'Mic'))),
//                 ],
//                 onChanged: (v) => manager.selectMic(v),
//               ),
//             ),
//           ]),
//         ),

//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
//           child: Row(children: [
//             WaveText('Speaker:', type: WaveTextType.subtitle),
//             SizedBox(width: 10),
//             Expanded(
//               child: DropdownButton<String?>(
//                 value: manager.selectedSpeakerId,
//                 isExpanded: true,
//                 items: [
//                   const DropdownMenuItem(value: null, child: Text('Default')),
//                   ...outs.map((d) => DropdownMenuItem(
//                       value: d.deviceId, child: Text(d.label ?? 'Speaker'))),
//                 ],
//                 onChanged: (v) => manager.selectSpeaker(v),
//               ),
//             ),
//           ]),
//         ),

//         SizedBox(height: 20),

//         // Video preview area (constrained)
//         // Container(
//         //   constraints: BoxConstraints(maxWidth: 800, maxHeight: 380),
//         //   color: Colors.black,
//         //   child: manager.remoteRenderer.srcObject != null
//         //       ? RTCVideoView(manager.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
//         //       : Center(child: Text('Waiting for remote video/audio...', style: TextStyle(color: Colors.white))),
//         // ),

//         // Small local preview
//         // Align(
//         //   alignment: Alignment.topRight,
//         //   child: Container(
//         //     margin: EdgeInsets.only(top: 8, right: 8),
//         //     width: 120,
//         //     height: 160,
//         //     decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
//         //     child: manager.localRenderer.srcObject != null
//         //         ? RTCVideoView(manager.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
//         //         : Container(color: Colors.black26, child: Center(child: Icon(Icons.person, color: Colors.white54, size: 40))),
//         //   ),
//         // ),

//         SizedBox(height: 20),

//         // Controls
//         WaveMicButton(
//           isMuted: manager.muted,
//           onTap: () async {
//             await manager.toggleMicMute();
//             // optional: notify CallKeep (UI side)
//             try {
//               final ck = FlutterCallkeep();
//               if (manager.callKeepUUID != null) {
//                 // API differs between versions; below are two common signatures in try/catch
//                 try {
//                   await ck.setMutedCall(
//                       uuid: manager.callKeepUUID!, shouldMute: manager.muted);
//                 } catch (_) {
//                   try {
//                     await ck.setMutedCall(
//                         uuid: manager.callKeepUUID!, shouldMute: manager.muted);
//                   } catch (e) {
//                     // ignore if API mismatch
//                   }
//                 }
//               }
//             } catch (e) {
//               // ignore callkeep issues
//             }
//           },
//         ),

//         SizedBox(height: 16),

//         Column(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             WaveSimpleButton(
//               label: manager.inCall ? 'Leave Call' : 'Start Call',
//               onPressed: () async {
//                 if (manager.inCall) {
//                   await manager.leaveCall();
//                 } else {
//                   try {
//                     await manager.startCall();
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Start call failed: $e')));
//                   }
//                 }
//               },
//             ),
//             WaveSimpleButton(
//               label: 'Toggle Video',
//               onPressed: () async {
//                 if (manager.localRenderer.srcObject != null) {
//                   await manager.disableVideo();
//                 } else {
//                   try {
//                     await manager.enableVideo();
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Camera error: $e')));
//                   }
//                 }
//               },
//             ),
//             WaveSimpleButton(
//               label: 'Close',
//               onPressed: () async {
//                 await manager.closeAll();
//               },
//             ),
//           ],
//         ),

//         SizedBox(height: 200),
//       ],
//     );
//   }

//   WaveDividerType _resolveDividerType(CallState state) {
//     switch (state) {
//       case CallState.connected:
//         return WaveDividerType.positive;
//       case CallState.connecting:
//         return WaveDividerType.brand;
//       case CallState.failed:
//         return WaveDividerType.negative;
//       case CallState.disconnected:
//         return WaveDividerType.disabled;
//     }
//   }

//   String _resolveDividerText(CallState callState) {
//     switch (callState) {
//       case CallState.connected:
//         return 'Connected';
//       case CallState.connecting:
//         return 'Connecting';
//       case CallState.failed:
//         return 'Failed to connect';
//       case CallState.disconnected:
//         return 'Disconnected';
//     }
//   }
// }

// // // call_screen.dart
// // import 'package:flutter/material.dart';
// // import 'package:flutter_webrtc/flutter_webrtc.dart';
// // import 'package:provider/provider.dart';
// // import 'package:callkeep/callkeep.dart'; // adapt to your package if different
// // import 'package:wave/src/core/webrtc_manager.dart';

// // class CallScreen extends StatefulWidget {
// //   final String peerId;
// //   const CallScreen({super.key, required this.peerId});

// //   @override
// //   State<CallScreen> createState() => _CallScreenState();
// // }

// // class _CallScreenState extends State<CallScreen> {
// //   bool _micEnabled = true;
// //   bool _videoEnabled = false;

// //   @override
// //   void initState() {
// //     super.initState();
// //     final manager = context.read<WebRTCManager>();
// //     // init renderers, don't request camera/mic here
// //     manager.init();

// //     // wire CallKeep events if you use it (best-effort)
// //     try {
// //       final ck = FlutterCallkeep();
// //       // The API for event subscription differs by package. This is illustrative.
// //       // If your package provides streams/callbacks, subscribe here.
// //       // e.g. ck.onAnswer = (data) => ...
// //     } catch (e) {
// //       // ignore callkeep init errors
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     super.dispose();
// //   }

// //   Future<void> _onToggleMic() async {
// //     final manager = context.read<WebRTCManager>();
// //     await manager.toggleMicMute();
// //     setState(() {
// //       _micEnabled = !manager.muted;
// //     });
// //   }

// //   Future<void> _onToggleVideo() async {
// //     final manager = context.read<WebRTCManager>();
// //     if (_videoEnabled) {
// //       await manager.disableVideo();
// //       setState(() => _videoEnabled = false);
// //     } else {
// //       try {
// //         await manager.enableVideo();
// //         setState(() => _videoEnabled = true);
// //       } catch (e) {
// //         ScaffoldMessenger.of(context)
// //             .showSnackBar(SnackBar(content: Text('Camera error: $e')));
// //       }
// //     }
// //   }

// //   Future<void> _onHangUp() async {
// //     final manager = context.read<WebRTCManager>();
// //     try {
// //       manager.closeAll();
// //     } catch (_) {}
// //     // If using CallKeep, end native UI (best-effort)
// //     try {
// //       final ck = FlutterCallkeep();
// //       await ck.endAllCalls();
// //     } catch (_) {}
// //     // if (mounted) Navigator.of(context).pop();
// //   }

// //   Future<void> _onStartCall() async {
// //     final manager = context.read<WebRTCManager>();
// //     try {
// //       manager.startCall();
// //     } catch (e) {
// //       print(e);
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final manager = context.watch<WebRTCManager>();

// //     return Stack(
// //       children: [
// //         Positioned(
// //           bottom: 12,
// //           left: 12,
// //           child: FloatingActionButton(
// //             heroTag: 'start call',
// //             backgroundColor: Colors.green,
// //             onPressed: _onStartCall,
// //             child: Icon(Icons.phone, color: Colors.white),
// //           ),
// //         ),
// //         // remote video (center)
// //         // Center(
// //         //   child: Container(
// //         //     constraints: BoxConstraints(maxWidth: 800, maxHeight: 600),
// //         //     color: Colors.black,
// //         //     child: manager.remoteRenderer.srcObject != null
// //         //         ? RTCVideoView(manager.remoteRenderer,
// //         //             objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
// //         //         : Center(
// //         //             child: Text('Waiting for remote video/audio...',
// //         //                 style: TextStyle(color: Colors.white))),
// //         //   ),
// //         // ),

// //         // local small preview
// //         // Positioned(
// //         //   top: 20,
// //         //   right: 20,
// //         //   child: Container(
// //         //     width: 140,
// //         //     height: 190,
// //         //     decoration:
// //         //         BoxDecoration(border: Border.all(color: Colors.white24)),
// //         //     child: manager.localRenderer.srcObject != null
// //         //         ? RTCVideoView(manager.localRenderer,
// //         //             mirror: true,
// //         //             objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
// //         //         : Container(
// //         //             color: Colors.black26,
// //         //             child: Center(
// //         //                 child: Icon(Icons.person,
// //         //                     color: Colors.white54, size: 40)),
// //         //           ),
// //         //   ),
// //         // ),

// //         // top bar with peer id
// //         Positioned(
// //           top: 12,
// //           left: 12,
// //           child: Text('Call with ${widget.peerId}',
// //               style: TextStyle(color: Colors.white, fontSize: 16)),
// //         ),

// //         // bottom controls
// //         Align(
// //           alignment: Alignment.bottomCenter,
// //           child: Padding(
// //             padding: const EdgeInsets.only(bottom: 28.0),
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //               children: [
// //                 // toggle mic
// //                 Column(
// //                   mainAxisSize: MainAxisSize.min,
// //                   children: [
// //                     FloatingActionButton(
// //                       heroTag: 'mic',
// //                       backgroundColor:
// //                           manager.muted ? Colors.grey[700] : Colors.blue,
// //                       onPressed: _onToggleMic,
// //                       child: Icon(manager.muted ? Icons.mic_off : Icons.mic,
// //                           color: Colors.white),
// //                     ),
// //                     SizedBox(height: 6),
// //                     Text('Mute', style: TextStyle(color: Colors.white70)),
// //                   ],
// //                 ),

// //                 // toggle video
// //                 Column(
// //                   mainAxisSize: MainAxisSize.min,
// //                   children: [
// //                     FloatingActionButton(
// //                       heroTag: 'video',
// //                       backgroundColor:
// //                           _videoEnabled ? Colors.blue : Colors.grey[700],
// //                       onPressed: _onToggleVideo,
// //                       child: Icon(
// //                           _videoEnabled ? Icons.videocam : Icons.videocam_off,
// //                           color: Colors.white),
// //                     ),
// //                     SizedBox(height: 6),
// //                     Text('Video', style: TextStyle(color: Colors.white70)),
// //                   ],
// //                 ),

// //                 // hang up
// //                 Column(
// //                   mainAxisSize: MainAxisSize.min,
// //                   children: [
// //                     FloatingActionButton(
// //                       heroTag: 'hangup',
// //                       backgroundColor: Colors.red,
// //                       onPressed: _onHangUp,
// //                       child: Icon(Icons.call_end, color: Colors.white),
// //                     ),
// //                     SizedBox(height: 6),
// //                     Text('Hang up', style: TextStyle(color: Colors.white70)),
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// // }
