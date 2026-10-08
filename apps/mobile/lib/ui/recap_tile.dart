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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
          const SizedBox(height: AppSpacing.s4),
          // One line, shrinking if it has to: "friends" must never break into "friend / s".
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1, style: AppType.label14.copyWith(color: AppColors.onColor(background))),
          ),
        ],
      ),
    );
  }
}
