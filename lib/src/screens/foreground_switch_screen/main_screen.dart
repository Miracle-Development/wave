import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/models/call_state.dart';
import 'package:wave_p2p/models/contact.dart';
import 'package:wave_p2p/src/core/keys.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/main_screen/friend_list_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/main_screen/call_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/main_screen/chat_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/main_screen/connection_screen.dart';
import 'package:wave_p2p/src/widgets/dynamic_container_wrapper.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.isPeerInitiator,
    required this.topPadding,
    required this.onClosePeerPressed,
  });

  final bool isPeerInitiator;
  final VoidCallback onClosePeerPressed;
  final double topPadding;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String localId = '';

  // TODO: remove reconnect functionality
  bool _isNavBarShowed = true;

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
    // _isNavBarShowed = true;
    _getLocalOfferId();

    _disposableManager = Provider.of<WebRTCManager>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // final manager = context.read<WebRTCManager>();

      // выключаем микрофон сразу после подключения
      await _disposableManager.toggleMicMute();
      _disposableManager.addListener(_handleStateChange);
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
    _chatTextController.dispose();
    _disposableManager.removeListener(_handleStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _disposableManager,
      builder: (context, child) {
        final isConnected = _disposableManager.callState == CallState.connected;

        return DynamicContainerWrapper(
          isConnected: isConnected,
          useScroll: navBarIndex != 1,
          isNavBarShowed: _isNavBarShowed,
          topPadding: widget.topPadding,
          navBarIndex: navBarIndex,
          onNavBarIndexChanged: (index) => setState(() => navBarIndex = index),
          onSendButtonPressed: () async {
            final t = _chatTextController.text.trim();
            if (t.isEmpty) return;
            await _disposableManager.sendText(t);
            _chatTextController.clear();
          },
          controller: _chatTextController,
          child: _buildCurrentPage(_disposableManager.callState),
        );
      },
    );
  }

  Widget _buildCurrentPage(CallState state) {
    final manager = context.read<WebRTCManager>();

    switch (navBarIndex) {
      case 0:
        return ConnectionScreen(
          key: ValueKey<int>(0),
          topPadding: widget.topPadding,
          isNavBarShowed: _isNavBarShowed,
          localId: localId,
          state: state,
          isPeerInitiator: widget.isPeerInitiator,
          onClosePeerPressed: widget.onClosePeerPressed,
        );
      case 1:
        return ChatScreen(
          key: ValueKey<int>(1),
        );
      case 2:
        return CallScreen(
          // peerId: manager.callKeepUUID!,
          key: ValueKey<int>(2),
          isInitialMuted: false,
        );
      case 3:
        return FriendsListScreen(
          key: ValueKey<int>(3),
          onOpenChat: (Contact contact) {
            manager.selectedContact = contact;
            setState(() => navBarIndex = 1); // переключить на чат
          },
          onStartCall: (Contact contact) async {
            manager.selectedContact = contact;
            // Если соединение не установлено, сначала создаём offer и ждём ответа
            if (manager.callState != CallState.connected) {
              // Можно создать оффер и показать экран ожидания
              await manager
                  .createOfferLink(); // или acceptOffer, в зависимости от роли
              // Здесь нужно переключить на вкладку Call, но пока просто
              setState(() => navBarIndex = 2);
            } else {
              // Если уже соединены, просто включаем звонок
              await manager.startCall();
              setState(() => navBarIndex = 2);
            }
          },
        );
      default:
        return Placeholder(
          key: ValueKey<int>(-1),
        );
    }
  }
}
