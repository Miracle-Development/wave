import 'package:callkeep/callkeep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class CallScreen extends StatefulWidget {
  final String peerId;
  const CallScreen({super.key, required this.peerId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCManager _webrtc = WebRTCManager();
  bool _micEnabled = true;

  @override
  void initState() {
    super.initState();
    // Инициализируем медиапотоки
    _webrtc.initLocalMedia();
    // Подключаем события CallKeep
    FlutterCallkeep callKeep = FlutterCallkeep();
    callKeep.on<CallKeepPerformAnswerCallAction>(_answerCall);
    callKeep.on<CallKeepPerformEndCallAction>(_endCall);
    callKeep.on<CallKeepDidPerformSetMutedCallAction>(_setMutedCall);
    // Начать звонок (для исходящего)
    // _webrtc.makeCall(widget.peerId);
  }

  // Обработчик ответа на звонок через CallKeep
  Future<void> _answerCall(CallKeepPerformAnswerCallAction event) async {
    // Пользователь ответил через нативный экран звонка
    // Здесь можно продолжить установку соединения, если нужно
    print('Answer call: ${event.callData.callUUID}');
  }

  // Обработчик завершения звонка
  Future<void> _endCall(CallKeepPerformEndCallAction event) async {
    _webrtc.hangUp();
    Navigator.pop(context);
  }

  // Обработчик переключения беззвучного режима
  Future<void> _setMutedCall(CallKeepDidPerformSetMutedCallAction event) async {
    _webrtc.toggleMic();
    setState(() { _micEnabled = !_micEnabled; });
  }

  // Кнопка завершения
  void _onHangUp() {
    // Важно вызвать CallKeep для нативного UI (если он был показан)
    FlutterCallkeep().endAllCalls();
    _webrtc.hangUp();
    Navigator.pop(context);
  }

  // Кнопка беззвучного режима
  void _onToggleMic() {
    _webrtc.toggleMic();
    setState(() { _micEnabled = !_micEnabled; });
    // Уведомить callkeep о смене статуса
    FlutterCallkeep().setMutedCall(shouldMute: _micEnabled ? false : true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Звонок с ${widget.peerId}')),
      body: Stack(
        children: [
          // Видео удаленного участника
          RTCVideoView(_webrtc.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          // Маленькое локальное видео в углу
          Positioned(
            top: 20, right: 20,
            child: Container(
              width: 120, height: 160,
              child: RTCVideoView(_webrtc.localRenderer, mirror: true),
            ),
          ),
          // Панель управления
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off, color: Colors.white),
                    color: Colors.blue,
                    iconSize: 30,
                    onPressed: _onToggleMic,
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _onHangUp,
                    child: Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
