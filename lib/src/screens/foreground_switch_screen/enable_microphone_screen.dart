import 'package:flutter/material.dart';
import 'package:md_ui_kit/widgets/md_text.dart';
import 'package:wave/core/colors.dart';

class EnableMicrophoneScreen extends StatelessWidget {
  const EnableMicrophoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const double topPadding = 40 + 28;

    return Stack(
      children: [
        Container(
          color: Colors.red,
          child: Text('Enable Microphone Screen'),
        ),
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
              padding:
                  const EdgeInsets.only(left: 20, right: 20, top: topPadding,),
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: WaveColors.containerColor,
                ),
                child: Center(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: MdText(
                        'Welcome!',
                        type: MdTextType.subtitle,
                        weight: MdTextWeight.bold,
                        color: MdTextColor.brandColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
