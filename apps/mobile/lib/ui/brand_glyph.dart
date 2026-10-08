import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum Brand { apple, google }

/// The Apple and Google marks for the sign-in buttons, drawn in code (no image files). Flat colour
/// only; Google keeps its four brand colours.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph(this.brand, {super.key, this.size = AppSize.icon, this.color = AppColors.navy});

  final Brand brand;
  final double size;

  /// The Apple mark's colour (the Google mark always uses its own).
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: brand == Brand.apple ? _ApplePainter(color) : _GooglePainter(),
      );
}

class _ApplePainter extends CustomPainter {
  _ApplePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final fill = Paint()..color = color;
    // Drawn a little small on its grid: scale it up about the centre.
    canvas.translate(12, 12);
    canvas.scale(1.3);
    canvas.translate(-12, -12.6);
    // The apple: two shoulders, a bite out of the right side, a little leaf.
    final body = Path()
      ..moveTo(12, 8.2)
      ..cubicTo(10.6, 7.1, 8.1, 7.4, 6.8, 9.5)
      ..cubicTo(5.3, 11.9, 6.2, 16.2, 8.1, 18.8)
      ..cubicTo(8.9, 19.9, 10.0, 20.8, 11.2, 20.3)
      ..cubicTo(11.7, 20.1, 11.9, 20.0, 12, 20.0)
      ..cubicTo(12.1, 20.0, 12.3, 20.1, 12.8, 20.3)
      ..cubicTo(14.0, 20.8, 15.1, 19.9, 15.9, 18.8)
      ..cubicTo(16.6, 17.8, 17.1, 16.8, 17.4, 15.8)
      ..cubicTo(15.7, 15.0, 15.3, 12.3, 17.1, 10.9)
      ..cubicTo(16.5, 9.0, 14.4, 7.6, 12, 8.2)
      ..close();
    canvas.drawPath(body, fill);
    canvas.save();
    canvas.translate(13.6, 5.2);
    canvas.rotate(-0.75);
    canvas.drawOval(const Rect.fromLTWH(-1.1, -2.7, 2.2, 5.4), fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ApplePainter old) => old.color != color;
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    const c = Offset(12, 12);
    const r = 7.6;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.butt;
    void arc(Color color, double fromDeg, double sweepDeg) {
      ring.color = color;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), fromDeg * math.pi / 180, sweepDeg * math.pi / 180, false, ring);
    }

    arc(AppColors.googleRed, 222, 96); // top
    arc(AppColors.googleYellow, 132, 90); // left
    arc(AppColors.googleGreen, 42, 90); // bottom
    arc(AppColors.googleBlue, -2, 44); // lower right
    // The bar of the G.
    canvas.drawRect(
      const Rect.fromLTWH(12, 9.9, 9.4, 4.2),
      Paint()..color = AppColors.googleBlue,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
