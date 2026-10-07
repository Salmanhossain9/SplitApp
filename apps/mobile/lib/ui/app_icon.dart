import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum AppIcons {
  home,
  dollarCoin,
  bell,
  settings,
  chevronLeft,
  chevronRight,
  chevronUp,
  chevronDown,
  plus,
  minus,
  check,
  camera,
  gallery,
  scan,
  arrowUpRight,
  arrowDownLeft,
  sparkle,
}

/// Chunky icon drawn on a 24 x 24 grid with round caps and joins.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = AppSize.icon,
    this.color = AppColors.navy,
    this.stroke = 2.8,
  });

  final AppIcons icon;
  final double size;
  final Color color;

  /// Stroke width on the 24 grid (spec: 2.4 to 3.6; the big action arrows use more).
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(icon, color, stroke),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.stroke);

  final AppIcons icon;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Path poly(List<double> p, {bool close = false}) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      if (close) path.close();
      return path;
    }

    switch (icon) {
      case AppIcons.home:
        final house = Path()
          ..moveTo(4, 11)
          ..lineTo(12, 4)
          ..lineTo(20, 11)
          ..lineTo(20, 18)
          ..arcToPoint(const Offset(18, 20), radius: const Radius.circular(2))
          ..lineTo(6, 20)
          ..arcToPoint(const Offset(4, 18), radius: const Radius.circular(2))
          ..close();
        canvas.drawPath(house, line);
        canvas.drawLine(const Offset(12, 20), const Offset(12, 14.5), line);
      case AppIcons.dollarCoin:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        final s = Path()
          ..moveTo(14.8, 9.6)
          ..cubicTo(14.8, 8.3, 13.6, 7.8, 12, 7.8)
          ..cubicTo(10.5, 7.8, 9.2, 8.5, 9.2, 9.8)
          ..cubicTo(9.2, 11.4, 11, 11.7, 12, 12)
          ..cubicTo(13, 12.3, 14.8, 12.6, 14.8, 14.2)
          ..cubicTo(14.8, 15.5, 13.5, 16.2, 12, 16.2)
          ..cubicTo(10.4, 16.2, 9.2, 15.7, 9.2, 14.4);
        canvas.drawPath(s, line);
        canvas.drawLine(const Offset(12, 6), const Offset(12, 7.8), line);
        canvas.drawLine(const Offset(12, 16.2), const Offset(12, 18), line);
      case AppIcons.bell:
        final bell = Path()
          ..moveTo(6, 16.5)
          ..lineTo(6, 11)
          ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
          ..lineTo(18, 16.5)
          ..lineTo(19.5, 18)
          ..lineTo(4.5, 18)
          ..close();
        canvas.drawPath(bell, line);
        final clapper = Path()
          ..moveTo(10, 20.8)
          ..arcToPoint(const Offset(14, 20.8), radius: const Radius.circular(2), clockwise: false);
        canvas.drawPath(clapper, line);
      case AppIcons.settings:
        canvas.drawCircle(const Offset(12, 12), 6.4, line);
        canvas.drawCircle(const Offset(12, 12), 2.2, fill);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final from = Offset(12 + math.cos(a) * 8.2, 12 + math.sin(a) * 8.2);
          final to = Offset(12 + math.cos(a) * 10.2, 12 + math.sin(a) * 10.2);
          canvas.drawLine(from, to, line);
        }
      case AppIcons.chevronLeft:
        canvas.drawPath(poly([15, 5, 8, 12, 15, 19]), line);
      case AppIcons.chevronRight:
        canvas.drawPath(poly([9, 5, 16, 12, 9, 19]), line);
      case AppIcons.chevronUp:
        canvas.drawPath(poly([5, 15, 12, 8, 19, 15]), line);
      case AppIcons.chevronDown:
        canvas.drawPath(poly([5, 9, 12, 16, 19, 9]), line);
      case AppIcons.plus:
        canvas.drawLine(const Offset(12, 4.5), const Offset(12, 19.5), line);
        canvas.drawLine(const Offset(4.5, 12), const Offset(19.5, 12), line);
      case AppIcons.minus:
        canvas.drawLine(const Offset(4.5, 12), const Offset(19.5, 12), line);
      case AppIcons.check:
        canvas.drawPath(poly([4.5, 12.5, 9.8, 17.8, 19.5, 6.8]), line);
      case AppIcons.camera:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 7, 18, 13),
          const Radius.circular(4),
        );
        canvas.drawRRect(body, line);
        canvas.drawPath(poly([8, 7, 9.5, 4, 14.5, 4, 16, 7]), line);
        canvas.drawCircle(const Offset(12, 13.5), 3.4, line);
      case AppIcons.gallery:
        final frame = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 4, 18, 16),
          const Radius.circular(4),
        );
        canvas.drawRRect(frame, line);
        canvas.drawPath(poly([3.5, 16.5, 9, 11, 13, 15, 15.5, 12.5, 20.5, 17.5]), line);
        canvas.drawCircle(const Offset(16.5, 8.5), 1.6, fill);
      case AppIcons.scan:
        canvas.drawPath(poly([4, 9, 4, 5.5, 5.5, 4, 9, 4]), line);
        canvas.drawPath(poly([15, 4, 18.5, 4, 20, 5.5, 20, 9]), line);
        canvas.drawPath(poly([20, 15, 20, 18.5, 18.5, 20, 15, 20]), line);
        canvas.drawPath(poly([9, 20, 5.5, 20, 4, 18.5, 4, 15]), line);
        canvas.drawLine(const Offset(7.5, 12), const Offset(16.5, 12), line);
      case AppIcons.arrowUpRight:
        canvas.drawLine(const Offset(6, 18), const Offset(18, 6), line);
        canvas.drawPath(poly([8.5, 6, 18, 6, 18, 15.5]), line);
      case AppIcons.arrowDownLeft:
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), line);
        canvas.drawPath(poly([15.5, 18, 6, 18, 6, 8.5]), line);
      case AppIcons.sparkle:
        // Four point star with concave sides, filled.
        final star = Path()
          ..moveTo(12, 1.5)
          ..quadraticBezierTo(13.2, 10.8, 22.5, 12)
          ..quadraticBezierTo(13.2, 13.2, 12, 22.5)
          ..quadraticBezierTo(10.8, 13.2, 1.5, 12)
          ..quadraticBezierTo(10.8, 10.8, 12, 1.5)
          ..close();
        canvas.drawPath(star, fill);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.stroke != stroke;
}
