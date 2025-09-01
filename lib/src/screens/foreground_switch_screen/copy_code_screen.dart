import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';

class CopyCodeScreen extends StatelessWidget {
  const CopyCodeScreen({
    super.key,
    required this.onCopyCodePressed,
    required this.label,
  });

  final Function(String) onCopyCodePressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'This is your two-word pair code. Copy and send it to your friend',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 27),
        WaveTextButton(
          label: label,
          onPressed: () => onCopyCodePressed(label),
        ),
        SizedBox(height: 135),
        WaveSimpleButton(label: 'Check pair'),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 57.0),
          child: WaveText(
            'Wait your friend to paste the code for button enabling',
            type: WaveTextType.caption,
            maxLines: 3,
            textAlign: TextAlign.center,
            color: MdColors.disabledColor,
          ),
        ),
      ],
    );
  }
}
