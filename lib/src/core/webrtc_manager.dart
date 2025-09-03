import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart' as words;
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/models/chat_message.dart';

import 'signaling.dart';
import 'storage.dart';

/// Управляет подпиской на Firestore и освобождением ресурсов
/// Дает UI простые геттеры: [offerId], [isOfferCreated], [isAnswerAvailable]
class WebRTCManager extends ChangeNotifier {
  final Signaling signaling = Signaling();
  final LocalStorage storage;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  WebRTCManager({required this.storage});

  // ====== PUBLIC STATE (UI) ======
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
  String localName = 'You';

  bool _muted = false;
  bool get muted => _muted;

  // offer/answer blobs (для отображения в UI)
  String? lastOfferBlob;
  String? lastAnswerBlob;

  // текущий сгенерированный offer ID (если создан)
  String? offerId;
  bool get isOfferCreated => offerId != null && offerId!.isNotEmpty;

  // геттер для UI: пришёл ли ответ
  bool get isAnswerAvailable =>
      lastAnswerBlob != null && lastAnswerBlob!.isNotEmpty;

  // подписка на изменения документа ответа Firestore (initiator слушает ответ)
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _answerSub;

  // ====== lifecycle ======
  Future<void> init() async {
    await _remoteRenderer.initialize();
    await signaling.init();
    _wirePc();
    await _refreshDevices();
    chat = signaling.chat;
    if (chat != null) _wireDataChannel(chat!);
  }

  @override
  void dispose() {
    _incomingCtrl.close();
    _cancelAnswerWatch();
    try {
      _remoteRenderer.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _wirePc() {
    final pc = signaling.pc;
    if (pc == null) return;

    pc.onConnectionState = (s) {
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

    pc.onDataChannel = (dc) {
      chat = dc;
      _wireDataChannel(dc);
      notifyListeners();
    };

    pc.onTrack = (e) {
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
      final text =
          m.isBinary ? '[binary ${m.binary?.length ?? 0} bytes]' : m.text;
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
      // noop — можно логировать при необходимости
    };
  }

  Future<void> _refreshDevices() async {
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
      // ignore / log
      print('Failed to enumerate devices: $e');
    }
  }

  // ====== AUDIO helpers ======
  /// Ensure there is a local audio stream attached to the peer connection.
  /// - respects [unmuted] (true = mic enabled)
  Future<void> _ensureLocalAudio({bool unmuted = true}) async {
    if (localStream != null) {
      final tracks = localStream!.getAudioTracks();
      if (tracks.isNotEmpty) tracks.first.enabled = unmuted;
      _muted = !unmuted;
      notifyListeners();
      return;
    }

// Используем сохраненный ID микрофона, если есть
    final constraints = <String, dynamic>{
      'audio': selectedMicId == null ? true : {'deviceId': selectedMicId},
      'video': false
    };

    try {
      final s = await navigator.mediaDevices.getUserMedia(constraints);
      localStream = s;

// Микрофон остается выключенным до явного включения
      final audioTracks = s.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        audioTracks.first.enabled = unmuted;
      }
      _muted = !unmuted;

      await signaling.attachLocal(s);
      notifyListeners();
    } catch (e) {
      // Обработка ошибки (например, показать сообщение пользователю)
      print('Error accessing microphone: $e');
      rethrow;
    }
  }

  /// Cross-platform permission check for microphone
  Future<bool> checkMicrophonePermission() async {
    if (kIsWeb) {
      try {
        final stream =
            await navigator.mediaDevices.getUserMedia({'audio': true});
        stream.getTracks().forEach((track) => track.stop());
        return true;
      } catch (e) {
        print('Microphone access denied (web): $e');
        return false;
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final status = await Permission.microphone.request();
        return status.isGranted;
      } catch (e) {
        print('Microphone permission request failed: $e');
        return false;
      }
    }

    print('Unsupported platform for microphone permission check');
    return false;
  }

  /// Set microphone enabled/disabled (true = enabled)
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (localStream == null) {
      final allowed = await checkMicrophonePermission();
      if (!allowed) return;
      await _ensureLocalAudio(unmuted: enabled);
      return;
    }

    final tracks = localStream!.getAudioTracks();
    if (tracks.isEmpty) return;
    tracks.first.enabled = enabled;
    _muted = !enabled;
    notifyListeners();
  }

  /// Toggle mic mute (keeps API from older code)
  Future<void> toggleMicMute() async {
    final current =
        !_muted; // if _muted == false -> current = true (mic enabled)
    await setMicrophoneEnabled(current == false ? true : false);
  }

  // ====== device helpers ======
  Future<void> updateAudioDevices() async {
    final all = await navigator.mediaDevices.enumerateDevices();
    final microphones =
        all.where((device) => device.kind == 'audioinput').toList();
    if (microphones.isNotEmpty) {
      selectedMicId ??= microphones.first.deviceId;
    }
    await _refreshDevices();
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

  // ====== FIRESTORE signalling ======
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

  DocumentReference<Map<String, dynamic>> _docRef(String id) {
    return firestore.collection(_collection).doc(id);
  }

  void _cancelAnswerWatch() {
    unawaited(_answerSub?.cancel());
    _answerSub = null;
  }

  /// Create offer, publish to Firestore under a free id and start listening for answer.
  /// Saves [lastOfferBlob] and [offerId].
  Future<String> createOfferLink() async {
    // Prepare local channel + audio
    final dc = await signaling.createLocalDataChannel();
    chat = dc;
    _wireDataChannel(dc);

    // ensure local audio and attach to pc (unmuted by default here)
    await _ensureLocalAudio(unmuted: true);

    final offerBlob = await signaling.makeOfferBlob();
    lastOfferBlob = offerBlob;
    notifyListeners();

    // find free id
    var id = _generateId();
    var doc = _docRef(id);

    // try to find free or expired id
    while (true) {
      final snap = await doc.get();
      if (!snap.exists) break;
      final data = snap.data()!;
      final ts = data['createdAt'] as Timestamp?;
      if (_isExpired(ts)) break;
      id = _generateId();
      doc = _docRef(id);
    }

    await doc.set({
      'offer': offerBlob,
      'answer': null,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
    });

    // set local state
    offerId = id;
    _cancelAnswerWatch();

    // listen for answer field changes
    _answerSub = doc.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final ab = data['answer'] as String?;
      if (ab != null && ab.isNotEmpty) {
        lastAnswerBlob = ab;
        notifyListeners();
      }
    }, onError: (e) {
      print('Answer watch error: $e');
    });

    notifyListeners();
    return id;
  }

  /// Answerer: accept offer by id, create answer and save to the same document.
  /// Returns id on success.
  Future<String> acceptOffer(String id) async {
    final ref = _docRef(id);
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

  /// Offerer: pull answer from Firestore and apply it locally.
  Future<void> acceptAnswer(String id) async {
    final ref = _docRef(id);
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
      throw Exception(
          'Ответ для "$id" пока не готов — попросите собеседника нажать "Принять приглашение"');
    }

    lastAnswerBlob = answerBlob;
    notifyListeners();

    await signaling.acceptAnswerBlob(answerBlob);
  }

  /// Stop listening for answer for current offer (if any)
  Future<void> stopWatchingAnswer() async {
    _cancelAnswerWatch();
    notifyListeners();
  }

  // ====== CHAT/API ======
  Future<void> sendText(String text) async {
    final c = chat ?? signaling.chat;
    if (c == null) {
      final sys = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: 'System',
        text: 'Channel unavailible',
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
      await Future.any(
          [comp.future, Future.delayed(const Duration(seconds: 5))]);
      c.onDataChannelState = null;
    }

    try {
      c.send(RTCDataChannelMessage(text));
      final m = ChatMessage(
        id: const Uuid().v4(),
        author: 'You',
        text: text,
        ts: DateTime.now(),
      );
      _history.add(m);
      _incomingCtrl.add(m);
      await storage.appendMessage(m);
    } catch (e) {
      final sys = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: 'System',
        text: 'Failed to send message: $e',
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

  Future<void> toggleMicMuteLegacy(bool isMuted) async {
    // Backward-compatible helper if some UI calls toggleMicrophone(bool).
    await setMicrophoneEnabled(!isMuted);
  }

  Future<void> toggleMicMuteNew() async {
    await toggleMicMute();
  }

  Future<void> toggleMicMuteIfNeeded() async {
    // keep existing API from your code that used toggleMicMute()
    await toggleMicMute();
  }

  // ====== close / cleanup ======
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
    offerId = null;
    notifyListeners();
  }
}

// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:english_words/english_words.dart' as words;
// import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:uuid/uuid.dart';
// import 'package:wave/models/call_state.dart';
// import 'package:wave/models/chat_message.dart';
// import 'dart:io' show Platform;

// import 'signaling.dart';
// import 'storage.dart';

// class WebRTCManager extends ChangeNotifier {
//   final Signaling signaling = Signaling();
//   final LocalStorage storage;
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;

//   WebRTCManager({required this.storage});

//   CallState callState = CallState.disconnected;
//   RTCDataChannel? chat;
//   MediaStream? localStream;
//   MediaStream? remoteStream;

//   final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
//   RTCVideoRenderer get remoteRenderer => _remoteRenderer;

//   List<MediaDeviceInfo> devices = [];
//   String? selectedMicId;
//   String? selectedSpeakerId;

//   final List<ChatMessage> _history = [];
//   List<ChatMessage> get history => List.unmodifiable(_history);

//   final _incomingCtrl = StreamController<ChatMessage>.broadcast();
//   Stream<ChatMessage> get incomingMessages => _incomingCtrl.stream;

//   int unread = 0;
//   final String localId = const Uuid().v4();
//   String localName = 'Вы';
//   bool _muted = false; // unmuted по умолчанию
//   bool get muted => _muted;

//   // Для UI: показываем фактические BLOB-ы (оффер/ответ), чтобы пользователь видел,
//   // что всё подтянулось из Firebase
//   String? lastOfferBlob;
//   String? lastAnswerBlob;

//   // подписка на изменения документа ответа (для инициатора)
//   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _answerSub;

//   bool get isAnswerAvailable => lastAnswerBlob != null && lastAnswerBlob!.isNotEmpty;

//   // ==== lifecycle ====
//   Future<void> init() async {
//     await _remoteRenderer.initialize();
//     await signaling.init();
//     _wirePc();
//     await _refreshDevices();
//     chat = signaling.chat;
//     if (chat != null) _wireDataChannel(chat!);
//   }

//   void _wirePc() {
//     signaling.pc!.onConnectionState = (s) {
//       switch (s) {
//         case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
//           callState = CallState.connected;
//           break;
//         case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
//           callState = CallState.failed;
//           break;
//         case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
//         case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
//           callState = CallState.disconnected;
//           break;
//         default:
//           callState = CallState.connecting;
//       }
//       notifyListeners();
//     };

//     signaling.pc!.onDataChannel = (dc) {
//       chat = dc;
//       _wireDataChannel(dc);
//       notifyListeners();
//     };

//     signaling.pc!.onTrack = (e) {
//       if (e.streams.isNotEmpty) {
//         remoteStream = e.streams.first;
//         try {
//           _remoteRenderer.srcObject = remoteStream;
//           if (kIsWeb && selectedSpeakerId != null) {
//             _remoteRenderer.audioOutput(selectedSpeakerId!);
//           }
//         } catch (_) {}
//         notifyListeners();
//       }
//     };
//   }

//   void _wireDataChannel(RTCDataChannel dc) {
//     dc.onMessage = (m) {
//       final text =
//           m.isBinary ? '[binary ${m.binary?.length ?? 0} bytes]' : m.text;
//       final msg = ChatMessage(
//         id: DateTime.now().microsecondsSinceEpoch.toString(),
//         author: 'Собеседник',
//         text: text,
//         ts: DateTime.now(),
//       );
//       _history.add(msg);
//       _incomingCtrl.add(msg);
//       unawaited(storage.appendMessage(msg));
//       unread++;
//       notifyListeners();
//     };

//     dc.onDataChannelState = (s) {
//       // noop
//     };
//   }

//   Future<void> _refreshDevices() async {
//     final all = await navigator.mediaDevices.enumerateDevices();
//     final seen = <String>{};
//     devices = [];
//     for (final d in all) {
//       final id = d.deviceId ?? '';
//       if (id.isEmpty || seen.contains(id)) continue;
//       seen.add(id);
//       devices.add(d);
//     }
//     notifyListeners();
//   }

//   // ====== AUDIO helpers ======
//   // Future<void> _ensureLocalAudio({bool unmuted = true}) async {
//   //   if (localStream != null) {
//   //     final tracks = localStream!.getAudioTracks();
//   //     if (tracks.isNotEmpty) tracks.first.enabled = unmuted;
//   //     _muted = !unmuted;
//   //     notifyListeners();
//   //     return;
//   //   }
//   //   final constraints = <String, dynamic>{
//   //     'audio': selectedMicId == null ? true : {'deviceId': selectedMicId},
//   //     'video': false
//   //   };
//   //   final s = await navigator.mediaDevices.getUserMedia(constraints);
//   //   localStream = s;
//   //   _muted = !unmuted;
//   //   // КРИТИЧНО: добавить трек ДО создания оффера/ответа
//   //   await signaling.attachLocal(s);
//   //   notifyListeners();
//   // }

//   Future<void> _ensureLocalAudio({bool unmuted = true}) async {
//     if (localStream != null) {
//       final tracks = localStream!.getAudioTracks();
//       if (tracks.isNotEmpty) tracks.first.enabled = unmuted;
//       _muted = !unmuted;
//       notifyListeners();
//       return;
//     }

//     // Используем сохраненный ID микрофона, если есть
//     final constraints = <String, dynamic>{
//       'audio': selectedMicId == null ? true : {'deviceId': selectedMicId},
//       'video': false
//     };

//     try {
//       final s = await navigator.mediaDevices.getUserMedia(constraints);
//       localStream = s;

//       // Микрофон остается выключенным до явного включения
//       final audioTracks = s.getAudioTracks();
//       if (audioTracks.isNotEmpty) {
//         audioTracks.first.enabled = false; // По умолчанию выключен
//       }

//       _muted = true; // Соответствует выключенному состоянию
//       await signaling.attachLocal(s);
//       notifyListeners();
//     } catch (e) {
//       print('Error accessing microphone: $e');
//       // Обработка ошибки (например, показать сообщение пользователю)
//     }
//   }

// // отдельный метод для запроса разрешения на микрофон
//   // Future<bool> _requestMicrophoneAccess() async {
//   //   try {
//   //     // Запрос доступа к микрофону
//   //     final constraints = {'audio': true, 'video': false};
//   //     final stream = await navigator.mediaDevices.getUserMedia(constraints);

//   //     // Немедленно отключаем аудиотрек (микрофон не активен)
//   //     final audioTracks = stream.getAudioTracks();
//   //     if (audioTracks.isNotEmpty) {
//   //       audioTracks.first.enabled = false;
//   //     }

//   //     // Освобождаем поток (доступ получен, но не используем)
//   //     audioTracks.forEach((track) => track.stop());
//   //     stream.dispose();

//   //     // Обновляем список устройств
//   //     await updateAudioDevices();

//   //     return true;
//   //   } catch (e) {
//   //     print('Microphone access denied: $e');
//   //     return false;
//   //   }
//   // }

//   // метод для запроса разрешения (мультиплатформенный)
//   Future<bool> checkMicrophonePermission() async {
//     // На Web используем стандартный API
//     if (kIsWeb) {
//       try {
//         final stream =
//             await navigator.mediaDevices.getUserMedia({'audio': true});
//         stream.getTracks().forEach((track) => track.stop());
//         return true;
//       } catch (e) {
//         print('Microphone access denied: $e');
//         return false;
//       }
//     }
//     if (Platform.isAndroid || Platform.isIOS) {
//       try {
//         // На мобильных используем permission_handler
//         final status = await Permission.microphone.request();
//         return status.isGranted;
//       } catch (e) {
//         print('Microphone access denied: $e');
//         return false;
//       }
//     }
//     print('Unsupported device');
//     return false;
//   }

// // метод для обновления аудиоустройств
//   Future<void> updateAudioDevices() async {
//     final devices = await navigator.mediaDevices.enumerateDevices();
//     final microphones = devices.where((device) => device.kind == 'audioinput');

//     // Обновляем состояние приложения с новым списком микрофонов
//     // Например: availableMics = microphones.toList();
//     microphones.toList();
//     selectedMicId = microphones.first.deviceId; // или сохраненный выбор
//     notifyListeners();
//   }

// // кастомный метод для включения микрофона
//   void toggleMicrophone(bool isMuted) async {
//     if (localStream == null) {
//       // Сначала запрашиваем доступ если нужно
//       final hasAccess =
//           await checkMicrophonePermission(); // TODO проверить корректность замены закомменченного метода
//       if (!hasAccess) return;

//       // Создаем поток для использования
//       await _ensureLocalAudio(unmuted: false);
//     }

//     final tracks = localStream!.getAudioTracks();
//     if (tracks.isNotEmpty) {
//       tracks.first.enabled = isMuted;
//       _muted = isMuted;
//       notifyListeners();
//     }
//   }

//   // ====== Firebase signaling (random wordpair ID) ======
//   static const _collection = 'calls';
//   static const _ttlDays = 7;

//   String _generateId() {
//     final p = words.generateWordPairs().take(1).first;
//     return '${p.first}-${p.second}';
//   }

//   bool _isExpired(Timestamp? ts) {
//     if (ts == null) return false;
//     final created = ts.toDate();
//     return DateTime.now().difference(created).inDays >= _ttlDays;
//   }

//   void _cancelAnswerWatch() {
//     unawaited(_answerSub?.cancel());
//     _answerSub = null;
//   }

//   /// Offerer: создаёт datachannel, поднимает локальный звук (unmuted),
//   /// публикует оффер в Firestore под свободным/просроченным ID и возвращает ID (например, `coala-frog`).
//   /// Также сохраняет локальный оффер-BLOB для отображения в UI и начинает слушать появление answer.
//   Future<String> createOfferLink() async {
//     final dc = await signaling.createLocalDataChannel();
//     chat = dc;
//     _wireDataChannel(dc);
//     await _ensureLocalAudio(unmuted: true);

//     final offerBlob = await signaling.makeOfferBlob();
//     lastOfferBlob = offerBlob;
//     notifyListeners();

//     // ищем свободный/просроченный id
//     String id = _generateId();
//     var doc = firestore.collection(_collection).doc(id);

//     while (true) {
//       final snap = await doc.get();
//       if (!snap.exists) break;
//       final data = snap.data()!;
//       final ts = data['createdAt'] as Timestamp?;
//       if (_isExpired(ts)) break; // можно переиспользовать
//       id = _generateId();
//       doc = firestore.collection(_collection).doc(id);
//     }

//     await doc.set({
//       'offer': offerBlob,
//       'answer': null,
//       'createdAt': FieldValue.serverTimestamp(),
//       'answeredAt': null,
//     });

//     // Автопрослушка появления answer — чтобы показать его в UI инициатору
//     _cancelAnswerWatch();
//     _answerSub = doc.snapshots().listen((snap) {
//       final data = snap.data();
//       if (data == null) return;
//       final ab = data['answer'] as String?;
//       if (ab != null && ab.isNotEmpty) {
//         lastAnswerBlob = ab;
//         notifyListeners();
//       }
//     });

//     return id;
//   }

//   /// Answerer: принимает оффер по ID, генерирует answer и сохраняет его в том же документе.
//   /// Если ID протух — бросаем исключение. Также сохраняем answer-BLOB в `lastAnswerBlob` для UI.
//   Future<String> acceptOffer(String id) async {
//     final ref = firestore.collection(_collection).doc(id);
//     final snap = await ref.get();
//     if (!snap.exists) {
//       throw Exception('Приглашение с ID "$id" не найдено');
//     }
//     final data = snap.data()!;
//     final createdAt = data['createdAt'] as Timestamp?;
//     if (_isExpired(createdAt)) {
//       throw Exception('ID "$id" протух (старше $_ttlDays дней)');
//     }
//     final offerBlob = data['offer'] as String?;
//     if (offerBlob == null || offerBlob.isEmpty) {
//       throw Exception('В документе "$id" отсутствует поле offer');
//     }

//     await _ensureLocalAudio(unmuted: true);
//     await signaling.acceptOfferBlob(offerBlob);

//     final answerBlob = await signaling.getAnswerBlob();
//     await ref.update({
//       'answer': answerBlob,
//       'answeredAt': FieldValue.serverTimestamp(),
//     });

//     lastAnswerBlob = answerBlob;
//     notifyListeners();

//     return id;
//   }

//   /// Offerer: подтягивает answer из Firestore и применяет его.
//   /// Если answer отсутствует — бросаем исключение с понятным текстом.
//   Future<void> acceptAnswer(String id) async {
//     final ref = firestore.collection(_collection).doc(id);
//     final snap = await ref.get();
//     if (!snap.exists) {
//       throw Exception('Документ "$id" не найден');
//     }
//     final data = snap.data()!;
//     final createdAt = data['createdAt'] as Timestamp?;
//     if (_isExpired(createdAt)) {
//       throw Exception('ID "$id" протух (старше $_ttlDays дней)');
//     }
//     final answerBlob = data['answer'] as String?;
//     if (answerBlob == null || answerBlob.isEmpty) {
//       throw Exception(
//           'Ответ для "$id" пока не готов — попросите собеседника нажать "Принять приглашение"');
//     }
//     // сохраним и для UI (на всякий)
//     lastAnswerBlob = answerBlob;
//     notifyListeners();

//     await signaling.acceptAnswerBlob(answerBlob);
//   }

//   // ===== CHAT/API (сохранено как просил) =====
//   Future<void> sendText(String text) async {
//     final c = chat ?? signaling.chat;
//     if (c == null) {
//       final sys = ChatMessage(
//         id: DateTime.now().microsecondsSinceEpoch.toString(),
//         author: 'Система',
//         text: 'Канал недоступен',
//         ts: DateTime.now(),
//       );
//       _history.add(sys);
//       _incomingCtrl.add(sys);
//       return;
//     }

//     if (c.state != RTCDataChannelState.RTCDataChannelOpen) {
//       final comp = Completer<void>();
//       void sub(RTCDataChannelState s) {
//         if (s == RTCDataChannelState.RTCDataChannelOpen && !comp.isCompleted) {
//           comp.complete();
//         }
//       }

//       c.onDataChannelState = sub;
//       await Future.any(
//           [comp.future, Future.delayed(const Duration(seconds: 5))]);
//       c.onDataChannelState = null;
//     }

//     try {
//       c.send(RTCDataChannelMessage(text));
//       final m = ChatMessage(
//         id: const Uuid().v4(),
//         author: 'Вы',
//         text: text,
//         ts: DateTime.now(),
//       );
//       _history.add(m);
//       _incomingCtrl.add(m);
//       await storage.appendMessage(m);
//     } catch (e) {
//       final sys = ChatMessage(
//         id: DateTime.now().microsecondsSinceEpoch.toString(),
//         author: 'Система',
//         text: 'Не удалось отправить сообщение: $e',
//         ts: DateTime.now(),
//       );
//       _history.add(sys);
//       _incomingCtrl.add(sys);
//     }
//   }

//   void markChatRead() {
//     unread = 0;
//     notifyListeners();
//   }

//   Future<void> toggleMicMute() async {
//     if (localStream == null) {
//       await _ensureLocalAudio(unmuted: true);
//       return;
//     }
//     final tracks = localStream!.getAudioTracks();
//     if (tracks.isEmpty) return;
//     final t = tracks.first;
//     t.enabled = !t.enabled;
//     _muted = !t.enabled;
//     notifyListeners();
//   }

//   Future<void> selectMic(String? id) async {
//     selectedMicId = id;
//     if (localStream != null) {
//       await localStream?.dispose();
//       localStream = null;
//       await _ensureLocalAudio(unmuted: !_muted);
//     }
//     await _refreshDevices();
//   }

//   Future<void> selectSpeaker(String? id) async {
//     selectedSpeakerId = id;
//     if (kIsWeb && id != null) {
//       try {
//         await _remoteRenderer.audioOutput(id);
//       } catch (_) {}
//     }
//     notifyListeners();
//   }

//   // ===== close =====
//   Future<void> closeAll() async {
//     _cancelAnswerWatch();
//     await signaling.closeAll();
//     try {
//       await _remoteRenderer.dispose();
//     } catch (_) {}
//     chat = null;
//     localStream = null;
//     remoteStream = null;
//     callState = CallState.disconnected;
//     _muted = false;
//     lastOfferBlob = null;
//     lastAnswerBlob = null;
//     notifyListeners();
//   }
// }
