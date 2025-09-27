import 'package:flutter/material.dart';

class SwipeSwitcher extends StatefulWidget {
  final bool showDevices;
  final Duration duration;
  final double slideDistance; // fraction of width (0.08 = 8%)
  final Curve inCurve;
  final Curve outCurve;
  final Curve fadeCurve;
  final EdgeInsetsGeometry edgePadding;
  final List<Widget> devicesWidgets;
  final List<Widget> participantsWidgets;

  const SwipeSwitcher({
    super.key,
    required this.showDevices,
    required this.devicesWidgets,
    required this.participantsWidgets,
    this.duration = const Duration(milliseconds: 360),
    this.slideDistance = 0.08,
    this.inCurve = Curves.easeOut,
    this.outCurve = Curves.easeIn,
    this.fadeCurve = Curves.linear,
    this.edgePadding = const EdgeInsets.symmetric(horizontal: 36.0),
  });

  @override
  State<SwipeSwitcher> createState() => _SwipeSwitcherState();
}

class _SwipeSwitcherState extends State<SwipeSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // виджет, который уехал, оставляем пока в стеке во время анимации
  Widget? _prevChild;
  bool _isAnimating = false;
  late bool _prevShowDevices;

  @override
  void initState() {
    super.initState();
    _prevShowDevices = widget.showDevices;
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // после окончания убираем предыдущий child
          setState(() {
            _prevChild = null;
            _isAnimating = false;
            _prevShowDevices = widget.showDevices;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant SwipeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    // если состояние сменилось — запускаем анимацию:
    if (widget.showDevices != _prevShowDevices) {
      // запоминаем текущее отображаемое как _prevChild, чтобы его анимировать наружу
      _prevChild = _buildCurrentChild(oldWidget.showDevices);
      _isAnimating = true;
      // restart animation
      _ctrl.stop();
      _ctrl.value = 0.0;
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildCurrentChild(bool showDevicesState) {
    final child = showDevicesState
        ? Column(
            key: const ValueKey('devices'),
            mainAxisSize: MainAxisSize.min,
            children: widget.devicesWidgets,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 43.0),
            child: Column(
              key: const ValueKey('participants'),
              mainAxisSize: MainAxisSize.min,
              children: widget.participantsWidgets,
            ),
          );
    // KeyedSubtree сохраняет ключ и структуру при переносе в стек
    return KeyedSubtree(key: child.key, child: child);
  }

  @override
  Widget build(BuildContext context) {
    // текущий видимый child
    final Widget currentChild = _buildCurrentChild(widget.showDevices);

    // dir: при showDevices == true хотим participants уехать влево, devices прийти справа:
    // dir == -1 -> outgoing end offset = -slideDistance (влево), incoming begin = +slideDistance (справа)
    final double dir = widget.showDevices ? 1.0 : -1.0;

    // таймлайны: outgoing — 0.0..0.5, incoming — 0.5..1.0
    final Animation<double> outPos =
        Tween<double>(begin: 0.0, end: dir * widget.slideDistance).animate(
            CurvedAnimation(
                parent: _ctrl,
                curve: Interval(0.0, 0.5, curve: widget.outCurve)));
    final Animation<double> outOpacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Interval(0.0, 0.5, curve: widget.fadeCurve)));

    final Animation<double> inPos =
        Tween<double>(begin: -dir * widget.slideDistance, end: 0.0).animate(
            CurvedAnimation(
                parent: _ctrl,
                curve: Interval(0.5, 1.0, curve: widget.inCurve)));
    final Animation<double> inOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Interval(0.5, 1.0, curve: widget.fadeCurve)));

    // Если не анимируем — просто показываем текущий child (без стека)
    if (_prevChild == null || !_isAnimating) {
      return Padding(
        padding: widget.edgePadding,
        child: ClipRect(
          child: SizedBox(width: double.infinity, child: currentChild),
        ),
      );
    }

    // Во время анимации рендерим оба: prev (outgoing) и current (incoming).
    // Положим incoming поверх, чтобы он скрывал предыдущий при появлении.
    return Padding(
      padding: widget.edgePadding,
      child: ClipRect(
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // outgoing (предыдущий) — управляем через AnimatedBuilder
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                        outPos.value * MediaQuery.of(context).size.width, 0),
                    child: Opacity(opacity: outOpacity.value, child: child),
                  );
                },
                child: _prevChild ?? SizedBox(),
              ),

              // incoming (текущий) — появляется в 2-й половине
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                        inPos.value * MediaQuery.of(context).size.width, 0),
                    child: Opacity(opacity: inOpacity.value, child: child),
                  );
                },
                child: currentChild,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
