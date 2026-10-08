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
          child: AppIcon(
            AppIcons.sparkle,
            size: widget.size,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

enum _Shape { pill, dot, squiggle, star }

/// One bit of confetti. "Burst" pieces fly out of the badge and then fall; the rest rain from
/// the top. All motion is a closed form of time, so a frame needs no state.
class _Piece {
  _Piece(math.Random r, {required this.burst})
    : shape = _Shape.values[r.nextInt(_Shape.values.length)],
      color = _colors[r.nextInt(_colors.length)],
      start = burst ? r.nextDouble() * 0.12 : 0.2 + r.nextDouble() * 1.4,
      angle = -math.pi * (0.05 + r.nextDouble() * 0.9), // Mostly upward, a fan.
      speed = 380 + r.nextDouble() * 520,
      x = r.nextDouble(),
      fall = 150 + r.nextDouble() * 170,
      sway = 6 + r.nextDouble() * 22,
      phase = r.nextDouble() * math.pi * 2,
      spin = (r.nextDouble() - 0.5) * 14,
      size = 9 + r.nextDouble() * 9;

  static const _colors = [
    AppColors.lime,
    AppColors.white,
    AppColors.coral,
    AppColors.sky,
    AppColors.cream,
  ];
  final bool burst;
  final _Shape shape;
  final Color color;
  final double start, angle, speed, x, fall, sway, phase, spin, size;
}

/// Flat confetti: a burst out of the check badge, then a light rain. Pills, dots, squiggles and
/// stars in the brand colours, about four seconds, no shadows.
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({
    super.key,
    this.burstPieces = 46,
    this.rainPieces = 34,
    this.seed = 7,
    this.origin = const Alignment(0, -0.6),
  });
  final int burstPieces;
  final int rainPieces;
  final int seed;

  /// Where the burst starts, as a fraction of the layer.
  final Alignment origin;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  static const _seconds = 4.2;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward();
  late final List<_Piece> _pieces = () {
    final r = math.Random(widget.seed);
    return [
      for (var i = 0; i < widget.burstPieces; i++) _Piece(r, burst: true),
      for (var i = 0; i < widget.rainPieces; i++) _Piece(r, burst: false),
    ];
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
          painter: _ConfettiPainter(
            _pieces,
            _c.value * _seconds,
            widget.origin,
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.seconds, this.origin);
  final List<_Piece> pieces;
  final double seconds;
  final Alignment origin;

  static const _drag = 1.5; // Burst pieces slow down this fast (per second).
  static const _gravity = 760.0;

  @override
  void paint(Canvas canvas, Size size) {
    final o = origin.alongSize(size);
    for (final p in pieces) {
      final t = seconds - p.start;
      if (t <= 0) continue;
      double x, y;
      if (p.burst) {
        // Air drag with gravity: slows sideways, settles into a steady fall.
        final decay = 1 - math.exp(-_drag * t);
        final terminal = _gravity / _drag;
        x =
            o.dx +
            p.speed * math.cos(p.angle) / _drag * decay +
            math.sin(t * 4 + p.phase) * p.sway * 0.4;
        y =
            o.dy +
            (p.speed * math.sin(p.angle) - terminal) / _drag * decay +
            terminal * t;
      } else {
        x = p.x * size.width + math.sin(t * 2.4 + p.phase) * p.sway;
        y = -24 + p.fall * t;
      }
      if (y > size.height + 30) continue;
      // Fade out over the last stretch of the run so nothing is cut off.
      final fade = ((_ConfettiLayerState._seconds - seconds) / 0.7).clamp(
        0.0,
        1.0,
      );
      final color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin);
      _draw(canvas, p, color);
      canvas.restore();
    }
  }

  void _draw(Canvas canvas, _Piece p, Color color) {
    final fill = Paint()..color = color;
    switch (p.shape) {
      case _Shape.pill:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.7,
              height: p.size * 0.6,
            ),
            Radius.circular(p.size),
          ),
          fill,
        );
      case _Shape.dot:
        canvas.drawCircle(Offset.zero, p.size * 0.4, fill);
      case _Shape.squiggle:
        final line = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.size * 0.28
          ..strokeCap = StrokeCap.round;
        final w = p.size * 1.8;
        final path = Path()..moveTo(-w / 2, 0);
        for (var i = 0; i < 3; i++) {
          final x0 = -w / 2 + w * i / 3;
          path.quadraticBezierTo(
            x0 + w / 12,
            i.isEven ? -p.size * 0.5 : p.size * 0.5,
            x0 + w / 6,
            0,
          );
          path.quadraticBezierTo(
            x0 + w / 4,
            i.isEven ? p.size * 0.5 : -p.size * 0.5,
            x0 + w / 3,
            0,
          );
        }
        canvas.drawPath(path, line);
      case _Shape.star:
        final r = p.size * 0.7;
        final path = Path()
          ..moveTo(0, -r)
          ..quadraticBezierTo(0, 0, r, 0)
          ..quadraticBezierTo(0, 0, 0, r)
          ..quadraticBezierTo(0, 0, -r, 0)
          ..quadraticBezierTo(0, 0, 0, -r)
          ..close();
        canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.seconds != seconds;
}
