import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';

/// Landing page explainer tile: "scan", "claim", "settle". A lime icon sits on a lavender tile
/// and a lavender icon on a lime tile.
class StepTile extends StatelessWidget {
  const StepTile({
    super.key,
    required this.number,
    required this.label,
    required this.icon,
    required this.background,
    required this.accent,
  });

  final int number;
  final String label;
  final AppIcons icon;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onColor(background);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: AppSize.icon + AppSpacing.s8, color: accent, stroke: 3.2),
          const SizedBox(height: AppSpacing.s24),
          Text('$number', style: AppType.micro12.copyWith(color: fg)),
          Text(label, style: AppType.heading20.copyWith(color: fg)),
        ],
      ),
    );
  }
}
