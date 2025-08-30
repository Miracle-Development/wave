import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:md_ui_kit/widgets/wave_divider.dart';
import 'package:md_ui_kit/widgets/wave_simple_button.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';
import 'package:wave/core/colors.dart';

class CopyCodeScreen extends StatelessWidget {
  const CopyCodeScreen({
    super.key,
    required this.onCopyCodePressed,
  });

  final VoidCallback onCopyCodePressed;

  @override
  Widget build(BuildContext context) {
    const double topPadding = 40 + 28;

    return Stack(
      children: [
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
                          label: 'copy-code',
                          onPressed: onCopyCodePressed,
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
