import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/screens/initial_screen.dart';
import 'package:wave/src/screens/home_screen.dart';

class InitialScreenImpl extends StatefulWidget {
  const InitialScreenImpl({super.key});

  @override
  State<InitialScreenImpl> createState() => _InitialScreenImplState();
}

class _InitialScreenImplState extends State<InitialScreenImpl> {
  bool _showSplash = true;
  // double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    Timer(const Duration(milliseconds: 5500), () {
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return
        // kDebugMode
        //     ? HomeScreen(
        //         key: ValueKey("home"),
        //       )
        //     :
        AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      layoutBuilder: (currentChild, previousChildren) {
        return DecoratedBox(
          decoration: BoxDecoration(color: MdColors.backgroundColor),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _buildChild(),
    );
  }

  _buildChild() {
    switch (_showSplash) {
      case true:
        return InitialScreen(
          key: const ValueKey("splash"),
          wavePositionedBottom: kIsWeb ? 120 : 100,
        );
      case false:
        return const HomeScreen(
          key: ValueKey("home"),
        );
    }
  }
}
