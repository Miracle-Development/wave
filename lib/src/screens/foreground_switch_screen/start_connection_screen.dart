import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:wave_p2p/src/i18n/localizations.dart';

class StartConnectionScreen extends StatelessWidget {
  const StartConnectionScreen({
    super.key,
    required this.onCreateCode,
    required this.onPasteCode,
    required this.onOrPressed,
  });

  final VoidCallback onCreateCode;
  final VoidCallback onPasteCode;

  // TODO: remove reconnect functionality
  final VoidCallback onOrPressed;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    final orWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: WaveDivider(
        type: WaveDividerType.disabled,
        label: locale.translate('start_connection_screen.or_text'),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaveText(
          locale.translate('start_connection_screen.create_code_text'),
          type: WaveTextType.title,
          weight: WaveTextWeight.bold,
        ),
        SizedBox(height: 10),
        WaveText(
          locale.translate('start_connection_screen.initiate_text'),
          type: WaveTextType.caption,
          color: MdColors.disabledColor,
        ),
        SizedBox(height: 24),
        WaveSimpleButton(
          label: locale.translate('start_connection_screen.create_button'),
          onPressed: onCreateCode,
          type: WaveButtonType.main,
          padding: EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 56,
          ),
        ),
        SizedBox(height: 80),
        // TODO: remove reconnect functionality
        kDebugMode
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    onOrPressed();
                  },
                  child: orWidget,
                ),
              )
            : orWidget,

        SizedBox(height: 80),
        WaveText(
          locale.translate('start_connection_screen.paste_code_text'),
          type: WaveTextType.title,
          weight: WaveTextWeight.bold,
        ),
        SizedBox(height: 10),
        WaveText(
          locale.translate('start_connection_screen.connect_text'),
          type: WaveTextType.caption,
          color: MdColors.disabledColor,
        ),
        SizedBox(height: 24),
        WaveSimpleButton(
          label: locale.translate('start_connection_screen.paste_button'),
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
