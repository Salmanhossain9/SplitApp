import 'package:flutter/material.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/widgets/pressable.dart';

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    this.icon = Icons.add,
    this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: AppSpacing.s4),
            Text(label, style: AppText.label14.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }
}