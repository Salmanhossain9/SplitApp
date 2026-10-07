import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A number that chases [target] like a spring, so it overshoots and settles instead of
/// easing. Used for the avatar chip growing into a pill and the success badge popping in.
/// Start from [initial] (after [delay]) to play an entrance.
class SpringValue extends StatefulWidget {
  const SpringValue({
    super.key,
    required this.target,
    required this.builder,
    this.initial,
    this.delay = Duration.zero,
    this.spring = const SpringDescription(mass: 1, stiffness: 320, damping: 17),
  });

  final double target;
  final double? initial;
  final Duration delay;
  final SpringDescription spring;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.initial ?? widget.target,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && widget.initial != widget.target) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _chase(widget.target);
      });
    }
  }

  @override
  void didUpdateWidget(SpringValue old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _chase(widget.target);
  }

  void _chase(double to) {
    _c.animateWith(SpringSimulation(widget.spring, _c.value, to, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
}
