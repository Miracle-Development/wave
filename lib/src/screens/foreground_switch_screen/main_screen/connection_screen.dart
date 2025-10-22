import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
// TODO: fix
import 'package:md_ui_kit/widgets/wave_hint_text.dart'
    hide WaveTextType, WaveTextWeight;
import 'package:wave_p2p/models/call_state.dart';
import 'package:wave_p2p/src/i18n/localizations.dart';
import 'package:wave_p2p/src/widgets/animated_status_line.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({
    super.key,
    required this.isNavBarShowed,
    required this.topPadding,
    required this.localId,
    required this.isPeerInitiator,
    required this.onReturnPressed,
    required this.onClosePeerPressed,
    required this.state,
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
    final locale = AppLocalizations.of(context);

    String resolveStatusText(CallState callState) {
      switch (callState) {
        case CallState.connected:
          return locale.translate('connection_screen.connected_text');
        case CallState.connecting:
          return locale.translate('connection_screen.connecting_text');
        case CallState.failed:
          return locale.translate('connection_screen.fail_to_connect_text');
        case CallState.disconnected:
          return locale.translate('connection_screen.disconnected_text');
      }
    }

    String resolveSubtitleText(CallState callState, bool? isPeerInitiator) {
      switch (callState) {
        case CallState.connected:
          return locale
              .translate('connection_screen.successful_connection_text');
        case CallState.connecting:
          if (isPeerInitiator == null) {
            return locale.translate('connection_screen.device_to_connect_text');
          }
          return isPeerInitiator
              ? locale.translate('connection_screen.device_to_accept_text')
              : locale.translate('connection_screen.device_to_answer_text');
        case CallState.failed:
          return locale.translate('connection_screen.failed_text');
        case CallState.disconnected:
          return locale.translate('connection_screen.connection_lost_text');
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: WaveStatus(
                type: resolveStatusType(state),
                label: resolveStatusText(state),
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
                    resolveSubtitleText(state, isPeerInitiator),
                    type: WaveTextType.caption,
                    color: resolveSubtitleColor(state),
                  ),
                ],
              ),
            ),
            if (state == CallState.connected) ...[
              SizedBox(height: 305),
              WaveSimpleButton(
                label: locale.translate('connection_screen.close_peer_button'),
                onPressed: onClosePeerPressed,
              ),
              SizedBox(height: 20),
              WaveText(
                locale.translate('connection_screen.warn_termination_text'),
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
                  boldPart: locale.translate('connection_screen.help_text'),
                  normalPart: locale
                      .translate('connection_screen.return_to_prev_step_text'),
                ),
              ),
              SizedBox(height: 260),
              WaveSimpleButton(
                label: locale.translate('connection_screen.return_button'),
                onPressed: onReturnPressed,
              ),
              SizedBox(height: 260),
            ],
          ],
        ),
      ),
    );
  }

  WaveStatusType resolveStatusType(CallState callState) {
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

  resolveSubtitleColor(CallState callState) {
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
