import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:md_ui_kit/widgets/gradient_scaffold_wrapper.dart';
import 'package:md_ui_kit/widgets/md_text.dart';
import 'package:md_ui_kit/widgets/wave_logo.dart';

import 'package:wave/core/colors.dart';
import 'package:wave/src/widgets/quad_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  late Animation<double> _topAnim;
  late Animation<double> _bottomAnim;

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

    Future.delayed(const Duration(milliseconds: 800), () {
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
    return GradientScaffoldWrapper(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: WaveLogo(),
          ),
          // 👇 растягиваем нижний контейнер на всё оставшееся место
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

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
                          clipper: _HorizontalClipper(_bottomAnim.value,
                              fromLeft: true),
                          child: CustomPaint(
                            size: Size(w, h),
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
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
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
                          ],
                        ),
                      ),
                    ),

                    // ВЕРХНЯЯ полоса (справа -> влево): рисуем последней, чтобы быть поверх
                    AnimatedBuilder(
                      animation: _topAnim,
                      builder: (context, _) {
                        return ClipRect(
                          clipper: _HorizontalClipper(_topAnim.value,
                              fromLeft: false),
                          child: CustomPaint(
                            size: Size(w, h),
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
                  ],
                );
              },
            ),
          ),
        ],
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
