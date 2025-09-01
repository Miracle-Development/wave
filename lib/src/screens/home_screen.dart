import 'package:flutter/material.dart';
import 'package:md_ui_kit/md_ui_kit.dart';

import 'package:wave/src/screens/foreground_switch_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffoldWrapper(
      showLogo: true,
      iosTopPadding: 82,
      child: ForegroundSwitchScreen(),
    );
  }
}
