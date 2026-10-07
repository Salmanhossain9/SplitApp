import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';

class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor = AppColors.navy,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s12,
      vertical: 6,
    ),
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppText.micro12.copyWith(color: textColor),
      ),
    );
  }
}