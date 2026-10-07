import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/widgets/avatar.dart';
import 'package:splitup/core/widgets/pressable.dart';

class PersonChip extends StatelessWidget {
  const PersonChip({
    super.key,
    required this.name,
    required this.avatarColor,
    required this.isHere,
    required this.onTap,
  });

  static const double width = 68;
  // name (16) + gap (6) + tallest pill (96), plus room for the spring overshoot.
  static const double height = 124;

  final String name;
  final Color avatarColor;
  final bool isHere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isHere ? 1 : 0.55,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.micro12,
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: width,
                height: isHere ? 96 : 68,
                decoration: BoxDecoration(
                  color: isHere
                      ? AppColors.lavender
                      : AppColors.lavender.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Avatar(
                        letter: name[0].toUpperCase(),
                        color: avatarColor,
                        size: 60,
                        ringColor: AppColors.lime,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: AnimatedOpacity(
                        opacity: isHere ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 20,
                          color: AppColors.lime,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}