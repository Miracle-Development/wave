import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/widgets/wave_text.dart';

class AnimatedContainerWrapper extends StatefulWidget {
  const AnimatedContainerWrapper({
    super.key,
    this.purpleTitle,
    required this.child,
    required this.isAnimated, required this.topPadding,
  });

  final String? purpleTitle;
  final Widget child;
  final bool isAnimated;
  final double topPadding;

  @override
  State<AnimatedContainerWrapper> createState() =>
      _AnimatedContainerWrapperState();
}

class _AnimatedContainerWrapperState extends State<AnimatedContainerWrapper>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  bool _showContent = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
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

    Future.delayed(Duration(milliseconds: widget.isAnimated ? 1400 : 600), () {
      if (mounted) setState(() => _showContent = true);
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
    final topPadding = widget.topPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        // final w = constraints.constrainWidth();
        final rawMaxH = constraints.maxHeight;
        final screenH = MediaQuery.of(context).size.height;
        final h = rawMaxH.isFinite ? rawMaxH : (screenH - topPadding);
        // final safeSize = Size(w, h);

        final childContainer = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            height: h,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              color: MdColors.containerColor,
            ),
            child: widget.purpleTitle != null
                ? Center(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: WaveText(
                          widget.purpleTitle!,
                          type: WaveTextType.subtitle,
                          weight: WaveTextWeight.bold,
                          color: MdColors.brandColor,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        );

        return Stack(
          children: [
            // Подложка контента
            widget.isAnimated
                ? SlideTransition(
                    position: _offsetAnimation,
                    child: childContainer,
                  )
                : childContainer,

            // Контент
            Positioned.fill(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: _showContent ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.center,
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
