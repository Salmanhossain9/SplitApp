import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: Container(
        width: AppSize.backButton,
        height: AppSize.backButton,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
        child: const AppIcon(
          AppIcons.chevronLeft,
          size: AppDims.chevronGlyph,
          color: AppColors.white,
          stroke: 3,
        ),
      ),
    );
  }
}

/// Three step progress bar. Done and current are lavender, next is slate at 30%.
class StepperBar extends StatelessWidget {
  const StepperBar({super.key, required this.current, this.steps = 3});

  /// 1-based.
  final int current;
  final int steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= steps; i++) ...[
          if (i > 1) const SizedBox(width: AppDims.stepGap),
          Expanded(
            child: Container(
              height: AppSize.stepper,
              decoration: BoxDecoration(
                color: i <= current
                    ? AppColors.lavender
                    : AppColors.slate.withValues(alpha: AppOpacity.stepNext),
                borderRadius: BorderRadius.circular(AppDims.stepSegmentRadius),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Back left, centered title, optional trailing (step pill) right.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, this.title, this.trailing, this.onBack, this.showBack = true});

  final String? title;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    if (trailing != null) {
      // The title cannot be centred on the screen when a pill sits on the right: it takes the
      // space between the back button and the pill and shrinks before it would be covered.
      return SizedBox(
        height: AppSize.topBar,
        child: Row(
          children: [
            if (showBack) AppBackButton(onTap: onBack),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text(title!, style: AppType.heading20)),
                    ),
            ),
            trailing!,
          ],
        ),
      );
    }
    return SizedBox(
      height: AppSize.topBar,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null) Center(child: Text(title!, style: AppType.heading20)),
          if (showBack) Align(alignment: Alignment.centerLeft, child: AppBackButton(onTap: onBack)),
        ],
      ),
    );
  }
}

/// 28 mark (lavender + lime half circles) and the wordmark.
class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size.square(AppDims.logoMark),
          painter: _LogoMarkPainter(),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text('splitup', style: AppType.wordmark22),
      ],
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(rect, 1.5708, 3.14159, true, Paint()..color = AppColors.lavender);
    canvas.drawArc(rect, -1.5708, 3.14159, true, Paint()..color = AppColors.lime);
  }

  @override
  bool shouldRepaint(_LogoMarkPainter old) => false;
}
