import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/widgets/wave_simple_button.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';
import 'package:wave/src/core/colors.dart';

class EnableMicrophoneScreen extends StatelessWidget {
  const EnableMicrophoneScreen({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

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
