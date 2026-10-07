import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';

/// Screen 1: the logged out landing page.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      header: const Align(alignment: Alignment.centerLeft, child: Logo()),
      gap: AppSpacing.s24,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WideButton(
            label: 'split a bill',
            variant: WideButtonVariant.start,
            onPressed: () => context.go('/auth/email'),
          ),
          const SizedBox(height: AppSpacing.s12),
          WideButton(
            label: 'log in / sign up',
            variant: WideButtonVariant.login,
            onPressed: () => context.go('/auth/email'),
          ),
        ],
      ),
      children: [
        const SizedBox(height: AppSpacing.s16),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text('split it. skip the awkward.', style: AppType.hero50),
            const Positioned(
              right: 0,
              top: -AppSpacing.s24,
              child: Sparkle(size: AppSize.icon + AppSpacing.s8, color: AppColors.lavender),
            ),
          ],
        ),
        Text(
          'Scan the receipt, tap who had what and settle in cash or bKash. No math, no awkward.',
          style: AppType.body16.copyWith(color: AppColors.slate),
        ),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StepTile(
                number: 1,
                label: 'scan',
                icon: AppIcons.scan,
                background: AppColors.lavender,
                accent: AppColors.lime,
              ),
            ),
            SizedBox(width: AppSpacing.s12),
            Expanded(
              child: StepTile(
                number: 2,
                label: 'claim',
                icon: AppIcons.check,
                background: AppColors.lime,
                accent: AppColors.lavender,
              ),
            ),
            SizedBox(width: AppSpacing.s12),
            Expanded(
              child: StepTile(
                number: 3,
                label: 'settle',
                icon: AppIcons.dollarCoin,
                background: AppColors.sky,
                accent: AppColors.lavender,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
