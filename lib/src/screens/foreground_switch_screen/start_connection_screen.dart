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
    final orWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: WaveDivider(
        type: WaveDividerType.disabled,
        label: context.l10n.t('start_connection_screen.or'),
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaveText(
          context.l10n.t('start_connection_screen.create_code'),
          type: WaveTextType.title,
          weight: WaveTextWeight.bold,
        ),
        SizedBox(height: 10),
        WaveText(
          context.l10n.t('start_connection_screen.initiate'),
          type: WaveTextType.caption,
          color: MdColors.disabledColor,
        ),
        SizedBox(height: 24),
        WaveSimpleButton(
          label: context.l10n.t('start_connection_screen.create'),
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
          context.l10n.t('start_connection_screen.paste_code'),
          type: WaveTextType.title,
          weight: WaveTextWeight.bold,
        ),
        SizedBox(height: 10),
        WaveText(
          context.l10n.t('start_connection_screen.connect'),
          type: WaveTextType.caption,
          color: MdColors.disabledColor,
        ),
        SizedBox(height: 24),
        WaveSimpleButton(
          label: context.l10n.t('start_connection_screen.paste'),
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
