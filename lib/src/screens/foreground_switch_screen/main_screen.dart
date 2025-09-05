import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
// TODO: fix
import 'package:md_ui_kit/widgets/wave_hint_text.dart'
    hide WaveTextType, WaveTextWeight;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/src/core/keys.dart';
import 'package:wave/src/core/webrtc_manager.dart';
import 'package:wave/src/widgets/animated_status_line.dart';
import 'package:wave/src/widgets/dynamic_container_wrapper.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.isPeerInitiator,
    required this.onReturnPressed,
    required this.topPadding,
    required this.onClosePeerPressed,
  });

  final bool isPeerInitiator;
  final VoidCallback onReturnPressed;
  final VoidCallback onClosePeerPressed;
  final double topPadding;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String localId = '';

  bool _isNavBarShowed = false;

  int navBarIndex = 0;

  Future<void> _getLocalOfferId() async {
    final prefs = await SharedPreferences.getInstance();
    // TODO: обработать случай когда нет кода в локальной памяти
    final id =
        prefs.getString(currentPeerLocalIdKey) ?? 'Invalid two-word code';
    setState(() {
      localId = id;
    });
  }

  @override
  void initState() {
    super.initState();
    _getLocalOfferId();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<WebRTCManager>();
      manager.addListener(_handleStateChange);
    });
  }

  void _handleStateChange() {
    final manager = context.read<WebRTCManager>();
    setState(() {
      if (manager.callState == CallState.connected) {
        setState(() {
          _isNavBarShowed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    final manager = context.read<WebRTCManager>();
    manager.removeListener(_handleStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WebRTCManager manager = Provider.of<WebRTCManager>(context);

    return ListenableBuilder(
        listenable: manager,
        builder: (context, child) {
          return DynamicContainerWrapper(
            isNavBarShowed: _isNavBarShowed, // Передаем состояние навбара
            topPadding: widget.topPadding,
            navBarIndex: navBarIndex,
            onNavBarIndexChanged: (index) {
              setState(() => navBarIndex = index);
            },
            child: _buildCurrentPage(manager), // Строим текущую страницу
          );
        });
  }

  Widget _buildCurrentPage(WebRTCManager manager) {
    switch (navBarIndex) {
      case 0:
        return ConnectionPage(
          key: ValueKey<int>(0),
          topPadding: widget.topPadding,
          isNavBarShowed: _isNavBarShowed,
          manager: manager,
          localId: localId,
          isPeerInitiator: widget.isPeerInitiator,
          onReturnPressed: widget.onReturnPressed,
          onClosePeerPressed: widget.onClosePeerPressed,
        );
      case 1:
        return ChatPage();
      case 2:
        return CallPage();
      default:
        return Placeholder();
    }
  }
}

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({
    super.key,
    required this.isNavBarShowed,
    required this.topPadding,
    required this.manager,
    required this.localId,
    required this.isPeerInitiator,
    required this.onReturnPressed,
    required this.onClosePeerPressed,
  });

  final bool isNavBarShowed;
  final double topPadding;
  final WebRTCManager manager;
  final String localId;
  final bool isPeerInitiator;
  final VoidCallback onReturnPressed;
  final VoidCallback onClosePeerPressed;

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
                type: _resolveStatusType(manager.callState),
                label: _resolveStatusText(manager.callState),
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
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
            //   child: Divider(color: MdColors.subtitleColor),
            // ),
            AnimatedStatusLine(),

            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  WaveText(
                    _resolveSubtitleText(manager.callState, isPeerInitiator),
                    type: WaveTextType.caption,
                    color: _resolveSubtitleColor(manager.callState),
                  ),
                ],
              ),
            ),
            if (manager.callState == CallState.connected) ...[
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
            if (manager.callState == CallState.failed ||
                manager.callState == CallState.disconnected) ...[
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

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}

class CallPage extends StatelessWidget {
  const CallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}
