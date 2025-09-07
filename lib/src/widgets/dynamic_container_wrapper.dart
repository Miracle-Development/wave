import 'package:flutter/material.dart';
import 'package:md_ui_kit/_core/colors.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:provider/provider.dart';
import 'package:wave/src/core/webrtc_manager.dart';

class DynamicContainerWrapper extends StatefulWidget {
  const DynamicContainerWrapper({
    super.key,
    required this.child,
    this.isNavBarShowed = false,
    this.isWaveShowed = false,
    required this.topPadding,
    required this.navBarIndex,
    required this.onNavBarIndexChanged,
    this.useScroll = true,
    required this.onSendButtonPressed,
    required this.controller,
  });

  final Widget child;
  final bool isNavBarShowed;
  final bool isWaveShowed;
  final double topPadding;
  final int navBarIndex;
  final ValueChanged<int> onNavBarIndexChanged;
  final bool useScroll;
  final VoidCallback onSendButtonPressed;
  final TextEditingController controller;

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
  void dispose() {
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

        final isChatTab = widget.navBarIndex == 1;
        WebRTCManager manager = Provider.of<WebRTCManager>(context);

        return Stack(
          children: [
            // Подложка контента
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: widget.isNavBarShowed
                    ? !isChatTab
                        ? h - 95
                        : h
                    : h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: widget.isNavBarShowed
                        ? Radius.circular(20)
                        : Radius.zero,
                    bottomRight: widget.isNavBarShowed
                        ? Radius.circular(20)
                        : Radius.zero,
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
                  child: widget.useScroll
                      ? SingleChildScrollView(child: widget.child)
                      : widget.child,
                ),
              ),
            ),

            // Навбар
            Offstage(
              offstage: !widget.isNavBarShowed,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 200),
                opacity: widget.isNavBarShowed ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isChatTab) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            color: MdColors.navBarContainerColor,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: widget.controller,
                                    decoration: const InputDecoration(
                                      hintText: 'Message',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: () => widget.onSendButtonPressed(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        height: 83,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft:
                                isChatTab ? Radius.zero : Radius.circular(20),
                            topRight:
                                isChatTab ? Radius.zero : Radius.circular(20),
                          ),
                          color: MdColors.navBarContainerColor,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 17,
                            bottom: 14,
                            left: 32,
                            right: 32,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 78,
                                child: WaveNavBarItem(
                                  icon: NavBarIconType.planet,
                                  label: 'Connection',
                                  selected: widget.navBarIndex == 0,
                                  onTap: () => widget.onNavBarIndexChanged(0),
                                ),
                              ),
                              SizedBox(
                                width: 78,
                                child: WaveNavBarItem(
                                  icon: NavBarIconType.chat,
                                  label: 'Chat',
                                  selected: widget.navBarIndex == 1,
                                  counter: manager.unread > 0 &&
                                          widget.navBarIndex != 1
                                      ? manager.unread
                                      : null,
                                  onTap: () => widget.onNavBarIndexChanged(1),
                                ),
                              ),
                              SizedBox(
                                width: 78,
                                child: WaveNavBarItem(
                                  icon: NavBarIconType.phone,
                                  label: 'Call',
                                  selected: widget.navBarIndex == 2,
                                  onTap: () => widget.onNavBarIndexChanged(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
