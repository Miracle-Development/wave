import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/gradient_background.dart';
import 'package:md_ui_kit/widgets/wave_logo.dart';

import 'package:wave/src/screens/foreground_switch_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffoldWrapper(
      // child: const Padding(
      //   padding: EdgeInsets.all(20.0),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: [
      //       WaveLogo(),
      //     ],
      //   ),
      // ),
      child: ForegroundSwitchScreen(),
    );
  }
}
