import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart' as words;
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../models/call_state.dart';
import '../../models/chat_message.dart';
import 'signaling.dart';
import 'storage.dart';

class WebRTCManager extends ChangeNotifier {
  final Signaling signaling = Signaling();
  final LocalStorage storage;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  WebRTCManager({required this.storage});

  CallState callState = CallState.disconnected;
  RTCDataChannel? chat;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  List<MediaDeviceInfo> devices = [];
  String? selectedMicId;
  String? selectedSpeakerId;

  final List<ChatMessage> _history = [];
  List<ChatMessage> get history => List.unmodifiable(_history);

  final _incomingCtrl = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingMessages => _incomingCtrl.stream;

  int unread = 0;
  final String localId = const Uuid().v4();
  String localName = 'Вы';
  bool _muted = false; // unmuted по умолчанию
  bool get muted => _muted;

  // Для UI: показываем фактические BLOB-ы (оффер/ответ), чтобы пользователь видел,
  // что всё подтянулось из Firebase
  String? lastOfferBlob;
  String? lastAnswerBlob;

  // подписка на изменения документа ответа (для инициатора)
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _answerSub;

  // ==== lifecycle ====
  Future<void> init() async {
    await _remoteRenderer.initialize();
    await signaling.init();
    _wirePc();
    await _refreshDevices();
    chat = signaling.chat;
    if (chat != null) _wireDataChannel(chat!);
  }

  void _wirePc() {
    signaling.pc!.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          callState = CallState.connected;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          callState = CallState.failed;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          callState = CallState.disconnected;
          break;
        default:
          callState = CallState.connecting;
      }
      notifyListeners();
    };

    signaling.pc!.onDataChannel = (dc) {
      chat = dc;
      _wireDataChannel(dc);
      notifyListeners();
    };

    signaling.pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        remoteStream = e.streams.first;
        try {
          _remoteRenderer.srcObject = remoteStream;
          if (kIsWeb && selectedSpeakerId != null) {
            _remoteRenderer.audioOutput(selectedSpeakerId!);
          }
        } catch (_) {}
        notifyListeners();
      }
    };
  }

  void _wireDataChannel(RTCDataChannel dc) {
    dc.onMessage = (m) {
      final text = m.isBinary ? '[binary ${m.binary?.length ?? 0} bytes]' : m.text;
      final msg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: 'Собеседник',
        text: text,
        ts: DateTime.now(),
      );
      _history.add(msg);
      _incomingCtrl.add(msg);
      unawaited(storage.appendMessage(msg));
      unread++;
      notifyListeners();
    };

    dc.onDataChannelState = (s) {
      // noop
    };
  }

  Future<void> _refreshDevices() async {
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
  }

  // ====== AUDIO helpers ======
  Future<void> _ensureLocalAudio({bool unmuted = true}) async {
    if (localStream != null) {
      final tracks = localStream!.getAudioTracks();
      if (tracks.isNotEmpty) tracks.first.enabled = unmuted;
      _muted = !unmuted;
      notifyListeners();
      return;
    }
    final constraints = <String, dynamic>{
      'audio': selectedMicId == null ? true : {'deviceId': selectedMicId},
      'video': false
    };
    final s = await navigator.mediaDevices.getUserMedia(constraints);
    localStream = s;
    _muted = !unmuted;
    // КРИТИЧНО: добавить трек ДО создания оффера/ответа
    await signaling.attachLocal(s);
    notifyListeners();
  }

  // ====== Firebase signaling (random wordpair ID) ======
  static const _collection = 'calls';
  static const _ttlDays = 7;

  String _generateId() {
    final p = words.generateWordPairs().take(1).first;
    return '${p.first}-${p.second}';
  }

  bool _isExpired(Timestamp? ts) {
    if (ts == null) return false;
    final created = ts.toDate();
    return DateTime.now().difference(created).inDays >= _ttlDays;
  }

  void _cancelAnswerWatch() {
    unawaited(_answerSub?.cancel());
    _answerSub = null;
  }

  /// Offerer: создаёт datachannel, поднимает локальный звук (unmuted),
  /// публикует оффер в Firestore под свободным/просроченным ID и возвращает ID (например, `coala-frog`).
  /// Также сохраняет локальный оффер-BLOB для отображения в UI и начинает слушать появление answer.
  Future<String> createOfferLink() async {
    final dc = await signaling.createLocalDataChannel();
    chat = dc;
    _wireDataChannel(dc);
    await _ensureLocalAudio(unmuted: true);

    final offerBlob = await signaling.makeOfferBlob();
    lastOfferBlob = offerBlob;
    notifyListeners();

    // ищем свободный/просроченный id
    String id = _generateId();
    var doc = firestore.collection(_collection).doc(id);

    while (true) {
      final snap = await doc.get();
      if (!snap.exists) break;
      final data = snap.data()!;
      final ts = data['createdAt'] as Timestamp?;
      if (_isExpired(ts)) break; // можно переиспользовать
      id = _generateId();
      doc = firestore.collection(_collection).doc(id);
    }

    await doc.set({
      'offer': offerBlob,
      'answer': null,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
    });

    // Автопрослушка появления answer — чтобы показать его в UI инициатору
    _cancelAnswerWatch();
    _answerSub = doc.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final ab = data['answer'] as String?;
      if (ab != null && ab.isNotEmpty) {
        lastAnswerBlob = ab;
        notifyListeners();
      }
    });

    return id;
  }

  /// Answerer: принимает оффер по ID, генерирует answer и сохраняет его в том же документе.
  /// Если ID протух — бросаем исключение. Также сохраняем answer-BLOB в `lastAnswerBlob` для UI.
  Future<String> acceptOffer(String id) async {
    final ref = firestore.collection(_collection).doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Приглашение с ID "$id" не найдено');
    }
    final data = snap.data()!;
    final createdAt = data['createdAt'] as Timestamp?;
    if (_isExpired(createdAt)) {
      throw Exception('ID "$id" протух (старше $_ttlDays дней)');
    }
    final offerBlob = data['offer'] as String?;
    if (offerBlob == null || offerBlob.isEmpty) {
      throw Exception('В документе "$id" отсутствует поле offer');
    }

    await _ensureLocalAudio(unmuted: true);
    await signaling.acceptOfferBlob(offerBlob);

    final answerBlob = await signaling.getAnswerBlob();
    await ref.update({
      'answer': answerBlob,
      'answeredAt': FieldValue.serverTimestamp(),
    });

    lastAnswerBlob = answerBlob;
    notifyListeners();

    return id;
  }

  /// Offerer: подтягивает answer из Firestore и применяет его.
  /// Если answer отсутствует — бросаем исключение с понятным текстом.
  Future<void> acceptAnswer(String id) async {
    final ref = firestore.collection(_collection).doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Документ "$id" не найден');
    }
    final data = snap.data()!;
    final createdAt = data['createdAt'] as Timestamp?;
    if (_isExpired(createdAt)) {
      throw Exception('ID "$id" протух (старше $_ttlDays дней)');
    }
    final answerBlob = data['answer'] as String?;
    if (answerBlob == null || answerBlob.isEmpty) {
      throw Exception('Ответ для "$id" пока не готов — попросите собеседника нажать "Принять приглашение"');
    }
    // сохраним и для UI (на всякий)
    lastAnswerBlob = answerBlob;
    notifyListeners();

    await signaling.acceptAnswerBlob(answerBlob);
  }

  // ===== CHAT/API (сохранено как просил) =====
  Future<void> sendText(String text) async {
    final c = chat ?? signaling.chat;
    if (c == null) {
      final sys = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: 'Система',
        text: 'Канал недоступен',
        ts: DateTime.now(),
      );
      _history.add(sys);
      _incomingCtrl.add(sys);
      return;
    }

    if (c.state != RTCDataChannelState.RTCDataChannelOpen) {
      final comp = Completer<void>();
      void sub(RTCDataChannelState s) {
        if (s == RTCDataChannelState.RTCDataChannelOpen && !comp.isCompleted) {
          comp.complete();
        }
      }
      c.onDataChannelState = sub;
      await Future.any([comp.future, Future.delayed(const Duration(seconds: 5))]);
      c.onDataChannelState = null;
    }

    try {
      c.send(RTCDataChannelMessage(text));
      final m = ChatMessage(
        id: const Uuid().v4(),
        author: 'Вы',
        text: text,
        ts: DateTime.now(),
      );
      _history.add(m);
      _incomingCtrl.add(m);
      await storage.appendMessage(m);
    } catch (e) {
      final sys = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: 'Система',
        text: 'Не удалось отправить сообщение: $e',
        ts: DateTime.now(),
      );
      _history.add(sys);
      _incomingCtrl.add(sys);
    }
  }

  void markChatRead() {
    unread = 0;
    notifyListeners();
  }

  Future<void> toggleMicMute() async {
    if (localStream == null) {
      await _ensureLocalAudio(unmuted: true);
      return;
    }
    final tracks = localStream!.getAudioTracks();
    if (tracks.isEmpty) return;
    final t = tracks.first;
    t.enabled = !t.enabled;
    _muted = !t.enabled;
    notifyListeners();
  }

  Future<void> selectMic(String? id) async {
    selectedMicId = id;
    if (localStream != null) {
      await localStream?.dispose();
      localStream = null;
      await _ensureLocalAudio(unmuted: !_muted);
    }
    await _refreshDevices();
  }

  Future<void> selectSpeaker(String? id) async {
    selectedSpeakerId = id;
    if (kIsWeb && id != null) {
      try {
        await _remoteRenderer.audioOutput(id);
      } catch (_) {}
    }
    notifyListeners();
  }

  // ===== close =====
  Future<void> closeAll() async {
    _cancelAnswerWatch();
    await signaling.closeAll();
    try {
      await _remoteRenderer.dispose();
    } catch (_) {}
    chat = null;
    localStream = null;
    remoteStream = null;
    callState = CallState.disconnected;
    _muted = false;
    lastOfferBlob = null;
    lastAnswerBlob = null;
    notifyListeners();
  }
}
