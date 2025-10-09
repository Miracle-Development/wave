import 'package:flutter/material.dart';
import 'package:md_ui_kit/widgets/wave_simple_button.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';
import 'package:wave_p2p/src/i18n/localizations.dart';

class EnableMicrophoneScreen extends StatelessWidget {
  const EnableMicrophoneScreen({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaveText(
          locale.translate('enable_microphone_screen.allow'),
          type: WaveTextType.subtitle,
        ),
        SizedBox(height: 20),
        WaveSimpleButton(
          label: locale.translate('enable_microphone_screen.mic_on'),
          onPressed: onNext,
          showShadow: true,
          type: WaveButtonType.alternative,
        ),
      ],
    );
  }
}
