import 'package:flutter/material.dart';
import 'package:split_core/split_core.dart';

import '../theme/tokens.dart';

/// Renders poisha as text. Whole taka is Bold; the decimals optionally drop to Regular
/// (`৳412` Bold + `.50` Regular on the big amounts).
class Money extends StatelessWidget {
  const Money(
    this.poisha, {
    super.key,
    required this.style,
    this.color,
    this.forceDecimals = false,
    this.lightDecimals = false,
    this.textAlign,
  });

  final int poisha;
  final TextStyle style;
  final Color? color;
  final bool forceDecimals;
  final bool lightDecimals;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final parts = moneyParts(poisha, forceDecimals: forceDecimals);
    final base = style.copyWith(color: color ?? style.color);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${parts.negative ? '-' : ''}$takaSign${parts.whole}',
            style: base.copyWith(fontWeight: AppFonts.bold),
          ),
          if (parts.decimals.isNotEmpty)
            TextSpan(
              text: parts.decimals,
              style: base.copyWith(
                fontWeight: lightDecimals ? AppFonts.regular : AppFonts.bold,
              ),
            ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
