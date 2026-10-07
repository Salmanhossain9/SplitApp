import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';

/// Floating navy pill: home, money, notifications, settings.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.index,
    required this.onTap,
    this.unreadNotifications = false,
  });

  final int index;
  final ValueChanged<int> onTap;
  final bool unreadNotifications;

  static const _icons = [
    AppIcons.home,
    AppIcons.dollarCoin,
    AppIcons.bell,
    AppIcons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSize.navHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.navy, borderRadius: AppRadius.rFull),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < _icons.length; i++)
            PressableScale(
              onTap: () => onTap(i),
              child: SizedBox(
                width: AppSize.navSlot,
                height: AppSize.navSlot,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (i == index && i == 1)
                      Container(
                        width: AppDims.navActiveCircle,
                        height: AppDims.navActiveCircle,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    AppIcon(
                      _icons[i],
                      color: i == index
                          ? (i == 1 ? AppColors.navy : AppColors.white)
                          : AppColors.slate,
                    ),
                    if (i == 2 && unreadNotifications)
                      Positioned(
                        top: AppSpacing.s8,
                        right: AppSpacing.s8,
                        child: Container(
                          width: AppDims.dot,
                          height: AppDims.dot,
                          decoration: const BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
