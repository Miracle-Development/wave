import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_circle_button.dart';
import 'package:md_ui_kit/widgets/wave_device_menu.dart';
import 'package:md_ui_kit/widgets/wave_mic_button.dart';
import 'package:md_ui_kit/widgets/wave_participant.dart';
import 'package:md_ui_kit/widgets/wave_participant_loader.dart';
import 'package:provider/provider.dart';
import 'package:callkeep/callkeep.dart' show FlutterCallkeep;
import 'package:wave_p2p/models/call_state.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/src/widgets/swipe_switcher.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    this.isInitialMuted = false,
    this.disposableManager,
  });

  final bool isInitialMuted;
  final WebRTCManager? disposableManager;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool isSettingsOpen = false;
  bool _isVideoEnabled = false;
  bool _isScreenSharing = false;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WebRTCManager>();

    final mics = manager.devices.where((d) => d.kind == 'audioinput').toList();
    final outs = manager.devices.where((d) => d.kind == 'audiooutput').toList();

    final participants = manager.participantsList;
    final localParticipant = participants.firstWhere(
      (p) => p.id == manager.localId,
      orElse: () =>
          ParticipantState(id: '1', inCall: false, muted: true, name: 'You'),
    );
    final remoteParticipant = participants.firstWhere(
      (p) => p.id != manager.localId,
      orElse: () =>
          ParticipantState(id: '2', inCall: false, muted: true, name: 'Peer'),
    );

    // Видео-виджеты
    final remoteVideo = manager.remoteRenderer;
    final localVideo = manager.localRenderer;

    return Column(
      children: [
        // Верхняя часть с видео (если активно)
        if (_isVideoEnabled || _isScreenSharing) ...[
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Удалённое видео (на весь экран)
                RTCVideoView(
                  remoteVideo,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                // Локальное видео (маленькое в углу)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: RTCVideoView(
                      localVideo,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
                // Индикатор состояния
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: WaveText(
                    manager.formattedCallDuration,
                    type: WaveTextType.caption,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Остальной интерфейс (как было)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
          child: WaveDivider(
            type: _resolveDividerType(manager.callState),
            label: _resolveDividerText(manager.callState),
          ),
        ),
        WaveChatBubble(
          type: WaveChatBubbleType.bubbleMessageInfo,
          label: 'Your call is end-to-end encrypted',
        ),
        const SizedBox(height: 8),
        if (!_isVideoEnabled && !_isScreenSharing) ...[
          WaveText(
            manager.formattedCallDuration,
            type: WaveTextType.subtitle,
            weight: WaveTextWeight.regular,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ],

        SwipeSwitcher(
          showDevices: isSettingsOpen,
          devicesWidgets: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: WaveDeviceMenu(
                items: mics,
                subtitle: 'Current Input Device',
                labelBuilder: (item) => item.label ?? 'Default Microphone',
                onChanged: (v) => manager.selectMic(v.deviceId),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: WaveDeviceMenu(
                items: outs,
                subtitle: 'Current Output Device',
                labelBuilder: (item) => item.label ?? 'Default Speaker',
                onChanged: (v) => manager.selectSpeaker(v.deviceId),
              ),
            ),
          ],
          participantsWidgets: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WaveParticipant(
                    label: 'You',
                    inCall: localParticipant.inCall,
                    muted: localParticipant.muted,
                  ),
                  const SizedBox(width: 16),
                  const WaveParticipantLoader(),
                  const SizedBox(width: 16),
                  WaveParticipant(
                    label: 'Peer',
                    inCall: remoteParticipant.inCall,
                    muted: remoteParticipant.muted,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Кнопки управления
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.only(top: 26.0, right: 26.0),
                child: WaveCircleButton(
                  type: WaveCircleButtonType.setting,
                  subtitle: 'Settings',
                  onTap: () => setState(() => isSettingsOpen = !isSettingsOpen),
                ),
              ),
            ),
            WaveMicButton(
              isMuted: manager.muted,
              onTap: () async {
                await manager.toggleMicMute();
                try {
                  final ck = FlutterCallkeep();
                  if (manager.callKeepUUID != null) {
                    try {
                      await ck.setMutedCall(
                          uuid: manager.callKeepUUID!,
                          shouldMute: manager.muted);
                    } catch (_) {
                      try {
                        await ck.setMutedCall(
                            uuid: manager.callKeepUUID!,
                            shouldMute: manager.muted);
                      } catch (e) {
                        // ignore if API mismatch
                      }
                    }
                  }
                } catch (_) {}
              },
            ),
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.only(top: 26.0, left: 26.0),
                child: WaveCircleButton(
                  type: manager.inCall
                      ? WaveCircleButtonType.leaveCall
                      : WaveCircleButtonType.startCall,
                  subtitle: manager.inCall ? 'Leave Call' : 'Join Call',
                  onTap: () async {
                    if (manager.inCall) {
                      await manager.leaveCall();
                    } else {
                      await manager.startCall();
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Дополнительные кнопки: динамик, камера, шаринг
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                manager.isEarpieceMode ? Icons.phone_iphone : Icons.speaker,
              ),
              onPressed: () => manager.toggleAudioOutput(),
              tooltip: manager.isEarpieceMode ? 'Телефон' : 'Динамик',
            ),
            // const SizedBox(width: 16),
            // IconButton(
            //   icon: Icon(
            //     _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            //   ),
            //   onPressed: () async {
            //     if (_isVideoEnabled) {
            //       await manager.disableVideo();
            //     } else {
            //       try {
            //         await manager.enableVideo();
            //       } catch (e) {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           SnackBar(content: Text('Ошибка камеры: $e')),
            //         );
            //       }
            //     }
            //     setState(() => _isVideoEnabled = !_isVideoEnabled);
            //   },
            // ),
            // if (!Platform.isIOS) ...[
            //   const SizedBox(width: 16),
            //   IconButton(
            //     icon: Icon(
            //       _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
            //     ),
            //     onPressed: () async {
            //       if (_isScreenSharing) {
            //         await manager.disableScreenShare();
            //       } else {
            //         try {
            //           await manager.enableScreenShare();
            //         } catch (e) {
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(content: Text('Ошибка шаринга: $e')),
            //           );
            //         }
            //       }
            //       setState(() => _isScreenSharing = !_isScreenSharing);
            //     },
            //   ),
            // ],
          ],
        ),

        // const SizedBox(height: 20),
      ],
    );
  }

  WaveDividerType _resolveDividerType(CallState state) {
    switch (state) {
      case CallState.connected:
        return WaveDividerType.positive;
      case CallState.failed:
        return WaveDividerType.negative;
      case CallState.connecting:
        return WaveDividerType.brand;
      default:
        return WaveDividerType.disabled;
    }
  }

  String _resolveDividerText(CallState state) {
    switch (state) {
      case CallState.connected:
        return 'Connected';
      case CallState.failed:
        return 'Call Failed';
      case CallState.connecting:
        return 'Connecting...';
      default:
        return 'Ready to call';
    }
  }
}
