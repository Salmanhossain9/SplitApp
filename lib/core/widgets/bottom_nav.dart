import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, this.selectedIndex = 0});

  static const double height = 64;

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavSlot(icon: Icons.home_rounded, selected: selectedIndex == 0),
          _NavSlot(
            glyph: '৳',
            selected: selectedIndex == 1,
            circleWhenSelected: true,
          ),
          _NavSlot(
            icon: Icons.notifications_rounded,
            selected: selectedIndex == 2,
            showDot: true,
          ),
          _NavSlot(icon: Icons.settings_rounded, selected: selectedIndex == 3),
        ],
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    this.icon,
    this.glyph,
    required this.selected,
    this.circleWhenSelected = false,
    this.showDot = false,
  });

  final IconData? icon;
  final String? glyph;
  final bool selected;
  final bool circleWhenSelected;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final inCircle = selected && circleWhenSelected;
    final color = inCircle
        ? AppColors.navy
        : (selected ? AppColors.white : AppColors.slate);

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (inCircle)
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            ),
          if (icon != null)
            Icon(icon, size: 28, color: color)
          else
            Text(
              glyph ?? '',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1,
                color: color,
              ),
            ),
          if (showDot)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}