import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
// TODO: fix
import 'package:md_ui_kit/widgets/wave_hint_text.dart'
    hide WaveTextType, WaveTextWeight;
import 'package:provider/provider.dart';
import 'package:wave_p2p/models/call_state.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/copy_code_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/paste_code_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/start_connection_screen.dart';
import 'package:wave_p2p/src/widgets/animated_status_line.dart';
import 'package:wave_p2p/src/widgets/center_container_wrapper.dart';

enum StageType {
  select,
  createCode,
  pasteCode,
  connection,
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    super.key,
    required this.isNavBarShowed,
    required this.topPadding,
    required this.localId,
    required this.isPeerInitiator,
    required this.onClosePeerPressed,
    required this.state,
  });

  final bool isNavBarShowed;
  final double topPadding;
  final String localId;
  final bool isPeerInitiator;
  final VoidCallback onClosePeerPressed;
  final CallState state;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  StageType stageType = StageType.select;

  late WebRTCManager _disposableManager;

  @override
  void initState() {
    super.initState();
    if (widget.state == CallState.connected) {
      setState(() {
        stageType = StageType.connection;
      });
    }

    _disposableManager = Provider.of<WebRTCManager>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // final manager = context.read<WebRTCManager>();

      // выключаем микрофон сразу после подключения
      // await _disposableManager.toggleMicMute();
      _disposableManager.addListener(_handleStateChange);
    });
  }

  void _handleStateChange() {
    // Используем сохранённый менеджер, а не context
    setState(() {
      if (_disposableManager.callState == CallState.connected) {
        stageType = StageType.connection;
      }
    });
  }

  @override
  void dispose() {
    _disposableManager.removeListener(_handleStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const postfix = '_screen_stage';
    switch (stageType) {
      // Экран с выбором действия - создать/вставить код
      // без анимации, если проигрывается после micOn
      case StageType.select:
        return CenterContainerWrapper(
          key: ValueKey<String>('selectAction$postfix'),
          topPadding: 100,
          child: StartConnectionScreen(
            onCreateCode: () {
              setState(() {
                stageType = StageType.createCode;
              });
            },
            onPasteCode: () {
              setState(() {
                stageType = StageType.pasteCode;
              });
            },
          ),
        );

      // Экран создания кода
      case StageType.createCode:
        return CenterContainerWrapper(
          key: ValueKey<String>('createCode$postfix'),
          topPadding: 0,
          child: CopyCodeScreen(),
        );

      // Экран вставки кода
      case StageType.pasteCode:
        return CenterContainerWrapper(
          key: ValueKey<String>('pasteCode$postfix'),
          topPadding: 200,
          child: PasteCodeScreen(),
        );

      case StageType.connection:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: WaveStatus(
                    type: _resolveStatusType(widget.state),
                    label: _resolveStatusText(widget.state),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      WaveText(
                        widget.localId,
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
                        _resolveSubtitleText(
                            widget.state, widget.isPeerInitiator),
                        type: WaveTextType.caption,
                        color: _resolveSubtitleColor(widget.state),
                      ),
                    ],
                  ),
                ),
                if (widget.state == CallState.connected) ...[
                  SizedBox(height: 305),
                  WaveSimpleButton(
                    label: 'Close peer',
                    onPressed: () {
                      setState(() {
                        stageType = StageType.select;
                      });
                      widget.onClosePeerPressed();
                    },
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
                if (widget.state == CallState.failed ||
                    widget.state == CallState.disconnected) ...[
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
                    onPressed: () {
                      setState(() {
                        stageType = StageType.select;
                      });
                      widget.onClosePeerPressed();
                    },
                  ),
                  SizedBox(height: 260),
                ],
              ],
            ),
          ),
        );
    }
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
