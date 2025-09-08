// signaling.dart (исправленный)
//
// Основные изменения:
// - attachLocal: не добавляет уже существующие треки (предотвращает дублирование senders).
// - detachLocal: использует sender.replaceTrack(null) вместо removeTrack, затем dispose локального stream.
// - acceptAnswerBlob: делает "safe setRemoteDescription" с retry и rollback попыткой при ошибке "wrong state".
// - Доп. логирование signalingState, senders/receivers для отладки.

import 'dart:async';
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
      debugPrint('ICE candidate: ${c.candidate}');
    };

    pc!.onIceGatheringState = (s) => debugPrint('ICE: $s');
    pc!.onConnectionState = (s) => debugPrint('PC: $s');

    pc!.onDataChannel = (dc) {
      debugPrint('onDataChannel: ${dc.label}');
      chat = dc;
    };

    pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        remoteStream = e.streams.first;
        debugPrint(
            'onTrack: got remote stream id=${remoteStream?.id}, audioTracks=${remoteStream?.getAudioTracks().map((t) => t.id).toList()}');
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

  /// Attach local stream to pc — безопасно: не добавляем треки, которые уже были добавлены ранее.
  Future<void> attachLocal(MediaStream stream) async {
    if (pc == null) {
      localStream = stream;
      debugPrint('attachLocal: pc == null => localStream saved only');
      return;
    }

    localStream = stream;

    try {
      // Сначала соберём set существующих senders'ов (track ids)
      final senders = await pc!.getSenders();
      final existingTrackIds = <String>{};
      for (final s in senders) {
        if (s.track != null && s.track!.id != null)
          existingTrackIds.add(s.track!.id!);
      }

      // Добавляем только те треки, которых нет среди sender'ов
      for (final t in stream.getTracks()) {
        if (t.kind == 'audio' || t.kind == 'video') {
          if (t.id != null && existingTrackIds.contains(t.id)) {
            debugPrint('attachLocal: track ${t.id} already added — skipping');
            continue;
          }
          try {
            await pc!.addTrack(t, stream);
            debugPrint('attachLocal: addTrack ${t.id} (${t.kind}) succeeded');
          } catch (e) {
            debugPrint('attachLocal: addTrack ${t.id} (${t.kind}) failed: $e');
            // не рвём выполнение — может быть вызвано уже установленным sender'ом
          }
        }
      }

      // debug dump
      final s2 = await pc!.getSenders();
      debugPrint('attachLocal: senders count=${s2.length}');
      for (var s in s2) {
        debugPrint(
            ' sender: kind=${s.track?.kind}, id=${s.track?.id}, label=${s.track?.label}');
      }
    } catch (e) {
      debugPrint('attachLocal: error: $e');
    }
  }

  /// Detach local stream: заменяем track->null для sender'ов (чтобы перестать слать),
  /// затем останавливаем и dispose локального stream.
  Future<void> detachLocal() async {
    if (pc != null) {
      try {
        final senders = await pc!.getSenders();
        for (final s in senders) {
          // заменяем только те sender'ы, которые отправляют наш локальный stream tracks
          try {
            if (s.track != null &&
                (s.track!.kind == 'audio' || s.track!.kind == 'video')) {
              // Try replaceTrack(null) — самая надёжная операция для прекращения отправки
              await s.replaceTrack(null);
              debugPrint(
                  'detachLocal: replaced sender ${s.track?.id} with null');
            }
          } catch (e) {
            debugPrint('detachLocal: replaceTrack(null) failed for sender: $e');
            // fallback: попробуем pc.removeTrack (если реализовано)
            try {
              await pc!.removeTrack(s);
              debugPrint('detachLocal: removeTrack fallback succeeded');
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('detachLocal: error while operating on senders: $e');
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
      debugPrint('detachLocal: error disposing localStream: $e');
    }

    localStream = null;
  }

  /// Создаёт локальный оффер и возвращает BLOB (JSON) c SDP.
  Future<String> makeOfferBlob() async {
    if (pc == null) throw Exception('PC not initialized');
    final offer = await pc!.createOffer({'offerToReceiveAudio': true});
    debugPrint(
        'makeOfferBlob: created offer, setting local desc, signalingState=${pc!.signalingState}');
    await pc!.setLocalDescription(offer);
    await _waitIceComplete();
    final sd = await pc!.getLocalDescription();
    final blob = jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
    debugPrint('makeOfferBlob: done. signalingState=${pc!.signalingState}');
    return blob;
  }

  /// Применяет BLOB оффера, создаёт answer и устанавливает локально
  Future<void> acceptOfferBlob(String blob) async {
    if (pc == null) throw Exception('PC not initialized');
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final desc = RTCSessionDescription(map['sdp'], map['type']);
    debugPrint(
        'acceptOfferBlob: applying remote offer, signalingState=${pc!.signalingState}');
    await _safeSetRemoteDescription(desc);
    final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
    await pc!.setLocalDescription(answer);
    await _waitIceComplete();
    debugPrint(
        'acceptOfferBlob: answer created and setLocal, signalingState=${pc!.signalingState}');
  }

  /// Возвращает BLOB ответа
  Future<String> getAnswerBlob() async {
    final sd = await pc!.getLocalDescription();
    return jsonEncode({'type': sd!.type, 'sdp': sd.sdp});
  }

  /// Применяет BLOB ответа — безопасно (retry + rollback на случай wrong state)
  Future<void> acceptAnswerBlob(String blob) async {
    if (pc == null) throw Exception('PC not initialized');
    final map = jsonDecode(blob) as Map<String, dynamic>;
    final desc = RTCSessionDescription(map['sdp'], map['type']);
    debugPrint(
        'acceptAnswerBlob: attempting to apply answer, signalingState=${pc!.signalingState}');
    // Try safe setRemoteDescription with retries/rollback
    await _safeSetRemoteDescription(desc);
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
    while (pc!.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  /// Безопасный setRemoteDescription:
  /// - пытается применить remote description;
  /// - при ошибке "Called in wrong state: stable" делает попытку rollback и повторяет;
  /// - логирует signaling state и возвращает ошибку если не получилось.
  Future<void> _safeSetRemoteDescription(RTCSessionDescription desc) async {
    if (pc == null) throw Exception('PC not initialized');
    try {
      debugPrint(
          '_safeSetRemoteDescription: before setRemote, signalingState=${pc!.signalingState}');
      await pc!.setRemoteDescription(desc);
      debugPrint(
          '_safeSetRemoteDescription: setRemote succeeded, signalingState=${pc!.signalingState}');
      return;
    } catch (e) {
      final err = e.toString();
      debugPrint('_safeSetRemoteDescription: initial setRemote failed: $err');
      // Если ошибка связана с "wrong state", попробуем rollback и повтор
      if (err.contains('Called in wrong state') ||
          err.contains('InvalidStateError')) {
        try {
          debugPrint(
              '_safeSetRemoteDescription: attempting rollback to recover');
          // rollback: setLocalDescription({type:'rollback'}) — браузеры обычно поддерживают
          await pc!.setLocalDescription(RTCSessionDescription('', 'rollback'));
          await Future.delayed(const Duration(milliseconds: 150));
          debugPrint(
              '_safeSetRemoteDescription: retrying setRemote after rollback');
          await pc!.setRemoteDescription(desc);
          debugPrint(
              '_safeSetRemoteDescription: setRemote succeeded after rollback, signalingState=${pc!.signalingState}');
          return;
        } catch (e2) {
          debugPrint(
              '_safeSetRemoteDescription: retry after rollback failed: $e2');
          // как последний шанс — логируем и пробуем отложить (не бросаем), вызывающий код должен обработать.
          rethrow;
        }
      } else {
        // другая ошибка — пробуем ещё раз (краткая задержка)
        try {
          await Future.delayed(const Duration(milliseconds: 120));
          debugPrint('_safeSetRemoteDescription: retrying setRemote once more');
          await pc!.setRemoteDescription(desc);
          debugPrint(
              '_safeSetRemoteDescription: retry succeeded, signalingState=${pc!.signalingState}');
          return;
        } catch (e3) {
          debugPrint('_safeSetRemoteDescription: retry also failed: $e3');
          rethrow;
        }
      }
    }
  }
}
