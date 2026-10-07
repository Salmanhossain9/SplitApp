import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

enum WideButtonVariant { primary, photo, upload, next, done, home, another }

class _Look {
  const _Look(this.bg, this.fg, this.circle, this.glyph, this.icon);
  final Color bg;
  final Color fg;
  final Color circle;
  final Color glyph;
  final AppIcons icon;
}

const _looks = {
  WideButtonVariant.primary:
      _Look(AppColors.navy, AppColors.white, AppColors.lime, AppColors.navy, AppIcons.scan),
  WideButtonVariant.photo:
      _Look(AppColors.lavender, AppColors.white, AppColors.lime, AppColors.lavender, AppIcons.camera),
  WideButtonVariant.upload:
      _Look(AppColors.lime, AppColors.navy, AppColors.lavender, AppColors.white, AppIcons.gallery),
  WideButtonVariant.next:
      _Look(AppColors.navy, AppColors.white, AppColors.lime, AppColors.navy, AppIcons.chevronRight),
  WideButtonVariant.done:
      _Look(AppColors.lavender, AppColors.white, AppColors.lime, AppColors.lavender, AppIcons.check),
  WideButtonVariant.home:
      _Look(AppColors.lime, AppColors.navy, AppColors.lavender, AppColors.white, AppIcons.home),
  WideButtonVariant.another:
      _Look(AppColors.navy, AppColors.white, AppColors.lime, AppColors.navy, AppIcons.plus),
};

/// Full width, 64 tall, label left and a 40 circle icon button on the right.
class WideButton extends StatelessWidget {
  const WideButton({
    super.key,
    required this.label,
    required this.variant,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final WideButtonVariant variant;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final look = _looks[variant]!;
    final active = enabled && onPressed != null && !loading;
    // Disabled: flat slate block with white label, icon circle in cream.
    final bg = enabled ? look.bg : AppColors.slate;
    final fg = enabled ? look.fg : AppColors.white;
    final circle = enabled ? look.circle : AppColors.cream;
    final glyph = enabled ? look.glyph : AppColors.slate;
    return PressableScale(
      onTap: active ? onPressed : null,
      child: Container(
        height: AppSize.button,
        padding: const EdgeInsets.only(left: 28, right: AppSpacing.s12),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rFull),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.heading20.copyWith(color: fg),
              ),
            ),
            Container(
              width: AppSize.buttonIcon,
              height: AppSize.buttonIcon,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
              child: loading
                  ? SizedBox(
                      width: AppSize.icon / 2,
                      height: AppSize.icon / 2,
                      child: CircularProgressIndicator(strokeWidth: 3, color: glyph),
                    )
                  : AppIcon(look.icon, size: AppSize.icon - AppSpacing.s8, color: glyph, stroke: 3),
            ),
          ],
        ),
      ),
    );
  }
}
