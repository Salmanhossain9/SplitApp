import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A number with a label under it ("৳2,236 / split", "4 / friends", "1 / open tab").
class RecapTile extends StatelessWidget {
  const RecapTile({super.key, required this.value, required this.label, required this.background});

  /// Usually a [Money] or a bold [Text].
  final Widget value;
  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
          const SizedBox(height: AppSpacing.s4),
          Text(label, style: AppType.label14.copyWith(color: AppColors.onColor(background))),
        ],
      ),
    );
  }
}
