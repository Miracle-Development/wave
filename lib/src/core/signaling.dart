import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnOffer = void Function(String fromId, String sdp);
typedef OnAnswer = void Function(String fromId, String sdp);
typedef OnCandidate = void Function(String fromId, dynamic candidate);
typedef OnCall = void Function(String fromId);

class Signaling {
  // Singleton
  static final Signaling _instance = Signaling._internal();
  factory Signaling() => _instance;
  Signaling._internal();

  // Optional WebSocket signaling
  WebSocket? _socket;
  String _selfId = '';

  // PeerConnection and DataChannel
  RTCPeerConnection? pc;
  RTCDataChannel? chat;

  MediaStream? localStream;
  MediaStream? remoteStream;

  // Callbacks
  OnOffer? onOffer;
  OnAnswer? onAnswer;
  OnCandidate? onCandidate;
  OnCall? onCall;

  final Map<String, dynamic> config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      // Add TURN here if you have it:
      // {'urls': 'turn:TURN_HOST:3478', 'username': 'USER', 'credential': 'PASS'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Initialize RTCPeerConnection (create pc and set handlers)
  Future<void> init() async {
    pc = await createPeerConnection(config);

    pc!.onIceCandidate = (candidate) {
      debugPrint('ICE candidate: ${candidate.candidate}');
    };

    pc!.onIceGatheringState = (state) => debugPrint('ICE: $state');
    pc!.onConnectionState = (s) => debugPrint('PC connectionState: $s');

    pc!.onDataChannel = (dc) {
      debugPrint('onDataChannel: ${dc.label}');
      chat = dc;
    };

    pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        debugPrint(
            'onTrack: remoteStream id=${remoteStream?.id}, audioTracks=${remoteStream?.getAudioTracks().map((t) => t.id).toList()}');
      }
    };
  }

  /// Connect to WebSocket signaling server (optional)
  Future<void> connect(String url) async {
    try {
      _socket = await WebSocket.connect(url);
      _socket!.listen((data) => _handleMessage(data),
          onError: (e) => debugPrint('WebSocket error: $e'),
          onDone: () => debugPrint('WebSocket closed'));
      _selfId = DateTime.now().millisecondsSinceEpoch.toString();
      _send({'type': 'register', 'id': _selfId});
    } catch (e) {
      debugPrint('Signaling.connect failed: $e');
      rethrow;
    }
  }

  void _send(Map<String, dynamic> msg) {
    try {
      if (_socket != null) _socket!.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('Signaling._send failed: $e');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data);
      final type = msg['type'] as String? ?? '';
      final from = msg['from'] as String? ?? '';
      if (type == 'offer' && onOffer != null) {
        onOffer!(from, msg['sdp'] as String? ?? '');
      } else if (type == 'answer' && onAnswer != null) {
        onAnswer!(from, msg['sdp'] as String? ?? '');
      } else if (type == 'candidate' && onCandidate != null) {
        onCandidate!(from, msg['candidate']);
      } else if (type == 'call' && onCall != null) {
        onCall!(from);
      } else {
        debugPrint('Signaling: unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Signaling._handleMessage parse error: $e');
    }
  }

  void callPeer(String peerId, String sdp) {
    _send({'type': 'offer', 'from': _selfId, 'to': peerId, 'sdp': sdp});
  }

  void sendAnswer(String peerId, String sdp) {
    _send({'type': 'answer', 'from': _selfId, 'to': peerId, 'sdp': sdp});
  }

  void sendCandidate(String peerId, RTCIceCandidate candidate) {
    _send({
      'type': 'candidate',
      'from': _selfId,
      'to': peerId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex
      }
    });
  }

  // ---------------- Local stream attach/detach ----------------

  Future<void> attachLocal(MediaStream stream) async {
    localStream = stream;
    if (pc == null) {
      debugPrint('attachLocal: pc == null, saved localStream only');
      return;
    }
    try {
      final senders = await pc!.getSenders();
      final existing = <String>{};
      for (final s in senders) {
        if (s.track != null && s.track!.id != null) existing.add(s.track!.id!);
      }
      for (final t in stream.getTracks()) {
        if (t.kind == 'audio' || t.kind == 'video') {
          if (t.id != null && existing.contains(t.id)) {
            debugPrint('attachLocal: skipping already added track ${t.id}');
            continue;
          }
          try {
            await pc!.addTrack(t, stream);
            debugPrint('attachLocal: addTrack ${t.id} succeeded');
          } catch (e) {
            debugPrint('attachLocal: addTrack ${t.id} failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('attachLocal error: $e');
    }
  }

  Future<void> detachLocal() async {
    if (pc != null) {
      try {
        final senders = await pc!.getSenders();
        for (final s in senders) {
          try {
            if (s.track != null &&
                (s.track!.kind == 'audio' || s.track!.kind == 'video')) {
              await s.replaceTrack(null);
              debugPrint('detachLocal: replaced sender ${s.track?.id} with null');
            }
          } catch (e) {
            debugPrint('detachLocal: replaceTrack(null) failed: $e');
            try {
              await pc!.removeTrack(s);
              debugPrint('detachLocal: removeTrack fallback succeeded');
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('detachLocal: error operating on senders: $e');
      }
    }

    try {
      for (final t in localStream?.getTracks() ?? []) {
        try {
          t.stop();
        } catch (_) {}
      }
      await localStream?.dispose();
    } catch (e) {
      debugPrint('detachLocal: disposing localStream failed: $e');
    }
    localStream = null;
  }

  // ---------------- Offer/Answer (BLOB) ----------------
  Future<String> makeOfferBlob() async {
    if (pc == null) throw Exception('PC not initialized');
    final offer = await pc!.createOffer({'offerToReceiveAudio': true});
    debugPrint('makeOfferBlob: creating offer, signalingState=${pc!.signalingState}');
    await pc!.setLocalDescription(offer);
    await _waitIceComplete();
    final sd = await pc!.getLocalDescription();
    final blob = jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
    debugPrint('makeOfferBlob done. signalingState=${pc!.signalingState}');
    return blob;
  }

  Future<void> acceptOfferBlob(String blob) async {
    if (pc == null) throw Exception('PC not initialized');
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final desc = RTCSessionDescription(map['sdp'], map['type']);
    debugPrint('acceptOfferBlob: applying remote offer, signalingState=${pc!.signalingState}');
    await safeSetRemoteDescription(desc);
    final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
    await pc!.setLocalDescription(answer);
    await _waitIceComplete();
    debugPrint('acceptOfferBlob: answer created and setLocal, signalingState=${pc!.signalingState}');
  }

  Future<String> getAnswerBlob() async {
    final sd = await pc!.getLocalDescription();
    return jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
  }

  Future<void> acceptAnswerBlob(String blob) async {
    if (pc == null) throw Exception('PC not initialized');
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final desc = RTCSessionDescription(map['sdp'], map['type']);
    debugPrint('acceptAnswerBlob: applying answer, signalingState=${pc!.signalingState}');
    await safeSetRemoteDescription(desc);
  }

  Future<void> _waitIceComplete() async {
    if (pc == null) return;
    while (pc!.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> safeSetRemoteDescription(RTCSessionDescription desc) async {
    if (pc == null) throw Exception('PC not initialized');
    try {
      debugPrint('safeSetRemoteDescription: before setRemote, signalingState=${pc!.signalingState}');
      await pc!.setRemoteDescription(desc);
      debugPrint('safeSetRemoteDescription: setRemote succeeded');
      return;
    } catch (e) {
      final err = e.toString();
      debugPrint('safeSetRemoteDescription: initial setRemote failed: $err');
      if (err.contains('Called in wrong state') || err.contains('InvalidStateError')) {
        try {
          debugPrint('safeSetRemoteDescription: attempting rollback');
          await pc!.setLocalDescription(RTCSessionDescription('', 'rollback'));
          await Future.delayed(const Duration(milliseconds: 150));
          debugPrint('safeSetRemoteDescription: retrying setRemote after rollback');
          await pc!.setRemoteDescription(desc);
          debugPrint('safeSetRemoteDescription: setRemote succeeded after rollback');
          return;
        } catch (e2) {
          debugPrint('safeSetRemoteDescription: retry failed: $e2');
          rethrow;
        }
      } else {
        try {
          await Future.delayed(const Duration(milliseconds: 120));
          await pc!.setRemoteDescription(desc);
          debugPrint('safeSetRemoteDescription: retry succeeded');
          return;
        } catch (e3) {
          debugPrint('safeSetRemoteDescription: retry also failed: $e3');
          rethrow;
        }
      }
    }
  }

  Future<RTCDataChannel> createLocalDataChannel([String label = 'chat']) async {
    if (pc == null) throw Exception('PC not initialized');
    final dc = await pc!.createDataChannel(label, RTCDataChannelInit()..ordered = true);
    chat = dc;
    return dc;
  }

  Future<void> close() async {
    try { await chat?.close(); } catch (_) {}
    try { await pc?.close(); } catch (_) {}
    try { await _socket?.close(); } catch (_) {}
    pc = null;
    chat = null;
    localStream = null;
    remoteStream = null;
    _socket = null;
  }

  // Ensure pc exists (used by manager)
  Future<void> connectionFallbackInitIfNeeded() async {
    if (pc == null) {
      await init();
    }
  }
}


// // signaling.dart
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io' show WebSocket;
// import 'package:flutter/foundation.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';

// typedef OnOffer = void Function(String fromId, String sdp);
// typedef OnAnswer = void Function(String fromId, String sdp);
// typedef OnCandidate = void Function(String fromId, dynamic candidate);
// typedef OnCall = void Function(String fromId);

// class Signaling {
//   // Singleton
//   static final Signaling _instance = Signaling._internal();
//   factory Signaling() => _instance;
//   Signaling._internal();

//   // Optional WebSocket signaling
//   WebSocket? _socket;
//   String _selfId = '';

//   // PeerConnection and DataChannel
//   RTCPeerConnection? pc;
//   RTCDataChannel? chat;

//   MediaStream? localStream;
//   MediaStream? remoteStream;

//   // Callbacks
//   OnOffer? onOffer;
//   OnAnswer? onAnswer;
//   OnCandidate? onCandidate;
//   OnCall? onCall;

//   final Map<String, dynamic> config = {
//     'iceServers': [
//       {'urls': 'stun:stun.l.google.com:19302'},
//       // Add TURN here if you have it:
//       // {'urls': 'turn:TURN_HOST:3478', 'username': 'USER', 'credential': 'PASS'},
//     ],
//     'sdpSemantics': 'unified-plan',
//   };

//   /// Initialize RTCPeerConnection (create pc and set handlers)
//   Future<void> init() async {
//     pc = await createPeerConnection(config);

//     pc!.onIceCandidate = (candidate) {
//       debugPrint('ICE candidate: ${candidate.candidate}');
//     };

//     pc!.onIceGatheringState = (state) => debugPrint('ICE: $state');
//     pc!.onConnectionState = (s) => debugPrint('PC connectionState: $s');

//     pc!.onDataChannel = (dc) {
//       debugPrint('onDataChannel: ${dc.label}');
//       chat = dc;
//     };

//     pc!.onTrack = (event) {
//       if (event.streams.isNotEmpty) {
//         remoteStream = event.streams.first;
//         debugPrint(
//             'onTrack: remoteStream id=${remoteStream?.id}, audioTracks=${remoteStream?.getAudioTracks().map((t) => t.id).toList()}');
//       }
//     };
//   }

//   /// Connect to WebSocket signaling server (optional)
//   Future<void> connect(String url) async {
//     try {
//       _socket = await WebSocket.connect(url);
//       _socket!.listen((data) => _handleMessage(data),
//           onError: (e) => debugPrint('WebSocket error: $e'),
//           onDone: () => debugPrint('WebSocket closed'));
//       _selfId = DateTime.now().millisecondsSinceEpoch.toString();
//       _send({'type': 'register', 'id': _selfId});
//     } catch (e) {
//       debugPrint('Signaling.connect failed: $e');
//       rethrow;
//     }
//   }

//   void _send(Map<String, dynamic> msg) {
//     try {
//       if (_socket != null) _socket!.add(jsonEncode(msg));
//     } catch (e) {
//       debugPrint('Signaling._send failed: $e');
//     }
//   }

//   void _handleMessage(dynamic data) {
//     try {
//       final msg = jsonDecode(data);
//       final type = msg['type'] as String? ?? '';
//       final from = msg['from'] as String? ?? '';
//       if (type == 'offer' && onOffer != null) {
//         onOffer!(from, msg['sdp'] as String? ?? '');
//       } else if (type == 'answer' && onAnswer != null) {
//         onAnswer!(from, msg['sdp'] as String? ?? '');
//       } else if (type == 'candidate' && onCandidate != null) {
//         onCandidate!(from, msg['candidate']);
//       } else if (type == 'call' && onCall != null) {
//         onCall!(from);
//       } else {
//         debugPrint('Signaling: unknown message type: $type');
//       }
//     } catch (e) {
//       debugPrint('Signaling._handleMessage parse error: $e');
//     }
//   }

//   void callPeer(String peerId, String sdp) {
//     _send({'type': 'offer', 'from': _selfId, 'to': peerId, 'sdp': sdp});
//   }

//   void sendAnswer(String peerId, String sdp) {
//     _send({'type': 'answer', 'from': _selfId, 'to': peerId, 'sdp': sdp});
//   }

//   void sendCandidate(String peerId, RTCIceCandidate candidate) {
//     _send({
//       'type': 'candidate',
//       'from': _selfId,
//       'to': peerId,
//       'candidate': {
//         'candidate': candidate.candidate,
//         'sdpMid': candidate.sdpMid,
//         'sdpMLineIndex': candidate.sdpMLineIndex
//       }
//     });
//   }

//   // ---------------- Local stream attach/detach ----------------

//   Future<void> attachLocal(MediaStream stream) async {
//     localStream = stream;
//     if (pc == null) {
//       debugPrint('attachLocal: pc == null, saved localStream only');
//       return;
//     }
//     try {
//       final senders = await pc!.getSenders();
//       final existing = <String>{};
//       for (final s in senders) {
//         if (s.track != null && s.track!.id != null) existing.add(s.track!.id!);
//       }
//       for (final t in stream.getTracks()) {
//         if (t.kind == 'audio' || t.kind == 'video') {
//           if (t.id != null && existing.contains(t.id)) {
//             debugPrint('attachLocal: skipping already added track ${t.id}');
//             continue;
//           }
//           try {
//             await pc!.addTrack(t, stream);
//             debugPrint('attachLocal: addTrack ${t.id} succeeded');
//           } catch (e) {
//             debugPrint('attachLocal: addTrack ${t.id} failed: $e');
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('attachLocal error: $e');
//     }
//   }

//   Future<void> detachLocal() async {
//     if (pc != null) {
//       try {
//         final senders = await pc!.getSenders();
//         for (final s in senders) {
//           try {
//             if (s.track != null &&
//                 (s.track!.kind == 'audio' || s.track!.kind == 'video')) {
//               await s.replaceTrack(null);
//               debugPrint('detachLocal: replaced sender ${s.track?.id} with null');
//             }
//           } catch (e) {
//             debugPrint('detachLocal: replaceTrack(null) failed: $e');
//             try {
//               await pc!.removeTrack(s);
//               debugPrint('detachLocal: removeTrack fallback succeeded');
//             } catch (_) {}
//           }
//         }
//       } catch (e) {
//         debugPrint('detachLocal: error operating on senders: $e');
//       }
//     }

//     try {
//       for (final t in localStream?.getTracks() ?? []) {
//         try {
//           t.stop();
//         } catch (_) {}
//       }
//       await localStream?.dispose();
//     } catch (e) {
//       debugPrint('detachLocal: disposing localStream failed: $e');
//     }
//     localStream = null;
//   }

//   // ---------------- Offer/Answer (BLOB) ----------------
//   Future<String> makeOfferBlob() async {
//     if (pc == null) throw Exception('PC not initialized');
//     final offer = await pc!.createOffer({'offerToReceiveAudio': true});
//     debugPrint('makeOfferBlob: creating offer, signalingState=${pc!.signalingState}');
//     await pc!.setLocalDescription(offer);
//     await _waitIceComplete();
//     final sd = await pc!.getLocalDescription();
//     final blob = jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
//     debugPrint('makeOfferBlob done. signalingState=${pc!.signalingState}');
//     return blob;
//   }

//   Future<void> acceptOfferBlob(String blob) async {
//     if (pc == null) throw Exception('PC not initialized');
//     final map = jsonDecode(blob) as Map<String, dynamic>;
//     final desc = RTCSessionDescription(map['sdp'], map['type']);
//     debugPrint('acceptOfferBlob: applying remote offer, signalingState=${pc!.signalingState}');
//     await safeSetRemoteDescription(desc);
//     final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
//     await pc!.setLocalDescription(answer);
//     await _waitIceComplete();
//     debugPrint('acceptOfferBlob: answer created and setLocal, signalingState=${pc!.signalingState}');
//   }

//   Future<String> getAnswerBlob() async {
//     final sd = await pc!.getLocalDescription();
//     return jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
//   }

//   Future<void> acceptAnswerBlob(String blob) async {
//     if (pc == null) throw Exception('PC not initialized');
//     final map = jsonDecode(blob) as Map<String, dynamic>;
//     final desc = RTCSessionDescription(map['sdp'], map['type']);
//     debugPrint('acceptAnswerBlob: applying answer, signalingState=${pc!.signalingState}');
//     await safeSetRemoteDescription(desc);
//   }

//   Future<void> _waitIceComplete() async {
//     if (pc == null) return;
//     while (pc!.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
//       await Future.delayed(const Duration(milliseconds: 120));
//     }
//   }

//   Future<void> safeSetRemoteDescription(RTCSessionDescription desc) async {
//     if (pc == null) throw Exception('PC not initialized');
//     try {
//       debugPrint('safeSetRemoteDescription: before setRemote, signalingState=${pc!.signalingState}');
//       await pc!.setRemoteDescription(desc);
//       debugPrint('safeSetRemoteDescription: setRemote succeeded');
//       return;
//     } catch (e) {
//       final err = e.toString();
//       debugPrint('safeSetRemoteDescription: initial setRemote failed: $err');
//       if (err.contains('Called in wrong state') || err.contains('InvalidStateError')) {
//         try {
//           debugPrint('safeSetRemoteDescription: attempting rollback');
//           await pc!.setLocalDescription(RTCSessionDescription('', 'rollback'));
//           await Future.delayed(const Duration(milliseconds: 150));
//           debugPrint('safeSetRemoteDescription: retrying setRemote after rollback');
//           await pc!.setRemoteDescription(desc);
//           debugPrint('safeSetRemoteDescription: setRemote succeeded after rollback');
//           return;
//         } catch (e2) {
//           debugPrint('safeSetRemoteDescription: retry failed: $e2');
//           rethrow;
//         }
//       } else {
//         try {
//           await Future.delayed(const Duration(milliseconds: 120));
//           await pc!.setRemoteDescription(desc);
//           debugPrint('safeSetRemoteDescription: retry succeeded');
//           return;
//         } catch (e3) {
//           debugPrint('safeSetRemoteDescription: retry also failed: $e3');
//           rethrow;
//         }
//       }
//     }
//   }

//   Future<RTCDataChannel> createLocalDataChannel([String label = 'chat']) async {
//     if (pc == null) throw Exception('PC not initialized');
//     final dc = await pc!.createDataChannel(label, RTCDataChannelInit()..ordered = true);
//     chat = dc;
//     return dc;
//   }

//   Future<void> close() async {
//     try { await chat?.close(); } catch (_) {}
//     try { await pc?.close(); } catch (_) {}
//     try { await _socket?.close(); } catch (_) {}
//     pc = null;
//     chat = null;
//     localStream = null;
//     remoteStream = null;
//     _socket = null;
//   }

//   // Ensure pc exists (used by manager)
//   Future<void> connectionFallbackInitIfNeeded() async {
//     if (pc == null) {
//       await init();
//     }
//   }
// }



// // // signaling.dart
// // // WebSocket signaling + helper methods for attaching/detaching local streams
// // // Singleton style. Uses simple JSON messages:
// // //  - register {type: 'register', id}
// // //  - offer  {type:'offer','from','to','sdp'}
// // //  - answer {type:'answer','from','to','sdp'}
// // //  - candidate {type:'candidate','from','to','candidate':{candidate,sdpMid,sdpMLineIndex}}
// // //  - call {type:'call','from','to'}

// // // signaling.dart
// // // Combines: WebSocket signaling (basic), and RTCPeerConnection helpers (attach/detach, offer/answer blobs, safe setRemote).
// // // Singleton.

// // import 'dart:async';
// // import 'dart:convert';
// // import 'dart:io' show WebSocket;
// // import 'package:flutter/foundation.dart';
// // import 'package:flutter_webrtc/flutter_webrtc.dart';

// // typedef OnOffer = void Function(String fromId, String sdp);
// // typedef OnAnswer = void Function(String fromId, String sdp);
// // typedef OnCandidate = void Function(String fromId, dynamic candidate);
// // typedef OnCall = void Function(String fromId);

// // class Signaling {
// //   // Singleton
// //   static final Signaling _instance = Signaling._internal();
// //   factory Signaling() => _instance;
// //   Signaling._internal();

// //   // WebSocket (optional)
// //   WebSocket? _socket;
// //   String _selfId = '';

// //   // RTCPeerConnection and datacahnnel
// //   RTCPeerConnection? pc;
// //   RTCDataChannel? chat;

// //   MediaStream? localStream;
// //   MediaStream? remoteStream;

// //   // Callbacks for upstream manager
// //   OnOffer? onOffer;
// //   OnAnswer? onAnswer;
// //   OnCandidate? onCandidate;
// //   OnCall? onCall;

// //   final Map<String, dynamic> config = {
// //     'iceServers': [
// //       {'urls': 'stun:stun.l.google.com:19302'},
// //       // add TURN here if needed
// //     ],
// //     'sdpSemantics': 'unified-plan',
// //   };

// //   /// Initialize RTCPeerConnection (creates pc, sets basic handlers)
// //   Future<void> init() async {
// //     pc = await createPeerConnection(config);

// //     pc!.onIceCandidate = (c) {
// //       debugPrint('ICE candidate: ${c.candidate}');
// //     };
// //     pc!.onIceGatheringState = (s) => debugPrint('ICE: $s');
// //     pc!.onConnectionState = (s) => debugPrint('PC connectionState: $s');

// //     pc!.onDataChannel = (dc) {
// //       debugPrint('onDataChannel: ${dc.label}');
// //       chat = dc;
// //     };

// //     pc!.onTrack = (event) {
// //       if (event.streams.isNotEmpty) {
// //         remoteStream = event.streams.first;
// //         debugPrint(
// //             'onTrack: remoteStream id=${remoteStream?.id}, audioTracks=${remoteStream?.getAudioTracks().map((t) => t.id).toList()}');
// //       }
// //     };
// //   }

// //   /// If you use a WebSocket signaling server.
// //   Future<void> connect(String url) async {
// //     try {
// //       _socket = await WebSocket.connect(url);
// //       _socket!.listen((data) => _handleMessage(data),
// //           onError: (e) => debugPrint('WebSocket error: $e'),
// //           onDone: () => debugPrint('WebSocket closed'));
// //       _selfId = DateTime.now().millisecondsSinceEpoch.toString();
// //       _send({'type': 'register', 'id': _selfId});
// //     } catch (e) {
// //       debugPrint('Signaling.connect failed: $e');
// //       rethrow;
// //     }
// //   }

// //   void _send(Map<String, dynamic> msg) {
// //     try {
// //       if (_socket != null) _socket!.add(jsonEncode(msg));
// //     } catch (e) {
// //       debugPrint('Signaling._send failed: $e');
// //     }
// //   }

// //   void _handleMessage(dynamic data) {
// //     try {
// //       final msg = jsonDecode(data);
// //       final type = msg['type'] as String? ?? '';
// //       final from = msg['from'] as String? ?? '';
// //       if (type == 'offer' && onOffer != null) {
// //         onOffer!(from, msg['sdp'] as String? ?? '');
// //       } else if (type == 'answer' && onAnswer != null) {
// //         onAnswer!(from, msg['sdp'] as String? ?? '');
// //       } else if (type == 'candidate' && onCandidate != null) {
// //         onCandidate!(from, msg['candidate']);
// //       } else if (type == 'call' && onCall != null) {
// //         onCall!(from);
// //       } else {
// //         debugPrint('Signaling: unknown message type: $type');
// //       }
// //     } catch (e) {
// //       debugPrint('Signaling._handleMessage parse error: $e');
// //     }
// //   }

// //   // WebSocket send helpers
// //   void callPeer(String peerId, String sdp) {
// //     _send({'type': 'offer', 'from': _selfId, 'to': peerId, 'sdp': sdp});
// //   }

// //   void sendAnswer(String peerId, String sdp) {
// //     _send({'type': 'answer', 'from': _selfId, 'to': peerId, 'sdp': sdp});
// //   }

// //   void sendCandidate(String peerId, RTCIceCandidate candidate) {
// //     _send({
// //       'type': 'candidate',
// //       'from': _selfId,
// //       'to': peerId,
// //       'candidate': {
// //         'candidate': candidate.candidate,
// //         'sdpMid': candidate.sdpMid,
// //         'sdpMLineIndex': candidate.sdpMLineIndex
// //       }
// //     });
// //   }

// //   // ------------------ Local stream attach / detach ------------------
// //   /// Attach local stream to pc; safe: skip tracks already present on pc senders.
// //   Future<void> attachLocal(MediaStream stream) async {
// //     localStream = stream;
// //     if (pc == null) {
// //       debugPrint('attachLocal: pc == null, saved localStream only');
// //       return;
// //     }
// //     try {
// //       final senders = await pc!.getSenders();
// //       final existing = <String>{};
// //       for (final s in senders) {
// //         if (s.track != null && s.track!.id != null) existing.add(s.track!.id!);
// //       }
// //       for (final t in stream.getTracks()) {
// //         if (t.kind == 'audio' || t.kind == 'video') {
// //           if (t.id != null && existing.contains(t.id)) {
// //             debugPrint('attachLocal: skipping already added track ${t.id}');
// //             continue;
// //           }
// //           try {
// //             await pc!.addTrack(t, stream);
// //             debugPrint('attachLocal: addTrack ${t.id} succeeded');
// //           } catch (e) {
// //             debugPrint('attachLocal: addTrack ${t.id} failed: $e');
// //           }
// //         }
// //       }
// //     } catch (e) {
// //       debugPrint('attachLocal error: $e');
// //     }
// //   }

// //   /// Detach local stream: replace sender.track -> null (stop sending), then stop & dispose localStream.
// //   Future<void> detachLocal() async {
// //     if (pc != null) {
// //       try {
// //         final senders = await pc!.getSenders();
// //         for (final s in senders) {
// //           try {
// //             if (s.track != null &&
// //                 (s.track!.kind == 'audio' || s.track!.kind == 'video')) {
// //               await s.replaceTrack(null);
// //               debugPrint('detachLocal: replaced sender ${s.track?.id} with null');
// //             }
// //           } catch (e) {
// //             debugPrint('detachLocal: replaceTrack(null) failed: $e');
// //             try {
// //               await pc!.removeTrack(s);
// //               debugPrint('detachLocal: removeTrack fallback succeeded');
// //             } catch (_) {}
// //           }
// //         }
// //       } catch (e) {
// //         debugPrint('detachLocal: error operating on senders: $e');
// //       }
// //     }

// //     try {
// //       for (final t in localStream?.getTracks() ?? []) {
// //         try {
// //           t.stop();
// //         } catch (_) {}
// //       }
// //       await localStream?.dispose();
// //     } catch (e) {
// //       debugPrint('detachLocal: disposing localStream failed: $e');
// //     }
// //     localStream = null;
// //   }

// //   // ------------------ Offer/Answer blob helpers (Firestore-style BLOBs) ------------------
// //   Future<String> makeOfferBlob() async {
// //     if (pc == null) throw Exception('PC not initialized');
// //     final offer = await pc!.createOffer({'offerToReceiveAudio': true});
// //     debugPrint('makeOfferBlob: creating offer, signalingState=${pc!.signalingState}');
// //     await pc!.setLocalDescription(offer);
// //     await _waitIceComplete();
// //     final sd = await pc!.getLocalDescription();
// //     final blob = jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
// //     debugPrint('makeOfferBlob done. signalingState=${pc!.signalingState}');
// //     return blob;
// //   }

// //   Future<void> acceptOfferBlob(String blob) async {
// //     if (pc == null) throw Exception('PC not initialized');
// //     final map = jsonDecode(blob) as Map<String, dynamic>;
// //     final desc = RTCSessionDescription(map['sdp'], map['type']);
// //     debugPrint('acceptOfferBlob: applying remote offer, signalingState=${pc!.signalingState}');
// //     await safeSetRemoteDescription(desc);
// //     final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
// //     await pc!.setLocalDescription(answer);
// //     await _waitIceComplete();
// //     debugPrint('acceptOfferBlob: answer created and setLocal, signalingState=${pc!.signalingState}');
// //   }

// //   Future<String> getAnswerBlob() async {
// //     final sd = await pc!.getLocalDescription();
// //     return jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
// //   }

// //   Future<void> acceptAnswerBlob(String blob) async {
// //     if (pc == null) throw Exception('PC not initialized');
// //     final map = jsonDecode(blob) as Map<String, dynamic>;
// //     final desc = RTCSessionDescription(map['sdp'], map['type']);
// //     debugPrint('acceptAnswerBlob: applying answer, signalingState=${pc!.signalingState}');
// //     await safeSetRemoteDescription(desc);
// //   }

// //   // Helper to wait until ICE gathering complete
// //   Future<void> _waitIceComplete() async {
// //     if (pc == null) return;
// //     while (pc!.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
// //       await Future.delayed(const Duration(milliseconds: 120));
// //     }
// //   }

// //   /// Safe setRemoteDescription; on "wrong state" tries rollback then retry.
// //   Future<void> safeSetRemoteDescription(RTCSessionDescription desc) async {
// //     if (pc == null) throw Exception('PC not initialized');
// //     try {
// //       debugPrint('safeSetRemoteDescription: before setRemote, signalingState=${pc!.signalingState}');
// //       await pc!.setRemoteDescription(desc);
// //       debugPrint('safeSetRemoteDescription: setRemote succeeded');
// //       return;
// //     } catch (e) {
// //       final err = e.toString();
// //       debugPrint('safeSetRemoteDescription: initial setRemote failed: $err');
// //       if (err.contains('Called in wrong state') || err.contains('InvalidStateError')) {
// //         try {
// //           debugPrint('safeSetRemoteDescription: attempting rollback');
// //           await pc!.setLocalDescription(RTCSessionDescription('', 'rollback'));
// //           await Future.delayed(const Duration(milliseconds: 150));
// //           debugPrint('safeSetRemoteDescription: retrying setRemote after rollback');
// //           await pc!.setRemoteDescription(desc);
// //           debugPrint('safeSetRemoteDescription: setRemote succeeded after rollback');
// //           return;
// //         } catch (e2) {
// //           debugPrint('safeSetRemoteDescription: retry failed: $e2');
// //           rethrow;
// //         }
// //       } else {
// //         try {
// //           await Future.delayed(const Duration(milliseconds: 120));
// //           await pc!.setRemoteDescription(desc);
// //           debugPrint('safeSetRemoteDescription: retry succeeded');
// //           return;
// //         } catch (e3) {
// //           debugPrint('safeSetRemoteDescription: retry also failed: $e3');
// //           rethrow;
// //         }
// //       }
// //     }
// //   }

// //   /// create data channel on current pc
// //   Future<RTCDataChannel> createLocalDataChannel([String label = 'chat']) async {
// //     if (pc == null) throw Exception('PC not initialized');
// //     final dc = await pc!.createDataChannel(label, RTCDataChannelInit()..ordered = true);
// //     chat = dc;
// //     return dc;
// //   }

// //   Future<void> close() async {
// //     try { await chat?.close(); } catch (_) {}
// //     try { await pc?.close(); } catch (_) {}
// //     try { await _socket?.close(); } catch (_) {}
// //     pc = null;
// //     chat = null;
// //     localStream = null;
// //     remoteStream = null;
// //     _socket = null;
// //   }

// //   // Utility: ensure pc exists - used by manager to call signaling.init() if needed.
// //   Future<void> connectionFallbackInitIfNeeded() async {
// //     if (pc == null) {
// //       await init();
// //     }
// //   }
// // }
