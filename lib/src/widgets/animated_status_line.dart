import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:provider/provider.dart';
import 'package:wave/models/call_state.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class AnimatedStatusLine extends StatefulWidget {
  const AnimatedStatusLine({super.key});

  @override
  State<AnimatedStatusLine> createState() => _AnimatedStatusLineState();
}

class _AnimatedStatusLineState extends State<AnimatedStatusLine>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 30000),
    );

    _animationController.value = 1.0;
    _animationController.reverse();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WebRTCManager manager = Provider.of<WebRTCManager>(context);

    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                // старые экраны остаются и плавно исчезают
                ...previousChildren,
                // новый экран накладывается
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: _buildLine(manager.callState),
        );
      },
    );
  }

  Widget _buildLine(CallState callState) {
    switch (callState) {
      case CallState.connected:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            color: MdColors.positiveColor,
            thickness: 1,
            height: 1,
          ),
        );
      case CallState.connecting:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final Animation<double> widthAnimation = CurvedAnimation(
                parent: _animationController,
                curve: Curves.linear,
              );

              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return _animationController.value == 0
                      ? Divider(
                          color: MdColors.negativeColor,
                          thickness: 1,
                          height: 1,
                        )
                      : TweenAnimationBuilder<Color?>(
                          tween: ColorTween(
                            begin: MdColors.subtitleColor,
                            end: MdColors.darkBrandColor,
                          ),
                          duration: const Duration(milliseconds: 30000),
                          builder: (context, color, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width:
                                    constraints.maxWidth * widthAnimation.value,
                                height: 1,
                                color: color,
                              ),
                            );
                          },
                        );
                },
              );
            },
          ),
        );
      case CallState.failed:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            color: MdColors.negativeColor,
            thickness: 1,
            height: 1,
          ),
        );
      case CallState.disconnected:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            color: MdColors.disabledColor,
            thickness: 1,
            height: 1,
          ),
        );
    }
  }
}
