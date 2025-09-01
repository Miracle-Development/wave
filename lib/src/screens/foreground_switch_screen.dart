import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/src/core/webrtc_manager.dart';
import 'package:wave/src/screens/animated_container_wrapper.dart';
import 'package:wave/src/screens/foreground_switch_screen/copy_code_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/enable_microphone_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_connection_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_screen.dart';

const prefsFirstTimeStartKey = 'got_started_first_time';
const prefsMicAccessKey = 'got_mic_access';

enum VisibleScreenType {
  startButton,
  micOn,
  micOnAnimated,
  selectAction,
  selectActionAnimated,
  createCode,
  pasteCode,
}

class ForegroundSwitchScreen extends StatefulWidget {
  const ForegroundSwitchScreen({super.key});

  @override
  State<ForegroundSwitchScreen> createState() => ForegroundSwitchScreenState();
}

class ForegroundSwitchScreenState extends State<ForegroundSwitchScreen> {
  VisibleScreenType _stepper = VisibleScreenType.startButton;
  // int _steper = 0; // TODO back to 0   if stable

  // bool _isOfferingScreen = true;

  @override
  void initState() {
    _checkHasStartButtonPressed();
    _checkMicPermission();
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
          child: StartConnectionScreen(
            onCreateCode: _onCreateCodePressed,
            onPasteCode: _onPasteCodePressed,
          ),
        );

      // Экран с выбором действия - создать/вставить код
      // без анимации, если проигрывается после micOn
      case VisibleScreenType.selectActionAnimated:
        return AnimatedContainerWrapper(
          key: ValueKey<String>('selectActionAnimated$postfix'),
          isAnimated: true,
          child: StartConnectionScreen(
            onCreateCode: _onCreateCodePressed,
            onPasteCode: _onPasteCodePressed,
          ),
        );

      // Экран создания кода
      case VisibleScreenType.createCode:
        return AnimatedContainerWrapper(
          key: ValueKey<String>('createCode$postfix'),
          isAnimated: false,
          child: CopyCodeScreen(
          ),
        );

      // case VisibleScreenType.selectAction:
      //   return CopyCodeScreen(
      //     key: ValueKey<String>('selectAction$postfix'),
      //     label: label,
      //     onCopyCodePressed: (code) => _onCopyCodePressed(code),
      //     // onPasteCode: _onPasteCodePressed,
      //   );

      // TODO: DO NOT REMOVE TO PREFENT FAILURE ON PROD
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

    final hasAccess = await webrtcManager.checkMicrophonePermission();

    if (hasAccess && hasAccessPref) {
      await webrtcManager.updateAudioDevices();

      setState(() {
        _stepper = VisibleScreenType.selectActionAnimated;
      });
      return;
    } else {
      await prefs.setBool(prefsMicAccessKey, false);
      return;
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

  void _onCreateCodePressed() {
    setState(() {
      _stepper = VisibleScreenType.createCode;
    });
  }



  Future<void> _onPasteCodePressed() async {
    // TODO remove, only for debugging
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsFirstTimeStartKey, false);
    await prefs.setBool(prefsMicAccessKey, false);
  }
}
