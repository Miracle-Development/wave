import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/src/core/keys.dart';
import 'package:wave/src/core/webrtc_manager.dart';
import 'package:wave/src/widgets/animated_container_wrapper.dart';
import 'package:wave/src/screens/foreground_switch_screen/copy_code_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/enable_microphone_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/main_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/paste_code_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_connection_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_screen.dart';

enum VisibleScreenType {
  startButton,
  micOn,
  micOnAnimated,
  selectAction,
  selectActionAnimated,
  createCode,
  pasteCode,
  main,
}

class ForegroundSwitchScreen extends StatefulWidget {
  const ForegroundSwitchScreen({super.key});

  @override
  State<ForegroundSwitchScreen> createState() => ForegroundSwitchScreenState();
}

class ForegroundSwitchScreenState extends State<ForegroundSwitchScreen> {
  // TODO back to 0   if stable
  VisibleScreenType _stepper = VisibleScreenType.startButton;

  bool _isPeerInitiator = true;

  late WebRTCManager _disposableManager;

  @override
  void initState() {
    // TODO: remove reconnect functionality
    _checkActiveConnection();

    _checkHasStartButtonPressed();
    _checkMicPermission();
    _disposableManager = Provider.of<WebRTCManager>(context, listen: false);
    super.initState();
  }

  @override
  void dispose() {
    final manager = _disposableManager;
    // закрываем соединение при очистке виджета
    manager.closeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // старые экраны остаются и плавно исчезают
            ...previousChildren,
            // новый экран накладывается
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _buildStep(_stepper),
    );
  }

  // обязательно! разные ключи для разных виджетов
  Widget _buildStep(VisibleScreenType stepper) {
    const postfix = '_screen';
    const double topPadding = 80;
    switch (stepper) {
      // Экран с кнопкой "Start", скрывается если нажался хотя бы раз
      case VisibleScreenType.startButton:
        return StartScreen(
          key: ValueKey<String>('startButton$postfix'),
          onNext: _onStartButtonPressed,
        );

      // Экран с кнопкой "Mic on", скрывается если нажался хотя бы раз
      // без анимации, если проигрывается после startButton
      case VisibleScreenType.micOn:
        return AnimatedContainerWrapper(
          purpleTitle: 'One more step',
          isAnimated: false,
          key: ValueKey<String>('micOn$postfix'),
          topPadding: topPadding,
          child: EnableMicrophoneScreen(
            onNext: _onEnableMicPressed,
          ),
        );

      // Экран с кнопкой "Mic on", скрывается если нажался хотя бы раз
      // с анимацией, если открывается сразу после заставки
      case VisibleScreenType.micOnAnimated:
        return AnimatedContainerWrapper(
          purpleTitle: 'One more step',
          isAnimated: true,
          key: ValueKey<String>('minOnAnimated$postfix'),
          topPadding: topPadding,
          child: EnableMicrophoneScreen(
            onNext: _onEnableMicPressed,
          ),
        );

      // Экран с выбором действия - создать/вставить код
      // без анимации, если проигрывается после micOn
      case VisibleScreenType.selectAction:
        return AnimatedContainerWrapper(
          isAnimated: false,
          key: ValueKey<String>('selectAction$postfix'),
          topPadding: topPadding,
          child: StartConnectionScreen(
            onCreateCode: _onCreateCodePressed,
            onPasteCode: _onPasteCodePressed,
            // TODO: remove reconnect functionality
            onOrPressed: _onOrPressed,
          ),
        );

      // Экран с выбором действия - создать/вставить код
      // без анимации, если проигрывается после micOn
      case VisibleScreenType.selectActionAnimated:
        return AnimatedContainerWrapper(
          key: ValueKey<String>('selectActionAnimated$postfix'),
          topPadding: topPadding,
          isAnimated: true,
          child: StartConnectionScreen(
            onCreateCode: _onCreateCodePressed,
            onPasteCode: _onPasteCodePressed,
            // TODO: remove reconnect functionality
            onOrPressed: _onOrPressed,
          ),
        );

      // Экран создания кода
      case VisibleScreenType.createCode:
        return AnimatedContainerWrapper(
          key: ValueKey<String>('createCode$postfix'),
          topPadding: topPadding,
          isAnimated: false,
          child: CopyCodeScreen(
            onCheckPairPressed: _onCheckPairPressed,
          ),
        );

      // Экран вставки кода
      case VisibleScreenType.pasteCode:
        return AnimatedContainerWrapper(
          key: ValueKey<String>('pasteCode$postfix'),
          topPadding: topPadding,
          isAnimated: false,
          child: PasteCodeScreen(
            onConnectPressed: _onCheckAnswerPressed,
          ),
        );

      // Основной экран с динамичным навбаром, скаффолдом с адаптивной высотой и волной
      case VisibleScreenType.main:
        return MainScreen(
          key: ValueKey<String>('main$postfix'),
          topPadding: topPadding,
          isPeerInitiator: _isPeerInitiator,
          onReturnPressed: () {
            setState(() {
              _stepper = VisibleScreenType.selectAction;
            });
          },
          onClosePeerPressed: _onClosePeerPressed,
        );

      // TODO: DO NOT REMOVE TO PREFENT FAILURE ON PROD
      // TODO: создать красивый экран с ошибкой навигации
      default:
        return Container(
          key: const ValueKey<int>(-1),
          color: Colors.blue,
        );
    }
  }

  Future<void> _checkHasStartButtonPressed() async {
    final prefs = await SharedPreferences.getInstance();

    final gotStarted = prefs.getBool(prefsFirstTimeStartKey) ?? false;

    if (gotStarted) {
      // if (!kDebugMode)
      setState(() {
        _stepper = VisibleScreenType.micOnAnimated;
      });
      return;
    }
  }

  Future<void> _checkMicPermission() async {
    final webrtcManager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccessPref = prefs.getBool(prefsMicAccessKey) ?? false;

    // предпроверка, чтобы не было заранее запроса доступа на веб
    final gotStarted = prefs.getBool(prefsFirstTimeStartKey) ?? false;

    if (gotStarted) {
      final hasAccess = await webrtcManager.checkMicrophonePermission();

      if (hasAccess && hasAccessPref) {
        await webrtcManager.updateAudioDevices();

        // if (!kDebugMode)
        setState(() {
          _stepper = VisibleScreenType.selectActionAnimated;
        });
        return;
      } else {
        await prefs.setBool(prefsMicAccessKey, false);
        return;
      }
    }
  }

  Future<void> _onEnableMicPressed() async {
    final webrtcManager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccess = await webrtcManager.checkMicrophonePermission();

    if (hasAccess) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Доступ к микрофону получен')),
      //   );
      // }

      // функция обновления списка устройств
      await webrtcManager.updateAudioDevices();

      // запоминаем
      await prefs.setBool(prefsMicAccessKey, true);
      setState(() {
        _stepper = VisibleScreenType.selectActionAnimated;
      });
    } else {
      // TODO: Доступ не получен
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Доступ к микрофону не получен, разрешите его в настройках')),
      );
      // setState(() {
      //   _stepper = VisibleScreenType.selectAction;
      // });
    }
  }

  Future<void> _onStartButtonPressed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsFirstTimeStartKey, true);
    setState(() {
      _stepper = VisibleScreenType.micOn;
    });
  }

  void _onCreateCodePressed() async {
    setState(() {
      _stepper = VisibleScreenType.createCode;
      _isPeerInitiator = true;
    });
  }

  Future<void> _onPasteCodePressed() async {
    setState(() {
      _stepper = VisibleScreenType.pasteCode;
      _isPeerInitiator = false;
    });
  }

  // TODO: remove reconnect functionality
  Future<void> _onOrPressed() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isInitiator = prefs.getBool(isPeerInitiatorKey);

    if (isInitiator != null) {
      setState(() {
        _stepper = VisibleScreenType.main;
      });
    }

    await _disposableManager.restoreConnection();
  }

  Future<void> _onCheckPairPressed() async {
    final manager = context.read<WebRTCManager>();
    try {
      // достаем из памяти localId two-word code
      final offerId = await _getLocalOfferId();
      // pull answer and apply it (this will throw if answer isn't ready)
      await manager.acceptAnswer(offerId);

      setState(() {
        _stepper = VisibleScreenType.main;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(isPeerInitiatorKey, _isPeerInitiator);
      await prefs.setBool(prefsHasActiveConnectionKey, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply answer: $e')),
      );
    } finally {}
  }

  Future<void> _onCheckAnswerPressed() async {
    final manager = context.read<WebRTCManager>();
    try {
      // достаем из памяти localId two-word code
      final offerId = await _getLocalOfferId();
      // pull answer and apply it (this will throw if answer isn't ready)
      await manager.acceptOffer(offerId);

      setState(() {
        _stepper = VisibleScreenType.main;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(isPeerInitiatorKey, _isPeerInitiator);
      await prefs.setBool(prefsHasActiveConnectionKey, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply offer: $e')),
      );
    } finally {}
  }

  Future<String> _getLocalOfferId() async {
    final prefs = await SharedPreferences.getInstance();
    // TODO: обработать случай когда нет кода в локальной памяти
    return prefs.getString(currentPeerLocalIdKey) ?? 'Invalid two-word code';
  }

  Future<void> _onClosePeerPressed() async {
    final prefs = await SharedPreferences.getInstance();
    // очищаем локальный код
    await prefs.remove(currentPeerLocalIdKey);

    await prefs.remove(currentPeerLocalIdKey);
    await prefs.setBool(prefsHasActiveConnectionKey, false);
    // возвращаемся к начальному экрану
    setState(() {
      _stepper = VisibleScreenType.selectAction;
    });
  }

  Future<void> _checkActiveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final hasActiveConnection =
        prefs.getBool(prefsHasActiveConnectionKey) ?? false;

    if (hasActiveConnection) {
      final isPeerInitiator = prefs.getBool(isPeerInitiatorKey) ?? true;
      setState(() {
        _stepper = VisibleScreenType.main;
        _isPeerInitiator = isPeerInitiator;
      });
    }
  }
}
