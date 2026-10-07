import 'package:flutter/material.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/widgets/pressable.dart';

class WideButton extends StatelessWidget {
  const WideButton({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.circleColor,
    required this.iconColor,
    this.onTap,
  });

  static const double height = 64;

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color circleColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.only(left: 28, right: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.heading20.copyWith(color: textColor),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }
}