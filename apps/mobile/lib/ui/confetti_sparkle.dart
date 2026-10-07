import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';

/// Four point star that twinkles (scale + opacity loop).
class Sparkle extends StatefulWidget {
  const Sparkle({
    super.key,
    this.size = AppSize.icon,
    this.color = AppColors.lime,
    this.delay = Duration.zero,
  });

  final double size;
  final Color color;
  final Duration delay;

  @override
  State<Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<Sparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: 0.55 + 0.45 * curve.value,
        child: Transform.scale(
          scale: 0.8 + 0.3 * curve.value,
          child: AppIcon(AppIcons.sparkle, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.45,
        speed = 0.55 + r.nextDouble() * 0.45,
        sway = 6 + r.nextDouble() * 24,
        phase = r.nextDouble() * math.pi * 2,
        spin = (r.nextDouble() - 0.5) * 10,
        w = 8 + r.nextDouble() * 10,
        h = 6 + r.nextDouble() * 12,
        round = r.nextBool(),
        color = _colors[r.nextInt(_colors.length)];

  static const _colors = [AppColors.lime, AppColors.lavender, AppColors.coral, AppColors.white];
  final double x, delay, speed, sway, phase, spin, w, h;
  final bool round;
  final Color color;
}

/// Flat confetti dropping once. Lime, lavender, coral and white pieces. No shadows.
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({super.key, this.pieces = 60, this.seed = 7});
  final int pieces;
  final int seed;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();
  late final List<_Piece> _pieces = () {
    final r = math.Random(widget.seed);
    return List.generate(widget.pieces, (_) => _Piece(r));
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final prog = ((t - p.delay) / (1 - p.delay) * p.speed + (t > p.delay ? 0 : 0)).clamp(0.0, 1.0);
      if (t <= p.delay) continue;
      final y = -20 + prog * (size.height + 40);
      final x = p.x * size.width + math.sin(prog * 6 + p.phase) * p.sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(prog * p.spin);
      final paint = Paint()..color = p.color;
      final rect = Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(p.round ? p.w : 2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
