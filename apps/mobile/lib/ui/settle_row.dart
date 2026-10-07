import 'package:flutter/material.dart';

import '../core/person.dart';
import '../theme/tokens.dart';
import 'app_icon.dart';
import 'avatar.dart';
import 'money.dart';
import 'pills.dart';
import 'pressable_scale.dart';
import 'selectors.dart';

enum SettleMethod { cash, bkash, bank, owesMe }

extension SettleMethodLabel on SettleMethod {
  String get label => switch (this) {
        SettleMethod.cash => 'cash',
        SettleMethod.bkash => 'bKash',
        SettleMethod.bank => 'bank',
        SettleMethod.owesMe => 'owes me',
      };
}

/// Host cover control: a stepper (steps of 50 taka) and a caption.
class CoverControl {
  const CoverControl({
    required this.covered,
    required this.caption,
    required this.onMinus,
    required this.onPlus,
  });

  final int covered;
  final String caption;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
}

class _StepperCircle extends StatelessWidget {
  const _StepperCircle({required this.icon, required this.onTap});
  final AppIcons icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: AppDims.stepperCircle,
        height: AppDims.stepperCircle,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.slate : AppColors.lavender,
          shape: BoxShape.circle,
        ),
        child: AppIcon(icon, size: AppDims.chevronGlyph, color: AppColors.white, stroke: 3.4),
      ),
    );
  }
}

class SettleRow extends StatelessWidget {
  const SettleRow({
    super.key,
    required this.person,
    required this.amount,
    required this.method,
    required this.onMethod,
    this.cover,
  });

  final Person person;
  final int amount;

  /// null = nothing picked yet (pending).
  final SettleMethod? method;
  final ValueChanged<SettleMethod> onMethod;
  final CoverControl? cover;

  @override
  Widget build(BuildContext context) {
    final owes = method == SettleMethod.owesMe;
    final paid = method != null && !owes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: person.name, color: avatarColorOf(person.avatarColor), size: AppSize.avatarSettle),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: Text(person.name, style: AppType.heading20)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Money(amount, style: AppType.heading20),
                  const SizedBox(height: 2),
                  AppPill(
                    paid ? 'paid' : owes ? 'owes me' : 'pending',
                    background: paid ? AppColors.lime : AppColors.coral,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.s4),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in SettleMethod.values)
                NameChip(
                  label: m.label,
                  on: method == m,
                  horizontalPadding: AppSpacing.s12,
                  onTap: () => onMethod(m),
                ),
            ],
          ),
          if (cover != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: const BoxDecoration(color: AppColors.cream, borderRadius: AppRadius.rMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('you cover', style: AppType.body16)),
                      _StepperCircle(icon: AppIcons.minus, onTap: cover!.onMinus),
                      SizedBox(
                        width: AppDims.amountFieldWidth - AppSpacing.s24,
                        child: Center(child: Money(cover!.covered, style: AppType.heading20)),
                      ),
                      _StepperCircle(icon: AppIcons.plus, onTap: cover!.onPlus),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(cover!.caption, style: AppType.label14.copyWith(color: AppColors.slate)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
