import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/core/widgets/avatar.dart';
import 'package:splitup/core/widgets/pill_tag.dart';

void main() {
  runApp(const SplitupApp());
}

class SplitupApp extends StatelessWidget {
  const SplitupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'PlusJakartaSans',
        scaffoldBackgroundColor: AppColors.cream,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.lavender)
            .copyWith(onSurface: AppColors.navy),
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(
                    letter: 'Y',
                    color: AppColors.lavender,
                    ringColor: AppColors.lime,
                  ),
                  SizedBox(width: AppSpacing.s8),
                  Avatar(
                    letter: 'R',
                    color: AppColors.coral,
                    ringColor: AppColors.lime,
                  ),
                  SizedBox(width: AppSpacing.s8),
                  Avatar(letter: 'N', color: AppColors.sky),
                  SizedBox(width: AppSpacing.s8),
                  Avatar(letter: 'T', color: AppColors.lime, size: 36),
                ],
              ),
              SizedBox(height: AppSpacing.s16),
              PillTag(
                label: 'settled',
                backgroundColor: AppColors.lime,
              ),
            ],
          ),
        ),
      ),
    );
  }
}