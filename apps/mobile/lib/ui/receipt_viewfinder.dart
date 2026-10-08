import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ReceiptLine {
  const ReceiptLine(this.name, this.price, {this.highlight = false});
  final String name;
  final String price;

  /// The total row: a lime bar with the amount in bold.
  final bool highlight;
}

const _sampleLines = [
  ReceiptLine('Chicken burger', '345'),
  ReceiptLine('Beef kala bhuna', '1,145'),
  ReceiptLine('Fries', '240'),
  ReceiptLine('Coke x3', '270'),
  ReceiptLine('VAT', '118'),
  ReceiptLine('Service', '118'),
  ReceiptLine('total', '৳2,236', highlight: true),
];

/// Navy frame with lime corner brackets, a paper receipt and a sweeping lavender scan line.
/// Pass [camera] to show a live preview inside the frame instead of the paper.
class ReceiptViewfinder extends StatefulWidget {
  const ReceiptViewfinder({
    super.key,
    this.scanning = false,
    this.camera,
    this.lines = _sampleLines,
    this.title = 'CHILLOX',
    this.dateLine = 'Sep 21 · 9:04 pm',
    this.height = AppDims.viewfinderHeight,
  });

  final bool scanning;
  final Widget? camera;
  final List<ReceiptLine> lines;
  final String title;
  final String dateLine;

  /// A shorter box on small screens, so the buttons under it show without scrolling.
  final double height;

  @override
  State<ReceiptViewfinder> createState() => _ReceiptViewfinderState();
}

class _ReceiptViewfinderState extends State<ReceiptViewfinder> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.scanning) _scan.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ReceiptViewfinder old) {
    super.didUpdateWidget(old);
    if (widget.scanning && !_scan.isAnimating) {
      _scan.repeat(reverse: true);
    } else if (!widget.scanning && _scan.isAnimating) {
      _scan.stop();
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.navy, borderRadius: AppRadius.rLg),
      child: Stack(
        children: [
          Positioned.fill(
            child: widget.camera ??
                Center(
                  // The sample receipt shrinks to fit a shorter box instead of overflowing.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                    width: AppDims.receiptPaperWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: AppSpacing.s16),
                    decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rSm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Text(widget.title, style: AppType.body16.copyWith(fontWeight: AppFonts.bold))),
                        Center(
                          child: Text(widget.dateLine, style: AppType.micro11.copyWith(color: AppColors.slate)),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        for (final l in widget.lines)
                          Padding(
                            padding: EdgeInsets.only(bottom: l.highlight ? 0 : AppSpacing.s8),
                            child: l.highlight
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                                    decoration: const BoxDecoration(color: AppColors.lime, borderRadius: AppRadius.rFull),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(l.name, style: AppType.micro12.copyWith(fontWeight: AppFonts.bold))),
                                        Text(l.price, style: AppType.micro12.copyWith(fontWeight: AppFonts.bold)),
                                      ],
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: Text(l.name, style: AppType.micro12, maxLines: 1)),
                                      Text(l.price, style: AppType.micro12),
                                    ],
                                  ),
                          ),
                      ],
                    ),
                  ),
                  ),
                ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: CustomPaint(painter: _BracketPainter()),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scan,
              builder: (context, _) {
                final range = widget.height - AppDims.scanLine - AppSpacing.s48;
                // Idle: parked a third of the way down like the design. Scanning: sweeping.
                final t = widget.scanning ? Curves.easeInOut.transform(_scan.value) : 0.25;
                return Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, AppSpacing.s24 + range * t),
                    child: Container(
                      height: AppDims.scanLine,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                      decoration: const BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: AppRadius.rFull,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppDims.bracketStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const b = AppDims.bracket;
    const r = AppSpacing.s16;
    final w = size.width, h = size.height;
    Path corner(double x, double y, double dx, double dy) => Path()
      ..moveTo(x, y + dy * b)
      ..lineTo(x, y + dy * r)
      ..quadraticBezierTo(x, y, x + dx * r, y)
      ..lineTo(x + dx * b, y);
    canvas.drawPath(corner(0, 0, 1, 1), p);
    canvas.drawPath(corner(w, 0, -1, 1), p);
    canvas.drawPath(corner(0, h, 1, -1), p);
    canvas.drawPath(corner(w, h, -1, -1), p);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}
