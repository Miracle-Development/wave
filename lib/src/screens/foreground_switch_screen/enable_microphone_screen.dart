import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/widgets/wave_simple_button.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';

class EnableMicrophoneScreen extends StatelessWidget {
  const EnableMicrophoneScreen({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaveText(
          'Allow access, please',
          type: WaveTextType.subtitle,
        ),
        SizedBox(height: 20),
        WaveSimpleButton(
          label: 'Mic on',
          onPressed: onNext,
          showShadow: true,
          type: WaveButtonType.alternative,
        ),
      ],
    );
  }
}
