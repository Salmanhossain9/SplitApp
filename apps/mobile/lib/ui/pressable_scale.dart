import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Every tappable thing scales to 0.96 on press.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Its own semantic node, so a screen reader announces "new bill, button" on its own and
    // not glued to the heading next to it.
    return Semantics(
      container: true,
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? AppMotion.pressScale : 1,
          duration: AppMotion.press,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
