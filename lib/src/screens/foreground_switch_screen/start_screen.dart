import 'package:flutter/material.dart';
import 'package:md_ui_kit/widgets/md_text.dart';
import 'package:wave/core/colors.dart';
import 'package:wave/src/widgets/quad_painter.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onNext});

  final VoidCallback? onNext;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  late AnimationController _topClipController;
  late AnimationController _bottomClipController;
  late Animation<double> _topClipAnim;
  late Animation<double> _bottomClipAnim;

  bool _showButton = false;
  bool _isExiting = false;
  bool _isReverseAnim = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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

    _topClipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _bottomClipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _topClipAnim =
        CurvedAnimation(parent: _topClipController, curve: Curves.easeOut);
    _bottomClipAnim =
        CurvedAnimation(parent: _bottomClipController, curve: Curves.easeOut);

    _controller.addListener(_handleMainControllerTick);

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showButton = true);
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  void _handleMainControllerTick() {
    if (_controller.value >= 0.4 &&
        _topClipController.status == AnimationStatus.dismissed) {
      _topClipController.forward();
    }
    if (_controller.value >= 0.5 &&
        _bottomClipController.status == AnimationStatus.dismissed) {
      _bottomClipController.forward();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleMainControllerTick);
    _controller.dispose();
    _topClipController.dispose();
    _bottomClipController.dispose();
    super.dispose();
  }

  Future<void> _onStartPressed() async {
    if (_isExiting) return;
    _isExiting = true;

    setState(() {
      _isReverseAnim = true;
    });

    // 1) Скрываем кнопку (opacity)
    if (mounted) setState(() => _showButton = false);
    await Future.delayed(const Duration(milliseconds: 320));

    // 2) Верхняя полоса: если не полностью показана — доводим, затем reverse()
    if (_topClipController.status != AnimationStatus.completed) {
      await _topClipController.forward();
    }
    await _topClipController.reverse();

    // 3) Нижняя полоса: аналогично (внимание: это останется слева->справа при reveal, и будет так же сворачиваться)
    if (_bottomClipController.status != AnimationStatus.completed) {
      await _bottomClipController.forward();
    }
    await _bottomClipController.reverse();

    // 4) Вызов перехода дальше
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    const double topPadding = 40 + 28;

    return Padding(
      padding: const EdgeInsets.only(top: topPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.constrainWidth();
          final rawMaxH = constraints.maxHeight;
          final screenH = MediaQuery.of(context).size.height;
          final h = rawMaxH.isFinite ? rawMaxH : (screenH - topPadding);
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
              // НИЖНЯЯ полоса — раскрывается слева->справа (fromLeft: true), при reverse будет сворачиваться справа->лево?
              // Нет — reverse уменьшает width от текущего состояния, сохраняя точку привязки (здесь слева), т.е. сворачивается слева->право.
              AnimatedBuilder(
                animation: _bottomClipAnim,
                builder: (context, _) {
                  return ClipRect(
                    clipper: _HorizontalClipper(
                      _bottomClipAnim.value,
                      fromLeft: !_isReverseAnim,
                    ),
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

              // Контент
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

              // ВЕРХНЯЯ полоса — раскрывается справа->влево (fromLeft: false). reverse() вернёт её обратно справа->влево.
              AnimatedBuilder(
                animation: _topClipAnim,
                builder: (context, _) {
                  return ClipRect(
                    clipper: _HorizontalClipper(
                      _topClipAnim.value,
                      fromLeft: _isReverseAnim,
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

              // Кнопка
              Positioned.fill(
                child: AnimatedOpacity(
                  curve: Curves.easeInOut,
                  opacity: _showButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 236.0),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _onStartPressed,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
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
