import 'package:flutter/material.dart';
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
import 'package:wave_p2p/src/i18n/localizations.dart';
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
  // bool inCall = false;
  bool isSettingsOpen = false;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    final manager =
        widget.disposableManager ?? Provider.of<WebRTCManager>(context);

    final mics = manager.devices.where((d) => d.kind == 'audioinput').toList();
    final outs = manager.devices.where((d) => d.kind == 'audiooutput').toList();

    // Получаем список участников
    final participants = manager.participantsList;

    // Находим локального участника (you)
    final localParticipant = participants.firstWhere(
      (p) => p.id == manager.localId,
      orElse: () => ParticipantState(
        id: '1',
        inCall: false,
        muted: true,
        name: locale.translate("call_screen.you_text"),
      ),
    );

    // Находим удаленного участника (peer) - первого из оставшихся
    final remoteParticipant = participants.firstWhere(
      (p) => p.id != manager.localId,
      orElse: () => ParticipantState(
        id: '2',
        inCall: false,
        muted: true,
        name: locale.translate("call_screen.peer_text"),
      ),
    );

    String resolveDividerText(CallState state) {
      switch (state) {
        case CallState.connected:
          return locale.translate("call_screen.connected_text");
        case CallState.failed:
          return locale.translate("call_screen.call_failed_text");
        case CallState.connecting:
          return locale.translate("call_screen.connecting_text");
        default:
          return locale.translate("call_screen.ready_text");
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
          child: WaveDivider(
            type: _resolveDividerType(manager.callState),
            label: resolveDividerText(manager.callState),
          ),
        ),
        WaveChatBubble(
          type: WaveChatBubbleType.bubbleMessageInfo,
          label: locale.translate("call_screen.encrypted_text"),
        ),

        SizedBox(height: 40),
        WaveText(
          manager.formattedCallDuration,
          type: WaveTextType.subtitle,
          weight: WaveTextWeight.regular,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 100),

        SwipeSwitcher(
          showDevices: isSettingsOpen,
          devicesWidgets: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: WaveDeviceMenu(
                items: mics,
                subtitle:
                    locale.translate("call_screen.current_input_device_text"),
                labelBuilder: (item) =>
                    item.label ?? locale.translate("call_screen.dfl_mic_text"),
                onChanged: (v) => manager.selectMic(v.deviceId),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: WaveDeviceMenu(
                items: outs,
                subtitle:
                    locale.translate("call_screen.current_output_device_text"),
                labelBuilder: (item) =>
                    item.label ??
                    locale.translate("call_screen.dfl_speaker_text"),
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
                  if (localParticipant != null)
                    WaveParticipant(
                      label: locale.translate("call_screen.you_text"),
                      inCall: localParticipant.inCall,
                      muted: localParticipant.muted,
                    ),
                  SizedBox(width: 16),
                  WaveParticipantLoader(),
                  SizedBox(width: 16),
                  if (remoteParticipant != null)
                    WaveParticipant(
                      label: locale.translate("call_screen.peer_text"),
                      inCall: remoteParticipant.inCall,
                      muted: remoteParticipant.muted,
                    ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 100),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 26.0,
                  right: 26.0,
                ),
                child: WaveCircleButton(
                  type: WaveCircleButtonType.setting,
                  subtitle: locale.translate("call_screen.settings_text"),
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
                } catch (e) {
                  // ignore callkeep issues
                }
              },
            ),
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 26.0,
                  left: 26.0,
                ),
                child: WaveCircleButton(
                  type: manager.inCall
                      ? WaveCircleButtonType.leaveCall
                      : WaveCircleButtonType.startCall,
                  subtitle: manager.inCall
                      ? locale.translate("call_screen.leave_text")
                      : locale.translate("call_screen.join_text"),
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

        // SizedBox(height: 32),
        //         WaveSimpleButton(
        //   label: 'Close Peer',
        //   onPressed: () async {
        //     await manager.closeAll();
        //   },
        // ),

        // Column(
        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        //   children: [
        // if (!inCall)
        // WaveSimpleButton(
        //   label: manager.inCall ? 'Leave Call' : 'Start Call',
        //   onPressed: () async {
        //     if (manager.inCall) {
        //       await manager.leaveCall();
        //     } else {
        //       try {
        //         await manager.startCall();
        //       } catch (e) {
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           SnackBar(
        //             content: Text('Start call failed: $e'),
        //           ),
        //         );
        //       }
        //     }
        //   },
        // ),
        // WaveSimpleButton(
        //   label: 'Toggle Video',
        //   onPressed: () async {
        //     if (manager.localRenderer.srcObject != null) {
        //       await manager.disableVideo();
        //     } else {
        //       try {
        //         await manager.enableVideo();
        //       } catch (e) {
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           SnackBar(
        //             content: Text('Camera error: $e'),
        //           ),
        //         );
        //       }
        //     }
        //   },
        // ),

        // ],
        // ),

        SizedBox(height: 200),
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
}
