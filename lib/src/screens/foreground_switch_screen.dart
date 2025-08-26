import 'package:flutter/material.dart';
import 'package:wave/src/screens/foreground_switch_screen/start_screen.dart';

class ForegroundSwitchScreen extends StatefulWidget {
  const ForegroundSwitchScreen({super.key});

  @override
  State<ForegroundSwitchScreen> createState() => ForegroundSwitchScreenState();
}

class ForegroundSwitchScreenState extends State<ForegroundSwitchScreen> {
  int _steper = 0;

  bool _isOfferingScreen = true;

  void _onStartButtonPressed() {
    setState(() {
      _steper++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
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
          key: const ValueKey("start"),
          onNext: _onStartButtonPressed,
        );
      case 1:
        return Container(
          key: const ValueKey("microphone"),
          color: Colors.red,
        );
      default:
        return Container(
          key: const ValueKey("other"),
          color: Colors.blue,
        );
    }
  }
}
