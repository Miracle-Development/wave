import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';

class DynamicContainerWrapper extends StatefulWidget {
  const DynamicContainerWrapper({
    super.key,
    required this.child,
    this.isNavBarShowed = false,
    this.isWaveShowed = false,
    required this.topPadding, required this.navBarIndex, required this.onNavBarIndexChanged,
  });

  final Widget child;
  final bool isNavBarShowed;
  final bool isWaveShowed;
  final double topPadding;
  final int navBarIndex;
  final ValueChanged<int> onNavBarIndexChanged;

  @override
  State<DynamicContainerWrapper> createState() =>
      _DynamicContainerWrapperState();
}

class _DynamicContainerWrapperState extends State<DynamicContainerWrapper>
    with TickerProviderStateMixin {
  bool _showContent = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showContent = true);
    });
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

        return Stack(
          children: [
            // Подложка контента
            Padding(
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
              ),
            ),

            // Контент
            Positioned.fill(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: _showContent ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(child: widget.child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
