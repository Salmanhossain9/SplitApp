import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

/// Flat pill: lavender step pill, settled/pending status pills, "remind", and so on.
class AppPill extends StatelessWidget {
  const AppPill(
    this.label, {
    super.key,
    required this.background,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 6),
    this.style,
  });

  final String label;
  final Color background;
  final Color? foreground;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.rFull),
      child: Padding(
        padding: padding,
        child: Text(
          label,
          style: (style ?? AppType.micro12).copyWith(
            color: foreground ?? AppColors.onColor(background),
          ),
        ),
      ),
    );
  }
}

/// "step 2 of 3", "final check", "last step".
class StepPill extends StatelessWidget {
  const StepPill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) =>
      AppPill(label, background: AppColors.lavender, foreground: AppColors.white);
}

enum BillStatus { settled, pending, tab }

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});
  final BillStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (text, bg) = switch (status) {
      BillStatus.settled => ('settled', AppColors.lime),
      BillStatus.pending => ('pending', AppColors.coral),
      BillStatus.tab => ('tab', AppColors.coral),
    };
    return AppPill(
      label ?? text,
      background: bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.s4),
    );
  }
}

/// Small tappable pill, optionally with a leading round icon. "remind", currency, "new bill".
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.background = AppColors.lime,
    this.icon,
    this.iconBackground,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 10),
    this.trailingIcon = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final AppIcons? icon;
  final Color? iconBackground;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onColor(background);
    final glyph = icon == null
        ? null
        : AppIcon(icon!, size: AppDims.plusGlyph, color: iconColor ?? fg, stroke: 3.2);
    return PressableScale(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: AppRadius.rFull),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null && !trailingIcon) ...[
                _IconDot(background: iconBackground, child: glyph),
                const SizedBox(width: AppSpacing.s8),
              ],
              Text(label, style: AppType.label14.copyWith(color: fg)),
              if (glyph != null && trailingIcon) ...[
                const SizedBox(width: AppSpacing.s8),
                glyph,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconDot extends StatelessWidget {
  const _IconDot({required this.child, this.background});
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    if (background == null) return child;
    return Container(
      width: AppSize.icon - AppSpacing.s4,
      height: AppSize.icon - AppSpacing.s4,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: child,
    );
  }
}

/// "new bill" pill on the home screen: lavender, white label, lime plus.
class NewBillPill extends StatelessWidget {
  const NewBillPill({super.key, required this.onTap, this.label = 'new bill'});
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) => PillButton(
        label: label,
        onTap: onTap,
        background: AppColors.lavender,
        icon: AppIcons.plus,
        iconColor: AppColors.lime,
      );
}
