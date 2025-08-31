import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class Signaling {
  RTCPeerConnection? pc;
  RTCDataChannel? chat;

  MediaStream? localStream;
  MediaStream? remoteStream;

  final Map<String, dynamic> config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> init() async {
    pc = await createPeerConnection(config);

    pc!.onIceCandidate = (c) {
      // non-trickle: просто логируем, ждём complete
      debugPrint('ICE candidate: ${c.candidate}');
    };

    pc!.onIceGatheringState = (s) => debugPrint('ICE: $s');
    pc!.onConnectionState = (s) => debugPrint('PC: $s');

    pc!.onDataChannel = (dc) {
      chat = dc;
    };

    pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        remoteStream = e.streams.first;
      }
    };
  }

  Future<RTCDataChannel> createLocalDataChannel() async {
    if (pc == null) throw Exception('PC not initialized');
    final dc = await pc!.createDataChannel(
      'chat',
      RTCDataChannelInit()..ordered = true,
    );
    chat = dc;
    return dc;
  }

  Future<void> attachLocal(MediaStream stream) async {
    localStream = stream;
    for (final t in stream.getTracks()) {
      await pc!.addTrack(t, stream);
    }
  }

  Future<void> detachLocal() async {
    try {
      final senders = await pc!.getSenders();
      for (final s in senders) {
        if (s.track?.kind == 'audio') {
          try {
            await pc!.removeTrack(s);
          } catch (_) {}
        }
      }
    } catch (_) {}
    try {
      await localStream?.dispose();
    } catch (_) {}
    localStream = null;
  }

  /// Создаёт локальный оффер и возвращает **BLOB** (JSON) c SDP (без префикса webrtc://)
  Future<String> makeOfferBlob() async {
    final offer = await pc!.createOffer({'offerToReceiveAudio': true});
    await pc!.setLocalDescription(offer);
    await _waitIceComplete();
    final sd = await pc!.getLocalDescription();
    final blob = jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
    return blob;
  }

  /// Применяет **BLOB** оффера (JSON), создаёт answer и устанавливает локально
  Future<void> acceptOfferBlob(String blob) async {
    final map = jsonDecode(blob) as Map<String, dynamic>;
    await pc!.setRemoteDescription(
      RTCSessionDescription(map['sdp'], map['type']),
    );
    final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
    await pc!.setLocalDescription(answer);
    await _waitIceComplete();
  }

  /// Возвращает **BLOB** (JSON) ответа
  Future<String> getAnswerBlob() async {
    final sd = await pc!.getLocalDescription();
    return jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
  }

  /// Применяет **BLOB** (JSON) ответа
  Future<void> acceptAnswerBlob(String blob) async {
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final st = pc!.signalingState;
    if (st == RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
        st == RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer) {
      await pc!.setRemoteDescription(
        RTCSessionDescription(map['sdp'], map['type']),
      );
    } else {
      debugPrint('acceptAnswerBlob: wrong signalingState=$st — skip');
    }
  }

  Future<void> closeAll() async {
    try {
      await chat?.close();
    } catch (_) {}
    try {
      await pc?.close();
    } catch (_) {}
    pc = null;
    chat = null;
    localStream = null;
    remoteStream = null;
  }

  Future<void> _waitIceComplete() async {
    // ждём non-trickle ICE complete
    while (pc!.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }
}
