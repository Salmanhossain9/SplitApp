import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/person.dart';
import '../theme/tokens.dart';
import 'app_icon.dart';
import 'avatar.dart';
import 'pressable_scale.dart';

/// Pill that toggles between cream/slate (off) and lavender/white (on) in about 150 ms.
class NameChip extends StatelessWidget {
  const NameChip({
    super.key,
    required this.label,
    required this.on,
    this.onTap,
    this.horizontalPadding = AppSpacing.s16,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: AppMotion.chip,
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 9),
        decoration: BoxDecoration(
          color: on ? AppColors.lavender : AppColors.cream,
          borderRadius: AppRadius.rFull,
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.chip,
          style: AppType.label14.copyWith(color: on ? AppColors.white : AppColors.slate),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Name above a lime-ringed avatar. Selected grows (spring-like) into a lavender pill
/// with a lime chevron under the avatar. Away dims to 55%.
class AvatarChip extends StatelessWidget {
  const AvatarChip({
    super.key,
    required this.person,
    required this.selected,
    this.onTap,
  });

  final Person person;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: SizedBox(
        width: AppSize.chipWidth,
        child: Opacity(
          opacity: selected ? 1 : AppOpacity.awayChip,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.micro12,
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                width: AppSize.chipWidth,
                height: selected ? AppDims.selectedChipHeight : AppSize.chipWidth,
                decoration: BoxDecoration(
                  color: selected ? AppColors.lavender : AppColors.clear,
                  borderRadius: AppRadius.rFull,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Avatar(
                        name: person.name,
                        // A lime avatar would vanish inside its own lime ring.
                        color: avatarColorOf(person.avatarColor) == AppColors.lime
                            ? AppColors.lavender
                            : avatarColorOf(person.avatarColor),
                        size: AppSize.chipWidth,
                        ringColor: AppColors.lime,
                        ringWidth: AppSize.avatarRing,
                      ),
                    ),
                    Positioned(
                      bottom: AppSpacing.s4,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: AppMotion.chip,
                        opacity: selected ? 1 : 0,
                        child: const Center(
                          child: AppIcon(
                            AppIcons.chevronUp,
                            size: AppDims.chevronGlyph + AppSpacing.s4,
                            color: AppColors.lime,
                            stroke: 3.4,
                          ),
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

class AddFriendButton extends StatelessWidget {
  const AddFriendButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: AppSize.addFriend,
        height: AppSize.addFriend,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.slate.withValues(alpha: AppOpacity.addFriend),
          shape: BoxShape.circle,
        ),
        child: const AppIcon(
          AppIcons.plus,
          size: AppDims.plusGlyph,
          color: AppColors.white,
          stroke: 3.4,
        ),
      ),
    );
  }
}

/// White pill, 56 tall, padding 4, gap 4. Active segment is filled with [activeColor].
class PillSwitch<T> extends StatelessWidget {
  const PillSwitch({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.activeColor,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSize.tabSwitch,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rFull),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: PressableScale(
                onTap: () => onChanged(options[i].$1),
                child: AnimatedContainer(
                  duration: AppMotion.chip,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: options[i].$1 == selected ? activeColor : AppColors.clear,
                    borderRadius: AppRadius.rFull,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.chip,
                    style: AppType.body16.copyWith(
                      color: options[i].$1 == selected ? AppColors.white : AppColors.navy,
                    ),
                    child: Text(options[i].$2, maxLines: 1),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum ItemsTab { scan, manual }

/// "scan receipt" / "add manually". Active tab is navy.
class TabSwitch extends StatelessWidget {
  const TabSwitch({super.key, required this.selected, required this.onChanged});
  final ItemsTab selected;
  final ValueChanged<ItemsTab> onChanged;

  @override
  Widget build(BuildContext context) => PillSwitch<ItemsTab>(
        options: const [(ItemsTab.scan, 'scan receipt'), (ItemsTab.manual, 'add manually')],
        selected: selected,
        onChanged: onChanged,
        activeColor: AppColors.navy,
      );
}

enum ClaimMode { items, equally, custom }

/// Order is always: by items, equally, custom.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key, required this.selected, required this.onChanged});
  final ClaimMode selected;
  final ValueChanged<ClaimMode> onChanged;

  @override
  Widget build(BuildContext context) => PillSwitch<ClaimMode>(
        options: const [
          (ClaimMode.items, 'by items'),
          (ClaimMode.equally, 'equally'),
          (ClaimMode.custom, 'custom'),
        ],
        selected: selected,
        onChanged: onChanged,
        activeColor: AppColors.lavender,
      );
}

/// `on` lavender/white, `off` white/navy.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.on,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? AppColors.white : AppColors.navy;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.chip,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: on ? AppColors.lavender : AppColors.white,
          borderRadius: AppRadius.rLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppType.body16.copyWith(color: fg, fontWeight: AppFonts.bold)),
            const SizedBox(height: AppSpacing.s4),
            Text(subtitle, style: AppType.micro12.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
