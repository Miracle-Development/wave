import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/models/call_state.dart';
import 'package:wave_p2p/src/core/keys.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/copy_code_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/enable_microphone_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/enable_video_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/main_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/paste_code_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/start_connection_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/start_screen.dart';
import 'package:wave_p2p/src/widgets/animated_container_wrapper.dart';

enum VisibleScreenType {
  startButton,
  micOn,
  micOnAnimated,
  videoOn,
  videoOnAnimated,
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

  @override
  void initState() {
    // TODO: remove reconnect functionality
    // _checkActiveConnection();

    _checkHasStartButtonPressed();
    _checkMicPermission();
    _checkVideoPermission();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<WebRTCManager>();
      manager.addListener(_onManagerStateChanged);
    });
  }

  void _onManagerStateChanged() {
    final manager = context.read<WebRTCManager>();
    if (manager.callState == CallState.connected &&
        _stepper != VisibleScreenType.main) {
      setState(() {
        _stepper = VisibleScreenType.main;
      });
    }
  }

  @override
  void dispose() {
    final manager = context.read<WebRTCManager>();
    manager.removeListener(_onManagerStateChanged);
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

      // Экран с кнопкой "Video on", скрывается если нажался хотя бы раз
      // без анимации, если проигрывается после startButton
      case VisibleScreenType.videoOn:
        return AnimatedContainerWrapper(
          purpleTitle: 'One more step',
          isAnimated: false,
          key: ValueKey<String>('videoOn$postfix'),
          topPadding: topPadding,
          child: EnableVideoScreen(
            onNext: _onEnableVideoPressed,
          ),
        );

      // Экран с кнопкой "Video on", скрывается если нажался хотя бы раз
      // с анимацией, если открывается сразу после заставки
      case VisibleScreenType.videoOnAnimated:
        return AnimatedContainerWrapper(
          purpleTitle: 'One more step',
          isAnimated: true,
          key: ValueKey<String>('videoOnAnimated$postfix'),
          topPadding: topPadding,
          child: EnableVideoScreen(
            onNext: _onEnableVideoPressed,
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
          child: CopyCodeScreen(onBackPressed: () {
            setState(() {
              _stepper = VisibleScreenType.selectAction;
            });
          }),
        );

      // Экран вставки кода
      case VisibleScreenType.pasteCode:
        return AnimatedContainerWrapper(
          key: ValueKey<String>('pasteCode$postfix'),
          topPadding: topPadding,
          isAnimated: false,
          child: PasteCodeScreen(onBackPressed: () {
            setState(() {
              _stepper = VisibleScreenType.selectAction;
            });
          }),
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
      // ignore: unreachable_switch_default
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
    final gotMicAccess = prefs.getBool(prefsMicAccessKey) ?? false;

    if (gotStarted) {
      if (gotMicAccess) {
        setState(() {
          _stepper = VisibleScreenType.videoOnAnimated;
        });
      } else {
        setState(() {
          _stepper = VisibleScreenType.micOnAnimated;
        });
      }

      return;
    }
  }

  Future<void> _checkMicPermission() async {
    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccessPref = prefs.getBool(prefsMicAccessKey) ?? false;

    // предпроверка, чтобы не было заранее запроса доступа на веб
    final gotStarted = prefs.getBool(prefsFirstTimeStartKey) ?? false;

    if (gotStarted) {
      final hasAccess = await manager.checkMicrophonePermission();

      if (hasAccess && hasAccessPref) {
        await manager.updateAudioDevices();

        if (!kDebugMode) {
          setState(() {
            _stepper = VisibleScreenType.videoOnAnimated;
          });
        } else {
          setState(() {
            _stepper = VisibleScreenType.selectActionAnimated;
          });
        }

        return;
      } else {
        await prefs.setBool(prefsMicAccessKey, false);
        return;
      }
    }
  }

  Future<void> _checkVideoPermission() async {
    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccessPref = prefs.getBool(prefsCamAccessKey) ?? false;

    // предпроверка, чтобы не было заранее запроса доступа на веб
    final gotStarted = prefs.getBool(prefsFirstTimeStartKey) ?? false;

    if (gotStarted) {
      final hasAccess = await manager.checkCameraPermission();

      if (hasAccess && hasAccessPref) {
        await manager.updateAudioDevices();

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
    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccess = await manager.checkMicrophonePermission();

    if (hasAccess) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Доступ к микрофону получен')),
      //   );
      // }

      // функция обновления списка устройств
      await manager.updateAudioDevices();

      // запоминаем
      await prefs.setBool(prefsMicAccessKey, true);
      setState(() {
        _stepper = VisibleScreenType.videoOnAnimated;
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

  Future<void> _onEnableVideoPressed() async {
    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccess = await manager.checkCameraPermission();

    if (hasAccess) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Доступ к микрофону получен')),
      //   );
      // }

      // функция обновления списка устройств
      // await manager.updateAudioDevices();

      // запоминаем
      await prefs.setBool(prefsCamAccessKey, true);
      setState(() {
        _stepper = VisibleScreenType.selectActionAnimated;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Доступ к камере не получен, разрешите его в настройках')),
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

    if (isInitiator == null) {
      prefs.setBool(isPeerInitiatorKey, false);
    }

    setState(() {
      _stepper = VisibleScreenType.main;
    });

    // await _disposableManager.restoreConnection();
  }

  Future<String> _getLocalOfferId() async {
    final prefs = await SharedPreferences.getInstance();
    // TODO: обработать случай когда нет кода в локальной памяти
    return prefs.getString(currentPeerLocalIdKey) ?? 'Invalid two-word code';
  }

  Future<void> _onClosePeerPressed() async {
    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();

    await manager.closeAll();

    // очищаем локальный код
    await prefs.remove(currentPeerLocalIdKey);

    await prefs.remove(currentPeerLocalIdKey);
    await prefs.setBool(prefsHasActiveConnectionKey, false);

    // возвращаемся к начальному экрану
    setState(() {
      _stepper = VisibleScreenType.selectAction;
    });
  }

  // Future<void> _checkActiveConnection() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final hasActiveConnection =
  //       prefs.getBool(prefsHasActiveConnectionKey) ?? false;

  //   if (hasActiveConnection) {
  //     final isPeerInitiator = prefs.getBool(isPeerInitiatorKey) ?? true;
  //     setState(() {
  //       _stepper = VisibleScreenType.main;
  //       _isPeerInitiator = isPeerInitiator;
  //     });
  //   }
  // }
}
