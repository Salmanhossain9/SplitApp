import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/core/widgets/pressable.dart';

class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.navy,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          size: 24,
          color: AppColors.white,
        ),
      ),
    );
  }
}