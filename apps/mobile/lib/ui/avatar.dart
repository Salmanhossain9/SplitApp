import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Maps the `avatar_color` column to a token.
Color avatarColorOf(String name) => switch (name) {
      'lime' => AppColors.lime,
      'sky' => AppColors.sky,
      'coral' => AppColors.coral,
      _ => AppColors.lavender,
    };

/// Circle with an initial. The chunky ring is the only stroke allowed in the app.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.color = AppColors.lavender,
    this.size = AppSize.avatarRow,
    this.ringColor,
    this.ringWidth = AppSize.avatarRing,
    this.opacity = 1,
  });

  /// Total diameter including the ring.
  final String name;
  final Color color;
  final double size;
  final Color? ringColor;
  final double ringWidth;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final inner = ringColor == null ? size : size - ringWidth * 2;
    final textStyle = size >= AppSize.avatarChip
        ? AppType.heading20
        : size >= AppSize.avatarRow
            ? AppType.body16
            : AppType.label14;
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: ringColor == null ? null : Border.all(color: ringColor!, width: ringWidth),
        ),
        child: SizedBox(
          width: inner,
          height: inner,
          child: Center(
            child: Text(
              letter,
              style: textStyle.copyWith(
                color: AppColors.onColor(color),
                fontWeight: AppFonts.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
