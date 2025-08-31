import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_simple_button.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';
import 'package:wave/src/core/colors.dart';

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
    const double topPadding = 40 + 28;

    return Stack(
      children: [
        // Align(
        //   alignment: Alignment.center,
        //   child:
        // ),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.constrainWidth();

            // если constraints.maxHeight бесконечен — возьмём высоту экрана (минус topPadding)
            final rawMaxH = constraints.maxHeight;
            final screenH = MediaQuery.of(context).size.height;
            final h = rawMaxH.isFinite ? rawMaxH : (screenH - topPadding);

            // безопасный Size для CustomPaint и SizedBox
            final safeSize = Size(w, h);

            return Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
              ),
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: WaveColors.containerColor,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: WaveText(
                          'One more step',
                          type: WaveTextType.subtitle,
                          weight: WaveTextWeight.bold,
                          color: MdColors.brandColor,
                        ),
                      ),
                    ),
                    Column(
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
                        WaveDivider(
                            type: WaveDividerType.disabled, label: 'OR'),
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
