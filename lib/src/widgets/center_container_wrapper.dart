import 'package:flutter/material.dart';

class CenterContainerWrapper extends StatefulWidget {
  const CenterContainerWrapper({
    super.key,
    required this.child,
    required this.topPadding,
    this.useScroll = false,
  });

  final Widget child;
  final double topPadding;
  final bool useScroll;

  @override
  State<CenterContainerWrapper> createState() => _CenterContainerWrapperState();
}

class _CenterContainerWrapperState extends State<CenterContainerWrapper>
    with TickerProviderStateMixin {
  bool _showContent = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = widget.topPadding;
    // final bottomInset = MediaQuery.of(context).padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        // final w = constraints.constrainWidth();
        // final rawMaxH = constraints.maxHeight;
        // final screenH = MediaQuery.of(context).size.height;
        // final h = rawMaxH.isFinite ? rawMaxH : (screenH - topPadding);

        return Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Align(
              alignment: Alignment.topCenter,
              child: widget.useScroll
                  ? SingleChildScrollView(child: widget.child)
                  : widget.child,
            ),
        );
      },
    );
  }
}
