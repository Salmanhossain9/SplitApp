import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_core/split_core.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'draft_bill.dart';
import 'draft_bill_notifier.dart';

/// Screen 11: everyone has paid or is on a tab. Confetti, a check badge that pops in with a
/// spring on a soft white halo, and three recap tiles.
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key});

  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  /// Set while leaving on purpose: clearing the bill must not look like a stale link.
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftBillProvider);
    if (d.status != DraftStatus.settled && !_leaving) {
      // Nothing to celebrate (opened by a stale link): go home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(backgroundColor: AppColors.lavender);
    }

    final tabs = [for (final f in d.friends) if (d.entryOf(f.id).owed > 0) f];
    final tabTotal = tabs.fold(0, (a, f) => a + d.entryOf(f.id).owed);
    final people = d.participants.length;
    final tabText = tabs.length == 1
        ? "${tabs.first.name}'s ${formatTaka(tabTotal)} is saved on your tab"
        : '${tabs.length} tabs worth ${formatTaka(tabTotal)} are saved on your tab';

    Future<void> leave(String location) async {
      _leaving = true;
      await ref.read(draftBillProvider.notifier).clear();
      if (context.mounted) context.go(location);
    }

    return Stack(
      children: [
        ScreenFrame(
          background: AppColors.lavender,
          gap: AppSpacing.s24,
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WideButton(label: 'back to home', variant: WideButtonVariant.home, onPressed: () => leave('/home')),
              const SizedBox(height: AppSpacing.s12),
              WideButton(label: 'split another bill', variant: WideButtonVariant.another, onPressed: () => leave('/bill/new')),
            ],
          ),
          children: [
            const SizedBox(height: AppSpacing.s16),
            Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(left: 0, top: 0, child: Sparkle(size: AppSize.icon, color: AppColors.lime)),
                const Positioned(
                  right: AppSpacing.s16,
                  top: AppSpacing.s24,
                  child: Sparkle(size: AppSize.icon + AppSpacing.s8, color: AppColors.white, delay: Duration(milliseconds: 500)),
                ),
                const Positioned(
                  left: AppSpacing.s32,
                  bottom: 0,
                  child: Sparkle(size: AppSize.icon - AppSpacing.s8, color: AppColors.white, delay: Duration(milliseconds: 900)),
                ),
                // The badge: lime check on a 20% white halo, popping in with a spring.
                SpringValue(
                  initial: 0,
                  target: 1,
                  delay: const Duration(milliseconds: 250),
                  builder: (context, scale) => Transform.scale(
                    scale: scale.clamp(0, 1.4),
                    child: Container(
                      width: AppSize.avatarChip * 3,
                      height: AppSize.avatarChip * 3,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: AppOpacity.halo),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: AppSize.avatarChip * 2,
                        height: AppSize.avatarChip * 2,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                        child: const AppIcon(AppIcons.check, size: AppSize.avatarChip, color: AppColors.lavender, stroke: 3.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('all settled.', style: AppType.celebrate72.copyWith(color: AppColors.white)),
            ),
            Text(
              '${d.place} is done. $people friends, ${formatTaka(d.total)} and zero awkward.',
              style: AppType.heading20.copyWith(color: AppColors.white),
            ),
            if (tabs.isNotEmpty) Align(alignment: Alignment.centerLeft, child: AppPill(tabText, background: AppColors.lime, style: AppType.label14)),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RecapTile(
                      value: Money(d.total, style: AppType.title24),
                      label: 'split',
                      background: AppColors.sky,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: RecapTile(
                      value: Text('$people', style: AppType.title24.copyWith(fontWeight: AppFonts.bold)),
                      label: 'friends',
                      background: AppColors.lime,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: RecapTile(
                      value: Text('${tabs.length}', style: AppType.title24.copyWith(fontWeight: AppFonts.bold)),
                      label: tabs.length == 1 ? 'open tab' : 'open tabs',
                      background: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Positioned.fill(child: ConfettiLayer()),
      ],
    );
  }
}
