import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket, HttpClient;
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

  List<Map<String, dynamic>> _userFallbackIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  // final Map<String, dynamic> config = {
  //   'iceServers': [
  //     {'urls': 'stun:stun.l.google.com:19302'},
  //   ],
  //   'sdpSemantics': 'unified-plan',
  // };
  final Map<String, dynamic> config = {
    'iceServers': [], // временно пусто, заполнится в init()
    'sdpSemantics': 'unified-plan',
  };

  void setFallbackIceServers(List<Map<String, dynamic>> servers) {
    _userFallbackIceServers = servers;
  }

  Future<List<Map<String, dynamic>>> _fetchXirsysIceServers() async {
    const ident = 'realtemity';
    const secret = '97719ea0-a0a1-11f1-b5a1-0242ac150002';
    final credentials = base64Encode(utf8.encode('$ident:$secret'));

    final client = HttpClient();
    try {
      final request = await client
          .putUrl(Uri.parse('https://global.xirsys.net/_turn/wave'));
      request.headers.set('Authorization', 'Basic $credentials');
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(jsonEncode({'format': 'urls'})));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final iceServers = data['v']['iceServers'] as List?;
        if (iceServers != null) {
          return iceServers.map((e) => e as Map<String, dynamic>).toList();
        } else {
          throw Exception('No iceServers in response');
        }
      } else {
        throw Exception(
            'Xirsys API error: ${response.statusCode} - $responseBody');
      }
    } finally {
      client.close();
    }
  }

  /// Initialize RTCPeerConnection (create pc and set handlers)
  Future<void> init() async {
    List<Map<String, dynamic>> iceServers;
    try {
      iceServers = await _fetchXirsysIceServers();
      debugPrint('✅ Xirsys ICE servers fetched successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to fetch Xirsys ICE servers: $e');
      // 2. Запасной вариант (Open Relay Project + STUN Google)
      if (_userFallbackIceServers.isNotEmpty) {
        debugPrint('🔄 Using user-provided fallback ICE servers');
        iceServers = _userFallbackIceServers;
      } else {
        // Иначе стандартный fallback (Google STUN + Open Relay TURN)
        debugPrint('🔄 Using default fallback ICE servers');
        iceServers = [
          {'urls': 'stun:stun.l.google.com:19302'},
          {
            'urls': [
              'turn:openrelay.metered.ca:80',
              'turn:openrelay.metered.ca:443',
              'turn:openrelay.metered.ca:443?transport=tcp',
            ],
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
        ];
      }
      // iceServers = [
      //   {'urls': 'stun:stun.l.google.com:19302'},
      //   {
      //     'urls': [
      //       'turn:openrelay.metered.ca:80',
      //       'turn:openrelay.metered.ca:443',
      //       'turn:openrelay.metered.ca:443?transport=tcp',
      //     ],
      //     'username': 'openrelayproject',
      //     'credential': 'openrelayproject',
      //   },
      // ];
      // debugPrint('🔄 Using fallback ICE servers');
    }

    config['iceServers'] = iceServers;

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

  /// Attach local stream. If attachToPc == false, only store localStream locally,
  /// do not call addTrack on pc. This allows controlling when audio is actually sent.
  Future<void> attachLocal(MediaStream stream, {bool attachToPc = true}) async {
    localStream = stream;
    if (pc == null) {
      debugPrint('attachLocal: pc == null, saved localStream only');
      return;
    }
    if (!attachToPc) {
      debugPrint('attachLocal: attachToPc is false, saved localStream only');
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
              debugPrint(
                  'detachLocal: replaced sender ${s.track?.id} with null');
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
    debugPrint(
        'makeOfferBlob: creating offer, signalingState=${pc!.signalingState}');
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
    debugPrint(
        'acceptOfferBlob: applying remote offer, signalingState=${pc!.signalingState}');
    await safeSetRemoteDescription(desc);
    final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
    await pc!.setLocalDescription(answer);
    await _waitIceComplete();
    debugPrint(
        'acceptOfferBlob: answer created and setLocal, signalingState=${pc!.signalingState}');
  }

  Future<String> getAnswerBlob() async {
    final sd = await pc!.getLocalDescription();
    return jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
  }

  Future<void> acceptAnswerBlob(String blob) async {
    if (pc == null) throw Exception('PC not initialized');
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final desc = RTCSessionDescription(map['sdp'], map['type']);
    debugPrint(
        'acceptAnswerBlob: applying answer, signalingState=${pc!.signalingState}');
    await safeSetRemoteDescription(desc);
  }

  Future<void> _waitIceComplete() async {
    if (pc == null) return;
    while (pc!.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> safeSetRemoteDescription(RTCSessionDescription desc) async {
    if (pc == null) throw Exception('PC not initialized');
    try {
      debugPrint(
          'safeSetRemoteDescription: before setRemote, signalingState=${pc!.signalingState}');
      await pc!.setRemoteDescription(desc);
      debugPrint('safeSetRemoteDescription: setRemote succeeded');
      return;
    } catch (e) {
      final err = e.toString();
      debugPrint('safeSetRemoteDescription: initial setRemote failed: $err');
      if (err.contains('Called in wrong state') ||
          err.contains('InvalidStateError')) {
        try {
          debugPrint('safeSetRemoteDescription: attempting rollback');
          await pc!.setLocalDescription(RTCSessionDescription('', 'rollback'));
          await Future.delayed(const Duration(milliseconds: 150));
          debugPrint(
              'safeSetRemoteDescription: retrying setRemote after rollback');
          await pc!.setRemoteDescription(desc);
          debugPrint(
              'safeSetRemoteDescription: setRemote succeeded after rollback');
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
    final dc = await pc!
        .createDataChannel(label, RTCDataChannelInit()..ordered = true);
    chat = dc;
    return dc;
  }

  Future<void> close() async {
    try {
      await chat?.close();
    } catch (_) {}
    try {
      await pc?.close();
    } catch (_) {}
    try {
      await _socket?.close();
    } catch (_) {}
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
