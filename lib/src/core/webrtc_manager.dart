import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wave/src/core/signaling.dart';

class WebRTCManager {
  final _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      // Для работы по NAT добавляем TURN:
      // {'urls': 'turn:YOUR_TURN_SERVER:3478', 'username': 'USER', 'credential': 'PASS'},
    ]
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _micEnabled = true;

  // Инициализация рендереров и локального медиа-потока
  Future<void> initLocalMedia() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    // Запрос разрешения камеры/микрофона (необходимо добавить permission handler)
    final mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': 640,
        'height': 480,
      }
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;
  }

  // Создание RTCPeerConnection и установка обработчиков
  Future<void> createPeerConnection() async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_iceServers);

    // Добавляем локальный поток в соединение
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }

    // Обработка удаленного потока
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    // При генерации ICE-кандидата отправляем его другому пиру
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      // Здесь нужно знать, кому отправлять (peerId)
      // Например, можно сохранять текущий активный peerId
      // WebRTCManager может вызывать Signaling.sendCandidate
    };
  }

  // Начать звонок (создать offer)
  Future<void> makeCall(String peerId) async {
    await createPeerConnection();
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    Signaling().callPeer(peerId, offer.sdp!);
  }

  // Обработка полученного предложения (offer)
  Future<void> handleOffer(String peerId, String sdp) async {
    await createPeerConnection();
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    Signaling().sendAnswer(peerId, answer.sdp!);
  }

  // Обработка полученного ответа (answer)
  Future<void> handleAnswer(String sdp) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
  }

  // Обработка полученного ICE-кандидата
  Future<void> handleCandidate(dynamic candidateMap) async {
    if (_peerConnection != null) {
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    }
  }

  // Переключить звук (микрофон)
  void toggleMic() {
    _micEnabled = !_micEnabled;
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = _micEnabled;
      });
    }
  }

  // Завершить звонок
  void hangUp() {
    _peerConnection?.close();
    _peerConnection = null;
    // Очищаем рендереры
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }
}
