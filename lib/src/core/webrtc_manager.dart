// webrtc_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart' as words;
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'signaling.dart';
import 'storage.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/models/chat_message.dart';

enum SystemMessageType { event, info }

enum EventSeverity { positive, negative, neutral }

class ParticipantState {
  final String id;
  String? name;
  bool inCall;
  bool muted;
  Timestamp? ts;
  ParticipantState(
      {required this.id,
      this.name,
      this.inCall = false,
      this.muted = true,
      this.ts});
}

class WebRTCManager extends ChangeNotifier {
  final Signaling signaling = Signaling();
  final LocalStorage storage;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  WebRTCManager({required this.storage});

  // UI public
  CallState callState = CallState.disconnected;
  RTCDataChannel? chat;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  List<MediaDeviceInfo> devices = [];
  String? selectedMicId;
  String? selectedSpeakerId;

  final List<ChatMessage> _history = [];
  List<ChatMessage> get history => List.unmodifiable(_history);

  final _incomingCtrl = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingMessages => _incomingCtrl.stream;

  int unread = 0;
  final String localId = const Uuid().v4();
  String localName = 'You';

  bool _muted = false;
  bool get muted => _muted;

  String? lastOfferBlob;
  String? lastAnswerBlob;
  String? offerId;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _answerSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callDocSub;

  bool _localAudioActive = false;
  bool get localAudioActive => _localAudioActive;

  bool _inCall = false;
  bool get inCall => _inCall;

  bool _renegotiationInProgress = false;
  bool _pendingRenegotiationRequested = false;
  bool _makingOffer = false;

  final Map<String, ParticipantState> participants = {};
  final Map<String, Completer<String?>> _renegCompleters = {};
  final List<String> _presenceQueue = [];

  bool get isOfferCreated => offerId != null && offerId!.isNotEmpty;
  bool get isAnswerAvailable =>
      lastAnswerBlob != null && lastAnswerBlob!.isNotEmpty;

  String? callKeepUUID; // UI side may use this for CallKeep

  // ---------------- lifecycle ----------------
  Future<void> init() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    await _remoteRenderer.initialize();
    await localRenderer.initialize();
    await signaling.connectionFallbackInitIfNeeded();
    _wirePc();
    await updateAudioDevices();
    chat = signaling.chat;
    if (chat != null) _wireDataChannel(chat!);
    _pushSystemMessage('Peer has been connected',
        type: SystemMessageType.event, severity: EventSeverity.positive);
    _pushSystemMessage(
        'Attention! Conversation history will be cleared on new connection',
        type: SystemMessageType.info);
  }

  @override
  void dispose() {
    _incomingCtrl.close();
    _cancelAnswerWatch();
    try {
      _remoteRenderer.dispose();
    } catch (_) {}
    try {
      localRenderer.dispose();
    } catch (_) {}
    _callDocSub?.cancel();
    _callDocSub = null;
    super.dispose();
  }

  void _log(String msg) => print('[WebRTCManager][$localId] $msg');

  void _pushSystemMessage(String text,
      {SystemMessageType type = SystemMessageType.info,
      EventSeverity severity = EventSeverity.neutral}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final prefix = (type == SystemMessageType.event)
        ? '[Event:${severity.toString().split('.').last}] '
        : '[Info] ';
    final sys = ChatMessage(
        id: id, author: 'System', text: '$prefix$text', ts: DateTime.now());
    _history.add(sys);
    _incomingCtrl.add(sys);
    unawaited(storage.appendMessage(sys));
  }

  void _cancelAnswerWatch() {
    unawaited(_answerSub?.cancel());
    _answerSub = null;
  }

  // ---------------- PC wiring ----------------
  void _wirePc() {
    final pc = signaling.pc;
    if (pc == null) return;

    pc.onConnectionState = (s) async {
      _log('pc.onConnectionState: $s');
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          if (kIsWeb || Platform.isIOS) {
            await _remoteRenderer.initialize();
            _updateRemoteAudioPlayback();
          }
          callState = CallState.connected;
          _startCallTimer();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _pushSystemMessage('Peer has been terminated',
              type: SystemMessageType.event, severity: EventSeverity.negative);
          callState = CallState.failed;
          _stopCallTimer();
          await _softLeaveOnPcFailure();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _pushSystemMessage('Peer has been disconnected',
              type: SystemMessageType.event, severity: EventSeverity.neutral);
          callState = CallState.disconnected;
          _stopCallTimer();
          await _softLeaveOnPcFailure();
          break;
        default:
          callState = CallState.connecting;
      }
      notifyListeners();
    };

    pc.onDataChannel = (dc) {
      chat = dc;
      _wireDataChannel(dc);
      notifyListeners();
    };

    pc.onTrack = (e) {
      _log('pc.onTrack: streams.length=${e.streams.length}');
      if (e.streams.isNotEmpty) {
        remoteStream = e.streams.first;
        _log(
            'pc.onTrack: got remoteStream id=${remoteStream?.id}, audioTracks=${remoteStream?.getAudioTracks().map((t) => t.id).toList()}');
        _updateRemoteAudioPlayback();
        notifyListeners();
      } else {
        _log('pc.onTrack: no streams in event');
      }
    };

    // WebSocket signaling callbacks (if used)
    signaling.onOffer = (from, sdp) async {
      _log('Signaling.onOffer from $from');
      await _handleRemoteOffer(from, sdp);
    };
    signaling.onAnswer = (from, sdp) async {
      _log('Signaling.onAnswer from $from');
      try {
        await signaling
            .safeSetRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      } catch (e) {
        _log('Failed to apply remote answer: $e');
      }
    };
    signaling.onCandidate = (from, cand) async {
      if (cand == null) return;
      final pc2 = signaling.pc;
      if (pc2 == null) return;
      try {
        final c = RTCIceCandidate(
            cand['candidate'], cand['sdpMid'], cand['sdpMLineIndex']);
        await pc2.addCandidate(c);
        _log('Applied remote candidate');
      } catch (e) {
        _log('Applying remote candidate failed: $e');
      }
    };
  }

  Future<void> _softLeaveOnPcFailure() async {
    try {
      final pc = signaling.pc;
      if (pc != null) {
        final senders = await pc.getSenders();
        for (final s in senders) {
          if (s.track != null && s.track!.kind == 'audio') {
            try {
              await s.replaceTrack(null);
              _log(
                  'softLeaveOnPcFailure: replaced audio sender track with null');
            } catch (e) {
              _log('softLeaveOnPcFailure replaceTrack null failed: $e');
            }
          }
        }
      }
    } catch (e) {
      _log('softLeaveOnPcFailure: $e');
    }
    _inCall = false;
    participants[localId] = ParticipantState(
        id: localId, name: localName, inCall: false, muted: true);
    await _sendPresenceOverDc(inCall: false, micOn: false);
    _updateRemoteAudioPlayback();
    notifyListeners();
  }

  // ---------------- DataChannel ----------------
  void _wireDataChannel(RTCDataChannel dc) {
    dc.onMessage = (m) {
      try {
        final payload = jsonDecode(m.text);
        if (payload is Map<String, dynamic>) {
          final type = payload['type'] as String?;
          if (type == 'presence') {
            final id = payload['id'] as String?;
            if (id != null) {
              final inCall = payload['inCall'] as bool? ?? false;
              final micOn = payload['micOn'] as bool? ?? false;
              final name = payload['name'] as String? ?? id;
              participants[id] = ParticipantState(
                  id: id, name: name, inCall: inCall, muted: !micOn, ts: null);
              _log('Received presence from $id (inCall=$inCall, micOn=$micOn)');
              _updateRemoteAudioPlayback();
              notifyListeners();
              return;
            }
          } else if (type == 'renegotiation-offer') {
            _handleDcRenegotiationOffer(payload);
            return;
          } else if (type == 'renegotiation-answer') {
            _handleDcRenegotiationAnswer(payload);
            return;
          }
        }
      } catch (e) {
        // not JSON -> chat text
      }

      final text =
          m.isBinary ? '[binary ${m.binary?.length ?? 0} bytes]' : m.text;
      final msg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          author: 'Peer',
          text: text,
          ts: DateTime.now());
      _history.add(msg);
      _incomingCtrl.add(msg);
      unawaited(storage.appendMessage(msg));
      unread++;
      notifyListeners();
    };

    dc.onDataChannelState = (s) async {
      _log('dataChannel state: $s');
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        await _flushPresenceQueue();
        await _sendPresenceOverDc();
      }
    };
  }

  Future<void> _handleDcRenegotiationOffer(Map<String, dynamic> payload) async {
    final sdp = payload['sdp'] as String?;
    final from = payload['from'] as String?;
    final renId = payload['id'] as String?;
    if (sdp == null) {
      _log('renegotiation-offer: missing sdp');
      return;
    }
    _log('Received renegotiation-offer via DC from $from id=$renId');

    final pc = signaling.pc;
    if (pc == null) {
      _log('No pc to handle renegotiation offer');
      return;
    }

    bool makingLocalOffer = _renegotiationInProgress || _makingOffer;
    final polite = (from != null) ? (localId.compareTo(from) < 0) : true;

    if (makingLocalOffer) {
      _log('Glare detected (we are making local offer). polite=$polite');
      if (!polite) {
        _log(
            'Ignoring incoming offer because we are impolite and already making an offer');
        return;
      } else {
        try {
          _log('Attempting rollback to handle glare (polite)');
          await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
          _log('Rollback succeeded');
        } catch (e) {
          _log(
              'Rollback failed or unsupported: $e - will try to continue anyway');
        }
      }
    }

    try {
      await signaling
          .safeSetRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);

      final resp = jsonEncode({
        'type': 'renegotiation-answer',
        'sdp': answer.sdp,
        'to': from,
        'from': localId,
        'id': renId
      });
      final dc = chat ?? signaling.chat;
      if (dc != null && dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        dc.send(RTCDataChannelMessage(resp));
        _log('Sent renegotiation-answer via DC id=$renId');
      } else {
        _log('Cannot send renegotiation-answer, data channel not open');
      }
    } catch (e) {
      _log('Failed to handle dc renegotiation-offer: $e');
    }
  }

  Future<void> _handleDcRenegotiationAnswer(
      Map<String, dynamic> payload) async {
    final sdp = payload['sdp'] as String?;
    final to = payload['to'] as String?;
    final id = payload['id'] as String?;
    if (to != localId) {
      _log('renegotiation-answer not for me (to=$to)');
      return;
    }
    if (sdp == null) {
      _log('renegotiation-answer: missing sdp');
      return;
    }
    _log(
        'Received renegotiation-answer via DC id=$id, applying remote description');
    final pc = signaling.pc;
    if (pc != null) {
      try {
        await signaling
            .safeSetRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        _log('Applied renegotiation answer from DC id=$id');
      } catch (e) {
        _log('Failed to apply renegotiation answer from DC: $e');
      }
    }
    if (id != null &&
        _renegCompleters.containsKey(id) &&
        !_renegCompleters[id]!.isCompleted) {
      _renegCompleters[id]!.complete(sdp);
      _renegCompleters.remove(id);
    }
  }

  // ---------------- Audio helpers ----------------
  Future<bool> checkMicrophonePermission() async {
    if (kIsWeb) {
      try {
        final s = await navigator.mediaDevices.getUserMedia({'audio': true});
        s.getTracks().forEach((t) => t.stop());
        return true;
      } catch (e) {
        _log('Microphone access denied (web): $e');
        return false;
      }
    }
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final status = await Permission.microphone.request();
        return status.isGranted;
      } catch (e) {
        _log('Microphone permission request failed: $e');
        return false;
      }
    }
    _log('Unsupported platform for microphone permission check');
    return false;
  }

  /// Create or update local audio stream.
  /// IMPORTANT: do NOT attach to PeerConnection unless _inCall == true.
  Future<void> _ensureLocalAudio({bool unmuted = true}) async {
    final allowed = await checkMicrophonePermission();
    if (!allowed) throw Exception('Microphone permission denied');

    if (localStream != null) {
      final tracks = localStream!.getAudioTracks();
      if (tracks.isNotEmpty) {
        tracks.first.enabled = unmuted;
        _muted = !unmuted;
      }
      notifyListeners();
      return;
    }

    final constraints = <String, dynamic>{
      'audio': selectedMicId == null ? true : {'deviceId': selectedMicId},
      'video': false
    };
    final s = await navigator.mediaDevices.getUserMedia(constraints);
    final audioTracks = s.getAudioTracks();
    if (audioTracks.isNotEmpty) audioTracks.first.enabled = unmuted;

    localStream = s;
    _localAudioActive = true;
    _muted = !unmuted;
    _log(
        'ensureLocalAudio: created stream id=${s.id}, audioTracks=${audioTracks.map((t) => t.id).toList()}');

    // Attach to signaling/pc ONLY if user is in call. This prevents sending audio while not in call.
    try {
      await signaling.attachLocal(s, attachToPc: _inCall);
      if (_inCall)
        _log(
            'ensureLocalAudio: attached local stream to signaling (inCall==true)');
      else
        _log(
            'ensureLocalAudio: saved local stream (not attaching to pc while not in call)');
      await dumpPcState('after-attachLocal');
    } catch (e) {
      _log('Warning: signaling.attachLocal failed: $e');
    }

    if (_inCall) await _sendPresenceOverDc(inCall: true, micOn: !_muted);
    notifyListeners();
  }

  Future<void> updateAudioDevices() async {
    try {
      final all = await navigator.mediaDevices.enumerateDevices();
      final seen = <String>{};
      devices = [];
      for (final d in all) {
        final id = d.deviceId ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        devices.add(d);
      }
      notifyListeners();
    } catch (e) {
      _log('Failed to enumerate devices: $e');
    }
  }

  Future<void> selectMic(String? id) async {
    selectedMicId = id;
    _log('Selected microphone: $id');
    if (localStream != null && _inCall) {
      await _recreateLocalAudio();
    } else if (localStream != null && !_inCall) {
      await _recreateLocalAudio(attachIfInCall: false);
    }
    if (_inCall) {
      await _sendPresenceOverDc(inCall: true, micOn: !_muted);
    }
    notifyListeners();
  }

  Future<void> selectSpeaker(String? id) async {
    selectedSpeakerId = id;
    _log('Selected speaker: $id');
    if (kIsWeb && id != null) {
      try {
        await _remoteRenderer.audioOutput(id);
      } catch (e) {
        _log('Failed to set audio output: $e');
      }
    } else {
      // On native mobile platforms switching sinks typically requires native code (platform channels).
      // Here we only store selection; you may need to implement platform-specific switching.
    }
    notifyListeners();
  }

  /// Recreate local audio stream; when attachIfInCall==false we only update localStream without touching pc.
  Future<void> _recreateLocalAudio({bool attachIfInCall = true}) async {
    if (localStream == null) {
      _log('_recreateLocalAudio: localStream == null -> nothing to do');
      return;
    }
    final wasMuted = _muted;
    final currentMicId = selectedMicId;
    try {
      final constraints = <String, dynamic>{
        'audio': currentMicId == null ? true : {'deviceId': currentMicId},
        'video': false
      };
      final newStream = await navigator.mediaDevices.getUserMedia(constraints);
      final newAudioTracks = newStream.getAudioTracks();
      if (newAudioTracks.isEmpty)
        throw Exception('No audio tracks in new stream');
      final newAudioTrack = newAudioTracks.first;
      newAudioTrack.enabled = !wasMuted;

      final pc = signaling.pc;
      if (_inCall && attachIfInCall) {
        if (pc == null) {
          await signaling.attachLocal(newStream, attachToPc: true);
          _log('_recreateLocalAudio: pc==null, attachLocal performed');
        } else {
          final senders = await pc.getSenders();
          RTCRtpSender? audioSender;
          for (final s in senders) {
            final t = s.track;
            if (t != null && t.kind == 'audio') {
              audioSender = s;
              break;
            }
          }
          if (audioSender != null) {
            try {
              await audioSender.replaceTrack(newAudioTrack);
              _log('replaceTrack succeeded');
            } catch (e) {
              _log(
                  'replaceTrack failed: $e — will try addTrack + renegotiation');
              try {
                await pc.addTrack(newAudioTrack, newStream);
                _log('addTrack succeeded after replaceTrack failure');
                await _requestRenegotiation();
              } catch (e2) {
                _log('addTrack also failed: $e2');
                rethrow;
              }
            }
          } else {
            try {
              await pc.addTrack(newAudioTrack, newStream);
              _log(
                  'addTrack succeeded (no previous audio sender). Initiating renegotiation.');
              await _requestRenegotiation();
            } catch (e) {
              _log('addTrack failed: $e');
              rethrow;
            }
          }
        }
      } else {
        // Not in call: just replace local stream, don't touch pc
        _log(
            '_recreateLocalAudio: updating localStream offline (not attaching to pc)');
        await signaling.attachLocal(newStream, attachToPc: false);
      }

      for (final t in localStream!.getTracks())
        try {
          t.stop();
        } catch (_) {}
      try {
        await localStream!.dispose();
      } catch (_) {}
      localStream = newStream;
      _muted = wasMuted;

      if (_inCall) await _sendPresenceOverDc(inCall: true, micOn: !_muted);
      notifyListeners();
    } catch (e) {
      _log('Error recreating local audio: $e');
      _muted = wasMuted;
      notifyListeners();
      rethrow;
    }
  }

  // ---------------- Renegotiation ----------------
  Future<void> _requestRenegotiation(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (_renegotiationInProgress) {
      _log('Renegotiation already in progress — queueing another request');
      _pendingRenegotiationRequested = true;
      return;
    }
    final pc = signaling.pc;
    if (pc == null) {
      _log('No pc for renegotiation');
      return;
    }
    _renegotiationInProgress = true;
    _makingOffer = true;
    final renegId = _makeNonce(12);
    try {
      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      final offerSdp = offer.sdp;
      if (offerSdp == null) throw Exception('Empty offer SDP');
      final dc = chat ?? signaling.chat;
      if (dc != null && dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        final completer = Completer<String?>();
        _renegCompleters[renegId] = completer;
        final msg = jsonEncode({
          'type': 'renegotiation-offer',
          'sdp': offerSdp,
          'from': localId,
          'id': renegId,
          'ts': DateTime.now().toIso8601String()
        });
        try {
          dc.send(RTCDataChannelMessage(msg));
          _log('Sent renegotiation-offer via DC id=$renegId');
        } catch (e) {
          _log('Failed to send renegotiation via DC: $e');
          _renegCompleters.remove(renegId);
          return;
        }
        String? answer;
        try {
          answer = await completer.future.timeout(timeout);
        } catch (e) {
          answer = null;
        } finally {
          _renegCompleters.remove(renegId);
        }
        if (answer != null) {
          await signaling.safeSetRemoteDescription(
              RTCSessionDescription(answer, 'answer'));
          _log('Applied renegotiation answer from DC id=$renegId');
        } else {
          _log('No answer received for renegotiation via DC id=$renegId');
        }
      } else {
        _log('Data channel not open, cannot renegotiate via DC');
      }
    } catch (e) {
      _log('Renegotiation failed: $e');
      rethrow;
    } finally {
      _makingOffer = false;
      _renegotiationInProgress = false;
      if (_pendingRenegotiationRequested) {
        _pendingRenegotiationRequested = false;
        unawaited(_requestRenegotiation(timeout: timeout));
      }
    }
  }

  String _makeNonce([int len = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ---------------- Offer/Answer / Firestore two-word code flow ----------------
  Future<String> createOfferLink() async {
    _makingOffer = true;
    try {
      await signaling.connectionFallbackInitIfNeeded();
      final dc = await signaling.createLocalDataChannel();
      chat = dc;
      _wireDataChannel(dc);

      final offerBlob = await signaling.makeOfferBlob();
      lastOfferBlob = offerBlob;
      notifyListeners();

      var id = _generateId();
      var doc = firestore.collection('calls').doc(id);
      while (true) {
        final snap = await doc.get();
        if (!snap.exists) break;
        final data = snap.data()!;
        final ts = data['createdAt'] as Timestamp?;
        if (_isExpired(ts)) break;
        id = _generateId();
        doc = firestore.collection('calls').doc(id);
      }

      await doc.set({
        'offer': offerBlob,
        'answer': null,
        'createdAt': FieldValue.serverTimestamp(),
        'answeredAt': null
      });
      offerId = id;
      _cancelAnswerWatch();

      _watchCallDoc();
      _answerSub = doc.snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        final ab = data['answer'] as String?;
        if (ab != null && ab.isNotEmpty) {
          lastAnswerBlob = ab;
          notifyListeners();
        }
      }, onError: (e) {
        _log('Answer watch error: $e');
      });

      participants[localId] = ParticipantState(
          id: localId, name: localName, inCall: false, muted: true);
      notifyListeners();

      callKeepUUID = const Uuid().v4();
      return id;
    } finally {
      _makingOffer = false;
    }
  }

  Future<String> acceptOffer(String id) async {
    final ref = firestore.collection('calls').doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Invite id "$id" not found');
    final data = snap.data()!;
    final createdAt = data['createdAt'] as Timestamp?;
    if (_isExpired(createdAt)) throw Exception('ID "$id" expired');
    final offerBlob = data['offer'] as String?;
    if (offerBlob == null || offerBlob.isEmpty)
      throw Exception('Offer missing in doc');

    offerId = id;
    _watchCallDoc();

    await signaling.connectionFallbackInitIfNeeded();
    await signaling.acceptOfferBlob(offerBlob);
    final answerBlob = await signaling.getAnswerBlob();

    await ref.update(
        {'answer': answerBlob, 'answeredAt': FieldValue.serverTimestamp()});
    lastAnswerBlob = answerBlob;
    participants[localId] = ParticipantState(
        id: localId, name: localName, inCall: false, muted: true);
    notifyListeners();
    callKeepUUID = const Uuid().v4();
    return id;
  }

  Future<void> acceptAnswer(String id) async {
    final ref = firestore.collection('calls').doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Doc "$id" not found');
    final data = snap.data()!;
    final createdAt = data['createdAt'] as Timestamp?;
    if (_isExpired(createdAt)) throw Exception('ID "$id" expired');
    final answerBlob = data['answer'] as String?;
    if (answerBlob == null || answerBlob.isEmpty)
      throw Exception('Answer for "$id" not ready');
    lastAnswerBlob = answerBlob;
    notifyListeners();
    await signaling.connectionFallbackInitIfNeeded();
    await signaling.acceptAnswerBlob(answerBlob);
  }

  // ---------------- Start / Join Call ----------------
  Future<void> startCall() async {
    final allowed = await checkMicrophonePermission();
    if (!allowed) throw Exception('Microphone permission denied');

    // Ensure local stream exists (preserve mute state)
    if (localStream == null) {
      // create local stream but don't force unmute if user was muted
      await _ensureLocalAudio(unmuted: !_muted);
    } else {
      // ensure track.enabled reflects desired unmuted state on start
      final tracks = localStream!.getAudioTracks();
      if (tracks.isNotEmpty) tracks.first.enabled = !_muted;
    }

    _inCall = true;
    participants[localId] = ParticipantState(
        id: localId, name: localName, inCall: true, muted: _muted);
    notifyListeners();

    // Inform others
    if (offerId != null) {
      await _sendPresenceOverDc(inCall: true, micOn: !_muted);
    }

    final pc = signaling.pc;
    if (pc != null) {
      try {
        // Attach local stream to PC (this will add tracks if not present)
        if (localStream != null) {
          await signaling.attachLocal(localStream!, attachToPc: true);
          _log('startCall: signaling.attachLocal done');

          // Wait tiny moment for native internals
          await Future.delayed(const Duration(milliseconds: 120));

          // Dump senders/transceivers for debugging
          try {
            final senders = await pc.getSenders();
            _log('startCall: post-attach senders count=${senders.length}');
            for (var s in senders) {
              _log(
                  ' startCall sender: kind=${s.track?.kind}, id=${s.track?.id}, label=${s.track?.label}');
            }
          } catch (e) {
            _log('startCall: getSenders failed: $e');
          }

          // Ensure remote side knows we want to send audio if we are not muted
          if (!_muted) {
            try {
              await _requestRenegotiation();
              _log('startCall: renegotiation requested after attach');
            } catch (e) {
              _log('startCall: renegotiation failed: $e');
            }
          } else {
            _log(
                'startCall: not requesting renegotiation because user is muted');
          }
        }
      } catch (e) {
        _log('startCall: error inspecting pc/senders: $e');
      }
    } else {
      _log('startCall: pc is null (will attach when pc becomes available)');
    }

    // Update remote playback policy
    _updateRemoteAudioPlayback();
  }

  Future<void> leaveCall() async {
    try {
      final pc = signaling.pc;
      if (pc != null) {
        try {
          final senders = await pc.getSenders();
          for (final s in senders) {
            if (s.track != null && s.track!.kind == 'audio') {
              try {
                await s.replaceTrack(null);
                _log('leaveCall: replaced audio sender track with null');
              } catch (e) {
                _log('leaveCall: replaceTrack(null) failed: $e');
              }
            }
          }
        } catch (e) {
          _log('leaveCall: error during pc cleanup: $e');
        }
      }

      // Do NOT stop or dispose localStream here — keep it for quick rejoin and preserve mute state.
      _inCall = false;

      participants[localId] = ParticipantState(
        id: localId,
        name: localName,
        inCall: false,
        muted: _muted,
      );

      // Send updated presence (we are no longer in call)
      await _sendPresenceOverDc(inCall: false, micOn: !_muted);

      _updateRemoteAudioPlayback();

      notifyListeners();
    } catch (e) {
      _log('leaveCall error: $e');
    }
  }

  // ---------------- Mute/Unmute (fixed) ----------------
  /// Toggle microphone mute/unmute. Does NOT leave call.
  Future<void> toggleMicMute() async {
    final currentlyMuted = _muted;
    final willBeMuted = !currentlyMuted;

    // If unmuting and we don't have a local stream, create one (but do not force leave/join)
    if (localStream == null && !willBeMuted) {
      try {
        await _ensureLocalAudio(unmuted: true);
      } catch (e) {
        _log('toggleMicMute: failed to ensure local audio: $e');
        return;
      }
    }

    // Toggle the track enabled flag if we have a track
    if (localStream != null) {
      final tracks = localStream!.getAudioTracks();
      if (tracks.isNotEmpty) {
        try {
          tracks.first.enabled = !willBeMuted;
        } catch (e) {
          _log('toggleMicMute: failed to set track.enabled: $e');
        }
      }
    }

    _muted = willBeMuted;
    _log('toggleMicMute: muted=$_muted');

    final pc = signaling.pc;
    if (_inCall && pc != null) {
      // If unmuting -> make sure we are actually sending (some implementations need renegotiation)
      if (!_muted) {
        try {
          // ensure local stream is attached to pc
          if (localStream != null) {
            await signaling.attachLocal(localStream!, attachToPc: true);
            _log('toggleMicMute: attachLocal done on unmute');
          }

          // small delay to let native addTrack settle
          await Future.delayed(const Duration(milliseconds: 120));

          // request renegotiation to make sure transceivers are sendrecv
          await _requestRenegotiation();
          _log('toggleMicMute: renegotiation requested on unmute');
        } catch (e) {
          _log('toggleMicMute: error on unmute flow (attach/reneg): $e');
        }
      } else {
        // Muting: we prefer to only disable track.enabled to avoid renegotiation.
        _log(
            'toggleMicMute: muted locally; track.enabled=false (no replaceTrack) to avoid renegotiation');
      }
    }

    // Notify others of mic state; keep inCall unchanged.
    await _sendPresenceOverDc(inCall: _inCall, micOn: !_muted);

    _updateRemoteAudioPlayback();
    notifyListeners();
  }

  // ---------------- Presence via DC ----------------
  Future<void> _sendPresenceOverDc({bool? inCall, bool? micOn}) async {
    final payload = {
      'type': 'presence',
      'id': localId,
      'name': localName,
      'inCall': inCall ?? _inCall,
      'micOn': micOn ?? !_muted,
      'ts': DateTime.now().toIso8601String()
    };
    final msg = jsonEncode(payload);
    final dc = chat ?? signaling.chat;
    if (dc != null && dc.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        dc.send(RTCDataChannelMessage(msg));
        _log('Sent presence via DC: $msg');
      } catch (e) {
        _log('Failed to send presence via DC, queueing: $e');
        _presenceQueue.add(msg);
      }
    } else {
      _log('DC not open yet — queue presence');
      _presenceQueue.add(msg);
    }
  }

  Future<void> _flushPresenceQueue() async {
    final dc = chat ?? signaling.chat;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen)
      return;
    while (_presenceQueue.isNotEmpty) {
      final m = _presenceQueue.removeAt(0);
      try {
        dc.send(RTCDataChannelMessage(m));
        _log('Flushed presence msg via DC: $m');
      } catch (e) {
        _log('Failed to flush presence msg, requeue: $e');
        _presenceQueue.insert(0, m);
        break;
      }
    }
  }

  // ---------------- Remote audio playback control ----------------
  bool _anyRemoteSpeaking() {
    for (final p in participants.values) {
      if (p.id == localId) continue;
      if (p.inCall && !p.muted) return true;
    }
    return false;
  }

  bool _shouldPlayRemoteAudio() {
    // Only play remote audio if local user inCall and at least one remote participant inCall with micOn
    if (!_inCall) return false;
    return _anyRemoteSpeaking();
  }

  void _updateRemoteAudioPlayback() {
    try {
      if (remoteStream == null) {
        try {
          _remoteRenderer.srcObject = null;
        } catch (_) {}
        return;
      }
      if (_shouldPlayRemoteAudio()) {
        try {
          _remoteRenderer.srcObject = remoteStream;
          if (kIsWeb && selectedSpeakerId != null) {
            try {
              _remoteRenderer.audioOutput(selectedSpeakerId!);
            } catch (e) {
              _log('Error setting audio output: $e');
            }
          }
        } catch (err) {
          _log('Error setting remoteRenderer.srcObject: $err');
        }
      } else {
        try {
          _remoteRenderer.srcObject = null;
        } catch (_) {}
      }
    } catch (e) {
      _log('Error in _updateRemoteAudioPlayback: $e');
    }
  }

  // ---------------- Cleanup ----------------
  Future<void> closeAll() async {
    _cancelAnswerWatch();
    await signaling.close();
    try {
      await _remoteRenderer.dispose();
    } catch (_) {}
    try {
      await localRenderer.dispose();
    } catch (_) {}
    chat = null;
    localStream = null;
    remoteStream = null;
    callState = CallState.disconnected;
    _muted = false;
    _inCall = false;
    lastOfferBlob = null;
    lastAnswerBlob = null;
    offerId = null;
    participants.clear();
    await clearChatHistory(emitIntro: true);
    notifyListeners();
  }

  Future<void> clearChatHistory({bool emitIntro = true}) async {
    _history.clear();
    unread = 0;
    try {
      await storage.clearMessages();
    } catch (e) {
      _log('clearChatHistory: failed: $e');
    }
    if (emitIntro)
      _pushSystemMessage('Ready',
          type: SystemMessageType.event, severity: EventSeverity.positive);
    notifyListeners();
  }

  // ---------------- Debug helpers ----------------
  Future<void> dumpPcState([String tag = '']) async {
    final pc = signaling.pc;
    _log('dumpPcState $tag: pc is ${pc == null ? 'null' : 'present'}');
    if (pc == null) return;
    try {
      final senders = await pc.getSenders();
      _log('dumpPcState $tag: senders count=${senders.length}');
      for (var s in senders)
        _log(
            ' sender: kind=${s.track?.kind}, id=${s.track?.id}, label=${s.track?.label}');
      final receivers = await pc.getReceivers();
      _log('dumpPcState $tag: receivers count=${receivers.length}');
      for (var r in receivers)
        _log(' receiver: kind=${r.track?.kind}, id=${r.track?.id}');
    } catch (e) {
      _log('dumpPcState $tag: error: $e');
    }
  }

  String _generateId() {
    final p = words.generateWordPairs().take(1).first;
    return '${p.first}-${p.second}';
  }

  bool _isExpired(Timestamp? ts) {
    if (ts == null) return false;
    final created = ts.toDate();
    return DateTime.now().difference(created).inDays >= 7;
  }

  // ---------------- Timer ----------------
  Timer? _callTimer;
  int _callDurationSeconds = 0;
  int get callDurationSeconds => _callDurationSeconds;

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDurationSeconds = 0;
    notifyListeners();
  }

  String get formattedCallDuration {
    if (_callDurationSeconds < 0) _callDurationSeconds = 0;
    int totalSeconds = _callDurationSeconds % 86400;
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    String formatSegment(int segment) => segment.toString().padLeft(2, '0');
    return '${formatSegment(hours)}:${formatSegment(minutes)}:${formatSegment(seconds)}';
  }

  // ---------------- CHAT API ----------------
  Future<void> sendText(String text) async {
    final c = chat ?? signaling.chat;
    if (c == null) {
      final sys = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          author: 'System',
          text: 'Channel unavailible',
          ts: DateTime.now());
      _history.add(sys);
      _incomingCtrl.add(sys);
      return;
    }
    if (c.state != RTCDataChannelState.RTCDataChannelOpen) {
      final comp = Completer<void>();
      void sub(RTCDataChannelState s) {
        if (s == RTCDataChannelState.RTCDataChannelOpen && !comp.isCompleted)
          comp.complete();
      }

      c.onDataChannelState = sub;
      await Future.any(
          [comp.future, Future.delayed(const Duration(seconds: 5))]);
      c.onDataChannelState = null;
    }
    try {
      c.send(RTCDataChannelMessage(text));
      final m = ChatMessage(
          id: const Uuid().v4(), author: 'You', text: text, ts: DateTime.now());
      _history.add(m);
      _incomingCtrl.add(m);
      await storage.appendMessage(m);
    } catch (e) {
      final sys = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          author: 'System',
          text: 'Failed to send message: $e',
          ts: DateTime.now());
      _history.add(sys);
      _incomingCtrl.add(sys);
    }
  }

  void markChatRead() {
    unread = 0;
    notifyListeners();
  }

  Future<void> restoreConnection() async {
    callState = CallState.connected;
  }

  Future<void> _updatePresence(bool inCall) async {
    _log(
        '_updatePresence: forwarding to DC (inCall=$inCall, micOn=${!_muted})');
    await _sendPresenceOverDc(inCall: inCall, micOn: !_muted);
  }

  Future<void> _updateMicState(bool micOn) async {
    _log('_updateMicState: forwarding to DC (micOn=$micOn)');
    await _sendPresenceOverDc(inCall: _inCall, micOn: micOn);
  }

  void _watchCallDoc() {
    _callDocSub?.cancel();
    if (offerId == null) return;
    final docRef = firestore.collection('calls').doc(offerId!);
    _callDocSub = docRef.snapshots().listen((snap) {
      if (!snap.exists) {
        notifyListeners();
        return;
      }
      final data = snap.data();
      if (data == null) return;
      notifyListeners();
    }, onError: (e) {
      _log('_watchCallDoc error: $e');
    });
  }

  // Wait for renegotiation answers by watching collection
  Future<String?> _waitForRenegotiationAnswerDocByCollection(String renegId,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (offerId == null) return null;
    final coll =
        firestore.collection('calls').doc(offerId).collection('renegotiations');
    final completer = Completer<String?>();
    final sub = coll.snapshots().listen((snapshots) {
      for (final doc in snapshots.docs) {
        final d = doc.data();
        if (d['type'] == 'answer' &&
            d['renegId'] == renegId &&
            d['sdp'] != null) {
          if (!completer.isCompleted) completer.complete(d['sdp'] as String);
          break;
        }
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    Future.delayed(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final res = await completer.future;
    await sub.cancel();
    return res;
  }

  // ---------------- Video ----------------
  MediaStream? _localVideoStream;

  Future<bool> _checkCameraPermission() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final status = await Permission.camera.request();
        return status.isGranted;
      } catch (e) {
        _log('Camera permission request failed: $e');
        return false;
      }
    }
    return false;
  }

  Future<void> enableVideo() async {
    if (_localVideoStream != null) return;
    final ok = await _checkCameraPermission();
    if (!ok) throw Exception('Camera permission denied');
    final constraints = <String, dynamic>{
      'audio': false,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480}
    };
    final s = await navigator.mediaDevices.getUserMedia(constraints);
    final tracks = s.getVideoTracks();
    if (tracks.isEmpty) {
      await s.dispose();
      throw Exception('No video tracks');
    }
    _localVideoStream = s;
    try {
      localRenderer.srcObject = _localVideoStream;
    } catch (e) {
      _log('localRenderer set failed: $e');
    }

    final pc = signaling.pc;
    if (pc != null) {
      try {
        final track = tracks.first;
        final senders = await pc.getSenders();
        RTCRtpSender? existed;
        for (final sdr in senders) {
          if (sdr.track != null && sdr.track!.kind == 'video') {
            existed = sdr;
            break;
          }
        }
        if (existed != null) {
          try {
            await existed.replaceTrack(track);
            _log('Replaced existing video sender track');
          } catch (e) {
            _log('replaceTrack video failed: $e — will addTrack');
            await pc.addTrack(track, _localVideoStream!);
            _log('Added video track via addTrack');
            await _requestRenegotiation();
          }
        } else {
          await pc.addTrack(track, _localVideoStream!);
          _log('Added video track via addTrack');
          await _requestRenegotiation();
        }
      } catch (e) {
        _log('enableVideo: adding video track failed: $e');
        try {
          for (final t in _localVideoStream!.getTracks()) t.stop();
          await _localVideoStream!.dispose();
        } catch (_) {}
        _localVideoStream = null;
        rethrow;
      }
    } else {
      _log('enableVideo: pc==null, will attach when pc becomes available');
    }

    notifyListeners();
  }

  Future<void> disableVideo() async {
    if (_localVideoStream == null) return;
    final pc = signaling.pc;
    if (pc != null) {
      try {
        final senders = await pc.getSenders();
        for (final s in senders) {
          if (s.track != null && s.track!.kind == 'video') {
            try {
              await s.replaceTrack(null);
              _log('disableVideo: replaced video sender with null');
            } catch (e) {
              _log('disableVideo replaceTrack failed: $e');
            }
          }
        }
      } catch (e) {
        _log('disableVideo pc operation failed: $e');
      }
    }
    try {
      for (final t in _localVideoStream!.getTracks()) t.stop();
      await _localVideoStream!.dispose();
    } catch (e) {
      _log('disableVideo cleanup failed: $e');
    }
    _localVideoStream = null;
    try {
      localRenderer.srcObject = null;
    } catch (_) {}
    try {
      await _requestRenegotiation();
    } catch (e) {
      _log('disableVideo renegotiation failed: $e');
    }
    notifyListeners();
  }

  // ---------------- Misc helpers ----------------
  List<ParticipantState> get participantsList => participants.values.toList();

  Future<void> dumpAllState() async {
    await dumpPcState('manual');
  }

  // ---------------- Process remote offer (WebSocket flow) ----------------
  Future<void> _handleRemoteOffer(String from, String sdp) async {
    final pc = signaling.pc;
    if (pc == null) {
      await signaling.connectionFallbackInitIfNeeded();
    }
    final pc2 = signaling.pc!;
    pc2.onIceCandidate = (candidate) {
      if (candidate != null) {
        try {
          signaling.sendCandidate(from, candidate);
        } catch (e) {
          _log('sendCandidate error: $e');
        }
      }
    };

    try {
      await signaling
          .safeSetRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      final answer = await pc2.createAnswer({});
      await pc2.setLocalDescription(answer);
      signaling.sendAnswer(from, answer.sdp ?? '');
      _log('Sent answer to $from');
    } catch (e) {
      _log('handleRemoteOffer failed: $e');
    }
  }
}
