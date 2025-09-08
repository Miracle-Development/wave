import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnOffer = void Function(String fromId, String sdp);
typedef OnAnswer = void Function(String fromId, String sdp);
typedef OnCandidate = void Function(String fromId, dynamic candidate);
typedef OnCall = void Function(String fromId);

class Signaling {
  WebSocket? _socket;
  String _selfId = ''; // уникальный идентификатор этого клиента

  OnOffer? onOffer;
  OnAnswer? onAnswer;
  OnCandidate? onCandidate;
  OnCall? onCall;

  // Singleton
  static final Signaling _instance = Signaling._internal();
  factory Signaling() => _instance;
  Signaling._internal();

  // Подключение к сигналинг-серверу WebSocket
  void connect(String url) async {
    _socket = await WebSocket.connect(url);
    _socket!.listen((data) {
      _handleMessage(data);
    }, onError: (e) {
      print('WebSocket error: $e');
    }, onDone: () {
      print('WebSocket closed');
    });
    // После подключения можно установить свой ID (например, имя или GUID)
    _selfId = DateTime.now().millisecondsSinceEpoch.toString();
    _send({'type': 'register', 'id': _selfId});
  }

  // Отправка JSON-сообщения на сервер
  void _send(Map<String, dynamic> msg) {
    if (_socket != null) _socket!.add(json.encode(msg));
  }

  // Инициировать вызов (отправить offer)
  void callPeer(String peerId, String sdp) {
    _send({
      'type': 'offer',
      'from': _selfId,
      'to': peerId,
      'sdp': sdp,
    });
  }

  // Ответ на вызов (answer)
  void sendAnswer(String peerId, String sdp) {
    _send({
      'type': 'answer',
      'from': _selfId,
      'to': peerId,
      'sdp': sdp,
    });
  }

  // Отправить ICE-кандидат
  void sendCandidate(String peerId, RTCIceCandidate candidate) {
    _send({
      'type': 'candidate',
      'from': _selfId,
      'to': peerId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    });
  }

  // Обработка входящих сообщений
  void _handleMessage(dynamic data) {
    var msg = json.decode(data);
    String type = msg['type'];
    String from = msg['from'];
    if (type == 'offer' && onOffer != null) {
      onOffer!(from, msg['sdp']);
    } else if (type == 'answer' && onAnswer != null) {
      onAnswer!(from, msg['sdp']);
    } else if (type == 'candidate' && onCandidate != null) {
      onCandidate!(from, msg['candidate']);
    } else if (type == 'call' && onCall != null) {
      onCall!(from);
    }
  }
}
