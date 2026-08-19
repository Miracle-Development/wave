import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave_p2p/src/core/keys.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/enable_microphone_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/main_screen.dart';
import 'package:wave_p2p/src/screens/foreground_switch_screen/start_screen.dart';
import 'package:wave_p2p/src/widgets/animated_container_wrapper.dart';

enum VisibleScreenType {
  startButton,
  micOn,
  micOnAnimated,
  main,
}

class ForegroundSwitchScreen extends StatefulWidget {
  const ForegroundSwitchScreen({super.key});

  @override
  State<ForegroundSwitchScreen> createState() => ForegroundSwitchScreenState();
}

class ForegroundSwitchScreenState extends State<ForegroundSwitchScreen>
    with ChangeNotifier, WidgetsBindingObserver {
  // TODO back to 0   if stable
  VisibleScreenType _stepper = VisibleScreenType.startButton;

  bool _isPeerInitiator = true;

  void setPeerInitiator(bool isPeerInitiator) {
    _isPeerInitiator = isPeerInitiator;
    notifyListeners();
  }

  @override
  void initState() {
    // TODO: remove reconnect functionality
    // _checkActiveConnection();

    _checkHasStartButtonPressed();

    super.initState();
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

      // Основной экран с динамичным навбаром, скаффолдом с адаптивной высотой и волной
      case VisibleScreenType.main:
        return MainScreen(
          key: ValueKey<String>('main$postfix'),
          topPadding: topPadding,
          isPeerInitiator: _isPeerInitiator,

          // onReturnPressed: () {
          //   setState(() {
          //     _stepper = VisibleScreenType.selectAction;
          //   });
          // },
          onClosePeerPressed: _onClosePeerPressed,
        );

      // TODO: DO NOT REMOVE TO PREVENT FAILURE ON PROD
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

    if (!mounted) return;

    final gotStarted = prefs.getBool(prefsFirstTimeStartKey) ?? false;

    if (gotStarted) {
      _checkMicPermission();
      if (!mounted) return;
      final hasMicAccess = prefs.getBool(prefsMicAccessKey) ?? false;
      if (!hasMicAccess) {
        // if (!kDebugMode)
        if (!mounted) return;
        setState(() {
          _stepper = VisibleScreenType.micOnAnimated;
        });
      }

      return;
    }
  }

  Future<void> _checkMicPermission() async {
    if (!mounted) return;

    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccessPref = prefs.getBool(prefsMicAccessKey) ?? false;

    // предпроверка, чтобы не было заранее запроса доступа на веб
    final gotStarted = prefs.getBool(prefsFirstTimeStartKey) ?? false;

    if (gotStarted) {
      final hasAccess = await manager.checkMicrophonePermission();

      if (!mounted) return;

      if (hasAccess && hasAccessPref) {
        await manager.updateAudioDevices();

        if (!mounted) return;

        // if (!kDebugMode)
        setState(() {
          _stepper = VisibleScreenType.main;
        });
        return;
      } else {
        await prefs.setBool(prefsMicAccessKey, false);
        return;
      }
    }
  }

  Future<void> _onEnableMicPressed() async {
    if (!mounted) return;

    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();
    final hasAccess = await manager.checkMicrophonePermission();

    if (!mounted) return;

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
        _stepper = VisibleScreenType.main;
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
    final hasMicAccess = prefs.getBool(prefsMicAccessKey) ?? false;
    if (hasMicAccess) {
      setState(() {
        _stepper = VisibleScreenType.main;
      });
    } else {
      setState(() {
        _stepper = VisibleScreenType.micOn;
      });
    }
  }

  // TODO: remove reconnect functionality
  // Future<void> _onOrPressed() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final bool? isInitiator = prefs.getBool(isPeerInitiatorKey);

  //   if (isInitiator == null) {
  //     prefs.setBool(isPeerInitiatorKey, false);
  //   }

  //   setState(() {
  //     _stepper = VisibleScreenType.main;
  //   });

  //   await context.read<WebRTCManager>().restoreConnection();
  // }

  Future<String> _getLocalOfferId() async {
    final prefs = await SharedPreferences.getInstance();
    // TODO: обработать случай когда нет кода в локальной памяти
    return prefs.getString(currentPeerLocalIdKey) ?? 'mysterious-code';
  }

  Future<void> _onClosePeerPressed() async {
    final manager = context.read<WebRTCManager>();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    await manager.closeAll();

    // очищаем локальный код
    await prefs.remove(currentPeerLocalIdKey);

    await prefs.remove(currentPeerLocalIdKey);
    await prefs.setBool(prefsHasActiveConnectionKey, false);

    if (!mounted) return;

    // возвращаемся к начальному экрану
    setState(() {
      _stepper = VisibleScreenType.main;
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
