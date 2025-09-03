import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';

class StartConnectionScreen extends StatelessWidget {
  const StartConnectionScreen({
    super.key,
    required this.onCreateCode,
    required this.onPasteCode,
  });

  final VoidCallback onCreateCode;
  final VoidCallback onPasteCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaveText(
          'Create a code',
          type: WaveTextType.title,
          weight: WaveTextWeight.bold,
        ),
        SizedBox(height: 10),
        WaveText(
          'If you want to initiate a connection',
          type: WaveTextType.caption,
          color: MdColors.disabledColor,
        ),
        SizedBox(height: 24),
        WaveSimpleButton(
          label: 'Create',
          onPressed: onCreateCode,
          type: WaveButtonType.main,
          padding: EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 56,
          ),
        ),
        SizedBox(height: 80),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: WaveDivider(type: WaveDividerType.disabled, label: 'OR'),
        ),
        SizedBox(height: 80),
        WaveText(
          'Paste code from friend',
          type: WaveTextType.title,
          weight: WaveTextWeight.bold,
        ),
        SizedBox(height: 10),
        WaveText(
          'If you want to connect to already created peer',
          type: WaveTextType.caption,
          color: MdColors.disabledColor,
        ),
        SizedBox(height: 24),
        WaveSimpleButton(
          label: 'Paste',
          onPressed: onPasteCode,
          type: WaveButtonType.main,
          padding: EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 56,
          ),
        ),
      ],
    );
  }
}
