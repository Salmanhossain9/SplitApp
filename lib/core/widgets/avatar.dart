import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.letter,
    required this.color,
    this.size = 48,
    this.ringColor,
    this.ringWidth = 4,
  });

  final String letter;
  final Color color;
  final double size;
  final Color? ringColor;
  final double ringWidth;

  // Spec: white text on lavender and coral, navy text on everything else.
  Color get _textColor =>
      (color == AppColors.lavender || color == AppColors.coral)
          ? AppColors.white
          : AppColors.navy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: ringWidth),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
    );
  }
}