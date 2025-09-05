import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/src/core/keys.dart';
import 'package:wave/src/core/webrtc_manager.dart';
import 'package:wave/src/screens/foreground_switch_screen/main_screen/call_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/main_screen/chat_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/main_screen/connection_screen.dart';
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

  late WebRTCManager _disposableManager;

  final _chatTextController = TextEditingController();

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

    _disposableManager = Provider.of<WebRTCManager>(context, listen: false);
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
    _chatTextController.dispose();
    final manager = _disposableManager;
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
          useScroll: navBarIndex != 1,
          isNavBarShowed: _isNavBarShowed,
          topPadding: widget.topPadding,
          navBarIndex: navBarIndex,
          onNavBarIndexChanged: (index) => setState(() => navBarIndex = index),
          onSendButtonPressed: () async {
            final t = _chatTextController.text.trim();
            if (t.isEmpty) return;
            await manager.sendText(t);
            _chatTextController.clear();
          },
          controller: _chatTextController,
          child: _buildCurrentPage(manager.callState),
        );
      },
    );
  }

  Widget _buildCurrentPage(CallState state) {
    switch (navBarIndex) {
      case 0:
        return ConnectionScreen(
          key: ValueKey<int>(0),
          topPadding: widget.topPadding,
          isNavBarShowed: _isNavBarShowed,
          localId: localId,
          state: state,
          isPeerInitiator: widget.isPeerInitiator,
          onReturnPressed: widget.onReturnPressed,
          onClosePeerPressed: widget.onClosePeerPressed,
        );
      case 1:
        return ChatScreen(
          key: ValueKey<int>(1),
        );
      case 2:
        return CallScreen(
          key: ValueKey<int>(2),
        );
      default:
        return Placeholder(
          key: ValueKey<int>(-1),
        );
    }
  }
}
