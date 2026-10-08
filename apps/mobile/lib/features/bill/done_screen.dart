import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Bumped to play the celebration again (tap the badge).
  int _round = 0;

  @override
  void initState() {
    super.initState();
    // A tap you can feel, as the badge pops in.
    Future<void>.delayed(
      const Duration(milliseconds: 280),
      HapticFeedback.heavyImpact,
    );
  }

  void _replay() {
    HapticFeedback.mediumImpact();
    setState(() => _round++);
  }

  /// A tile that springs in after [ms], one after another.
  Widget _pop(int ms, Widget child) => SpringValue(
    key: ValueKey(_round == 0 ? 'pop$ms' : 'pop$ms-$_round'),
    initial: 0,
    target: 1,
    delay: Duration(milliseconds: ms),
    builder: (context, v) =>
        Transform.scale(scale: v.clamp(0.0, 1.15), child: child),
  );

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

    final tabs = [
      for (final f in d.friends)
        if (d.entryOf(f.id).owed > 0) f,
    ];
    final tabTotal = tabs.fold(0, (a, f) => a + d.entryOf(f.id).owed);
    final people = d.participants.length;
    final tabText = tabs.length == 1
        ? "${tabs.first.name}'s ${formatTaka(tabTotal)} is saved on your tab"
        : '${tabs.length} tabs worth ${formatTaka(tabTotal)} are saved on your tab';

    // A short or narrow phone: everything has to fit above the two buttons without scrolling.
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final compact = size.height / textScale < 800 || size.width < 340;
    final badge = compact ? 0.62 : 1.0;
    final gap = compact ? AppSpacing.s12 : AppSpacing.s24;

    Future<void> leave(String location) async {
      _leaving = true;
      await ref.read(draftBillProvider.notifier).clear();
      if (context.mounted) context.go(location);
    }

    return Stack(
      children: [
        ScreenFrame(
          background: AppColors.lavender,
          gap: gap,
          bottomHeight: AppSize.button * 2 + AppSpacing.s12,
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WideButton(
                label: 'back to home',
                variant: WideButtonVariant.home,
                onPressed: () => leave('/home'),
              ),
              const SizedBox(height: AppSpacing.s12),
              WideButton(
                label: 'split another bill',
                variant: WideButtonVariant.another,
                onPressed: () => leave('/bill/new'),
              ),
            ],
          ),
          children: [
            if (!compact) const SizedBox(height: AppSpacing.s16),
            Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(
                  left: 0,
                  top: 0,
                  child: Sparkle(size: AppSize.icon, color: AppColors.lime),
                ),
                const Positioned(
                  right: AppSpacing.s16,
                  top: AppSpacing.s24,
                  child: Sparkle(
                    size: AppSize.icon + AppSpacing.s8,
                    color: AppColors.white,
                    delay: Duration(milliseconds: 500),
                  ),
                ),
                const Positioned(
                  left: AppSpacing.s32,
                  bottom: 0,
                  child: Sparkle(
                    size: AppSize.icon - AppSpacing.s8,
                    color: AppColors.white,
                    delay: Duration(milliseconds: 900),
                  ),
                ),
                // The badge: lime check on a 20% white halo, popping in with a spring.
                SpringValue(
                  key: ValueKey('badge$_round'),
                  initial: 0,
                  target: 1,
                  delay: const Duration(milliseconds: 250),
                  builder: (context, scale) => GestureDetector(
                    key: const ValueKey('badge'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _replay,
                    child: Transform.scale(
                      scale: scale.clamp(0, 1.4),
                      child: Container(
                        width: AppSize.avatarChip * 3 * badge,
                        height: AppSize.avatarChip * 3 * badge,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(
                            alpha: AppOpacity.halo,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: AppSize.avatarChip * 2 * badge,
                          height: AppSize.avatarChip * 2 * badge,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                          child: AppIcon(
                            AppIcons.check,
                            size: AppSize.avatarChip * badge,
                            color: AppColors.lavender,
                            stroke: 3.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'all settled.',
                style: (compact ? AppType.amount56 : AppType.celebrate72).copyWith(color: AppColors.white),
              ),
            ),
            Text(
              '${d.place} is done. $people friends, ${formatTaka(d.total)} and zero awkward.',
              style: (compact ? AppType.body16 : AppType.heading20).copyWith(color: AppColors.white),
            ),
            if (tabs.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppPill(
                    tabText,
                    background: AppColors.lime,
                    style: AppType.label14,
                  ),
                ),
              ),
            // Three tiles of one height; not IntrinsicHeight, which let one wrapped label stretch them.
            SizedBox(
              height: (compact ? AppDims.recapTileCompact : AppDims.recapTile) * textScale,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _pop(
                      600,
                      RecapTile(
                        value: Money(d.total, style: AppType.title24),
                        label: 'split',
                        background: AppColors.sky,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _pop(
                      720,
                      RecapTile(
                        value: Text(
                          '$people',
                          style: AppType.title24.copyWith(
                            fontWeight: AppFonts.bold,
                          ),
                        ),
                        label: 'friends',
                        background: AppColors.lime,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _pop(
                      840,
                      RecapTile(
                        value: Text(
                          '${tabs.length}',
                          style: AppType.title24.copyWith(
                            fontWeight: AppFonts.bold,
                          ),
                        ),
                        label: tabs.length == 1 ? 'open tab' : 'open tabs',
                        background: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned.fill(child: ConfettiLayer(key: ValueKey('confetti$_round'))),
      ],
    );
  }
}
