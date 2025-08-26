import 'package:flutter/material.dart';
import 'package:md_ui_kit/widgets/md_text.dart';
import 'package:wave/core/colors.dart';
import 'package:wave/src/widgets/quad_painter.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onNext});

  final VoidCallback? onNext;

  @override
  State<StartScreen> createState() => StartScreenState();
}

class StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  late Animation<double> _topAnim;
  late Animation<double> _bottomAnim;

  bool _showButton = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // общее время
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _topAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.5, curve: Curves.easeOut),
    );

    _bottomAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.55, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _showButton = true;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double topPadding = 40 + 28;

    return Padding(
      padding: const EdgeInsets.only(top: topPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.constrainWidth();

          // если constraints.maxHeight бесконечен — возьмём высоту экрана (минус topPadding)
          final rawMaxH = constraints.maxHeight;
          final screenH = MediaQuery.of(context).size.height;
          final h = rawMaxH.isFinite ? rawMaxH : (screenH - topPadding);

          // безопасный Size для CustomPaint и SizedBox
          final safeSize = Size(w, h);

          final quadTop = [
            const Offset(0.0, 0.60),
            const Offset(1.0, 0.50),
            const Offset(1.0, 0.70),
            const Offset(0.0, 0.80),
          ];
          final quadBottom = [
            const Offset(0.0, 0.70),
            const Offset(1.0, 0.70),
            const Offset(1.0, 0.90),
            const Offset(0.0, 0.80),
          ];

          return Stack(
            children: [
              // НИЖНЯЯ полоса (слева -> вправо): рисуем первой, чтобы была под контентом
              AnimatedBuilder(
                animation: _bottomAnim,
                builder: (context, _) {
                  return ClipRect(
                    clipper:
                        _HorizontalClipper(_bottomAnim.value, fromLeft: true),
                    child: CustomPaint(
                      size: safeSize,
                      painter: QuadPainter(
                        points: quadBottom,
                        normalized: true,
                        color: WaveColors.brandSecondStrip,
                        drawShadow: true,
                        shadowElevation: 10,
                      ),
                    ),
                  );
                },
              ),

              // КАРТОЧКА / КОНТЕНТ (SlideTransition)
              SlideTransition(
                position: _offsetAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                ),
              ),

              // ВЕРХНЯЯ полоса (справа -> влево): рисуем последней, чтобы быть поверх
              AnimatedBuilder(
                animation: _topAnim,
                builder: (context, _) {
                  return ClipRect(
                    clipper: _HorizontalClipper(
                      _topAnim.value,
                      fromLeft: false,
                    ),
                    child: CustomPaint(
                      size: safeSize,
                      painter: QuadPainter(
                        points: quadTop,
                        normalized: true,
                        color: WaveColors.brandFirstStrip,
                        drawShadow: true,
                        shadowElevation: 10,
                      ),
                    ),
                  );
                },
              ),

              Positioned.fill(
                child: AnimatedOpacity(
                  curve: Curves.easeInOut,
                  opacity: _showButton ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 300),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 236.0),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onNext,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(24),
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(12),
                              ),
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 11,
                                horizontal: 60,
                              ),
                              child: MdText(
                                'Start',
                                color: MdTextColor.brandColor,
                                weight: MdTextWeight.bold,
                                type: MdTextType.title,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HorizontalClipper extends CustomClipper<Rect> {
  final double progress; // от 0.0 до 1.0
  final bool fromLeft;

  _HorizontalClipper(this.progress, {this.fromLeft = true});

  @override
  Rect getClip(Size size) {
    final width = size.width * progress;
    if (fromLeft) {
      return Rect.fromLTWH(0, 0, width, size.height);
    } else {
      return Rect.fromLTWH(size.width - width, 0, width, size.height);
    }
  }

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) =>
      oldClipper.progress != progress;
}
