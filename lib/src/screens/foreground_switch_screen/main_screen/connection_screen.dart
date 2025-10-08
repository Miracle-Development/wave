import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
// TODO: fix
import 'package:md_ui_kit/widgets/wave_hint_text.dart'
    hide WaveTextType, WaveTextWeight;
import 'package:wave_p2p/models/call_state.dart';
import 'package:wave_p2p/src/widgets/animated_status_line.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({
    super.key,
    required this.isNavBarShowed,
    required this.topPadding,
    required this.localId,
    required this.isPeerInitiator,
    required this.onReturnPressed,
    required this.onClosePeerPressed, required this.state,
  });

  final bool isNavBarShowed;
  final double topPadding;
  final String localId;
  final bool isPeerInitiator;
  final VoidCallback onReturnPressed;
  final VoidCallback onClosePeerPressed;
  final CallState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: WaveStatus(
                type: _resolveStatusType(state),
                label: _resolveStatusText(state),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  WaveText(
                    localId,
                    type: WaveTextType.title,
                    color: MdColors.titleColor,
                    weight: WaveTextWeight.bold,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Row(
            //   children: [
            //     Flexible(
            //       child: Padding(
            //         padding: const EdgeInsets.symmetric(horizontal: 16.0),
            //         child: WaveText(
            //           'QASGHSVRGMOHGM4O87GH345G8H75W46V8MAYHW765T3HM7HPGBFGUIHHSVRG...MON',
            //           maxLines: 3,
            //           type: WaveTextType.caption,
            //           color: MdColors.subtitleColor,
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            // SizedBox(height: 14),
            AnimatedStatusLine(),

            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  WaveText(
                    _resolveSubtitleText(state, isPeerInitiator),
                    type: WaveTextType.caption,
                    color: _resolveSubtitleColor(state),
                  ),
                ],
              ),
            ),
            if (state == CallState.connected) ...[
              SizedBox(height: 305),
              WaveSimpleButton(
                label: 'Close peer',
                onPressed: onClosePeerPressed,
              ),
              SizedBox(height: 20),
              WaveText(
                'This leads to the termination of your connection',
                type: WaveTextType.caption,
                textAlign: TextAlign.center,
                color: MdColors.disabledColor,
              ),
              SizedBox(height: 305),
            ],
            if (state == CallState.failed ||
                state == CallState.disconnected) ...[
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: WaveHintText(
                  textAlign: TextAlign.start,
                  boldPart: 'This might help: ',
                  normalPart:
                      'Return to the previous step and try to pair once again',
                ),
              ),
              SizedBox(height: 260),
              WaveSimpleButton(
                label: 'Return',
                onPressed: onReturnPressed,
              ),
              SizedBox(height: 260),
            ],
          ],
        ),
      ),
    );
  }

  WaveStatusType _resolveStatusType(CallState callState) {
    switch (callState) {
      case CallState.connected:
        return WaveStatusType.positive;
      case CallState.connecting:
        return WaveStatusType.brand;
      case CallState.failed:
        return WaveStatusType.negative;
      case CallState.disconnected:
        return WaveStatusType.disabled;
    }
  }

  _resolveStatusText(CallState callState) {
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

  String _resolveSubtitleText(CallState callState, bool? isPeerInitiator) {
    switch (callState) {
      case CallState.connected:
        return 'Successful connection!';
      case CallState.connecting:
        if (isPeerInitiator == null) return 'Waiting other device to connect..';
        return isPeerInitiator
            ? 'Waiting your friend’s device to accept..'
            : 'Waiting your friend’s device to answer..';
      case CallState.failed:
        return 'Failed!';
      case CallState.disconnected:
        return 'Connection lost!';
    }
  }

  _resolveSubtitleColor(CallState callState) {
    switch (callState) {
      case CallState.connected:
        return MdColors.positiveColor;
      case CallState.connecting:
        return MdColors.subtitleColor;
      case CallState.failed:
        return MdColors.negativeColor;
      case CallState.disconnected:
        return MdColors.disabledColor;
    }
  }
}
