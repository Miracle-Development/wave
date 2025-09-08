import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_mic_button.dart';
import 'package:provider/provider.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key, required this.isInitialMuted});
  final bool isInitialMuted;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WebRTCManager>();
    final mics = manager.devices.where((d) => d.kind == 'audioinput').toList();
    final outs = manager.devices.where((d) => d.kind == 'audiooutput').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: WaveDivider(
            type: _resolveDividerType(manager.callState),
            label: _resolveDividerText(manager.callState),
          ),
        ),
        WaveChatBubble(
          type: WaveChatBubbleType.bubbleMessageInfo,
          label:
              'Your call will be end-to-end encryped.\nAre you ready to start?',
        ),
        SizedBox(height: 20),

        // Секция: список участников (presence)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WaveText('Participants', type: WaveTextType.subtitle),
              SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 160),
                child: ListView(
                  shrinkWrap: true,
                  children: manager.participants.values.map((p) {
                    return ListTile(
                      leading: Icon(
                        p.inCall ? Icons.person : Icons.person_off,
                        color: p.inCall ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        p.id == manager.localId
                            ? (p.name == null ? 'You' : '${p.name} (you)')
                            : (p.name ?? 'Peer'),
                      ),
                      subtitle: Text(
                        p.inCall ? 'In call' : 'Not in call',
                      ),
                      trailing: Icon(
                        p.muted ? Icons.mic_off : Icons.mic,
                        color: p.muted ? Colors.red : Colors.blue,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),
        WaveText(
          manager.formattedCallDuration,
          type: WaveTextType.title,
          weight: WaveTextWeight.regular,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),

        // Выбор микрофона и динамика как у вас было
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(children: [
            WaveText('Microphone:', type: WaveTextType.subtitle),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String?>(
                value: manager.selectedMicId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('По умолчанию'),
                  ),
                  ...mics.map(
                    (d) => DropdownMenuItem(
                      value: d.deviceId,
                      child: Text(d.label ?? 'Mic'),
                    ),
                  ),
                ],
                onChanged: (v) => context.read<WebRTCManager>().selectMic(v),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(children: [
            WaveText('Speaker:', type: WaveTextType.subtitle),
            SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String?>(
                value: manager.selectedSpeakerId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('По умолчанию'),
                  ),
                  ...outs.map(
                    (d) => DropdownMenuItem(
                      value: d.deviceId,
                      child: Text(d.label ?? 'Speaker'),
                    ),
                  ),
                ],
                onChanged: (v) =>
                    context.read<WebRTCManager>().selectSpeaker(v),
              ),
            ),
          ]),
        ),

        SizedBox(height: 20),
        WaveMicButton(
          isMuted: context.watch<WebRTCManager>().muted,
          onTap: () async {
            await context.read<WebRTCManager>().toggleMicMute();
          },
        ),
        SizedBox(height: 20),
        WaveSimpleButton(
          label: 'Leave Call',
          onPressed: () async {
            await context.read<WebRTCManager>().leaveCall();
          },
        ),
        SizedBox(height: 20),
        WaveSimpleButton(
          label: 'Start Call',
          onPressed: () async {
            await context.read<WebRTCManager>().startCall();
          },
        ),
      ],
    );
  }

  WaveDividerType _resolveDividerType(CallState state) {
    switch (state) {
      case CallState.connected:
        return WaveDividerType.positive;
      case CallState.connecting:
        return WaveDividerType.brand;
      case CallState.failed:
        return WaveDividerType.negative;
      case CallState.disconnected:
        return WaveDividerType.disabled;
    }
  }

  String _resolveDividerText(CallState callState) {
    switch (callState) {
      case CallState.connected:
        return 'Connected';
      case CallState.connecting:
        return 'Connecting';
      case CallState.failed:
        return 'Failed to connect';
      case CallState.disconnected:
        return 'Disconnected';
    }
  }
}
