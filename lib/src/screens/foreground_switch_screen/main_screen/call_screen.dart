import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_mic_button.dart';
import 'package:provider/provider.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({
    super.key,
    required this.isInitialMuted,
    required this.disposableManager,
  });

  final bool isInitialMuted;
  final WebRTCManager disposableManager;

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<WebRTCManager>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
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
        SizedBox(height: 40),
        Consumer<WebRTCManager>(
          builder: (context, manager, child) {
            return WaveText(
              manager.formattedCallDuration,
              type: WaveTextType.title,
              weight: WaveTextWeight.regular,
              textAlign: TextAlign.center,
            );
          },
        ),
        SizedBox(height: 40),
        WaveMicButton(
          isMuted: manager.muted,
          onTap: () async {
            await manager.toggleMicMute();
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
