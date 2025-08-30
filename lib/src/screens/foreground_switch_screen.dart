import 'package:flutter/material.dart';
import 'package:wave/src/screens/foreground_switch_screen/copy_code_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/enable_microphone_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_connection_screen.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_screen.dart';

class ForegroundSwitchScreen extends StatefulWidget {
  const ForegroundSwitchScreen({super.key});

  @override
  State<ForegroundSwitchScreen> createState() => ForegroundSwitchScreenState();
}

class ForegroundSwitchScreenState extends State<ForegroundSwitchScreen> {
  int _steper = 0; // TODO back to 0   if stable

  bool _isOfferingScreen = true;

  void _onStartButtonPressed() {
    setState(() {
      _steper++;
    });
  }

  void _onEnableMicPressed() {
    setState(() {
      _steper++;
    });
  }

  void _onCreateCodePressed() {
    setState(() {
      _steper++;
    });
  }

  void _onPasteCodePressed() {}

  void _onCopyCodePressed() {
    // setState(() {
    //   _steper++;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // определяем, incoming ли child (ему соответствует текущий _step)
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
      child: _buildStep(_steper),
    );
  }

// обязательно! разные ключи для разных виджетов
  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return StartScreen(
          key: const ValueKey<int>(0),
          onNext: _onStartButtonPressed,
        );
      case 1:
        // TODO add shared pref check, if done - skip
        return EnableMicrophoneScreen(
          key: const ValueKey<int>(1),
          onNext: _onEnableMicPressed,
        );
      case 2:
        return StartConnectionScreen(
          key: const ValueKey<int>(2),
          onCreateCode: _onCreateCodePressed,
          onPasteCode: _onPasteCodePressed,
        );
      case 3:
        return CopyCodeScreen(
          key: const ValueKey<int>(3),
          onCopyCodePressed: _onCopyCodePressed,
          // onPasteCode: _onPasteCodePressed,
        );
      default:
        return Container(
          key: const ValueKey<int>(-1),
          color: Colors.blue,
        );
    }
  }
}
