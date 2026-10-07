import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_core/split_core.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'draft_bill.dart';
import 'draft_bill_notifier.dart';

/// Screen 10: tick off how each friend pays you back. Cash, bKash and bank are labels only.
class SettleScreen extends ConsumerWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(draftBillProvider);
    final n = ref.read(draftBillProvider.notifier);
    final summary = d.settleSummary;
    final friends = d.friends;
    final paidCount = friends.where((f) => d.entryOf(f.id).method != null && d.entryOf(f.id).owed == 0).length;
    final tabs = [for (final f in friends) if (d.entryOf(f.id).owed > 0) f];

    return ScreenFrame(
      header: AppTopBar(
        title: 'settle up',
        trailing: const StepPill('last step'),
        onBack: () => context.pop(),
      ),
      bottom: WideButton(
        label: 'finish bill',
        variant: WideButtonVariant.done,
        enabled: d.allFriendsSettled,
        onPressed: () {
          if (n.finishBill()) context.go('/home');
        },
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.place, style: AppType.display36),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'You paid ${formatTaka(d.total)} at the restaurant. Pick how each friend pays you back.',
              style: AppType.label14.copyWith(color: AppColors.slate),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s24),
          decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('collected', style: AppType.body16),
              const SizedBox(height: AppSpacing.s4),
              Money(summary.collected, style: AppType.amount56, lightDecimals: true),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'of ${formatTaka(summary.target)} . $paidCount of ${friends.length} paid',
                style: AppType.label14,
              ),
              const SizedBox(height: AppSpacing.s16),
              ProgressSplitBar(
                done: summary.collected,
                pending: summary.target - summary.collected,
              ),
              if (summary.openTabs > 0) ...[
                const SizedBox(height: AppSpacing.s12),
                AppPill(
                  '${formatTaka(summary.openTabs)} owed to you',
                  background: AppColors.coral,
                  style: AppType.label14,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
                ),
              ],
            ],
          ),
        ),
        for (final f in friends)
          SettleRow(
            key: ValueKey(f.id),
            person: f,
            amount: d.shareOf(f.id),
            method: d.entryOf(f.id).method,
            onMethod: (m) => n.setMethod(f.id, m),
            cover: d.entryOf(f.id).method == SettleMethod.owesMe
                ? _cover(d, n, f.id, f.name)
                : null,
          ),
        if (tabs.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text('open tabs', style: AppType.heading20)),
              AppPill('${tabs.length} open', background: AppColors.coral),
            ],
          ),
          for (final f in tabs) TabCard(name: f.name, amount: d.entryOf(f.id).owed, onRemind: () {}),
        ],
      ],
    );
  }

  CoverControl _cover(DraftBill d, DraftBillNotifier n, String id, String name) {
    final share = d.shareOf(id);
    final owed = d.entryOf(id).owed;
    final paid = share - owed;
    return CoverControl(
      covered: owed,
      caption: paid > 0
          ? '$name owes you ${formatTaka(owed)}. The other ${formatTaka(paid)} is paid in cash.'
          : '$name owes you ${formatTaka(owed)}.',
      onMinus: owed > 0 ? () => n.setOwed(id, owed - AppDims.coverStep.toInt()) : null,
      onPlus: owed < share ? () => n.setOwed(id, owed + AppDims.coverStep.toInt()) : null,
      onChanged: (v) => n.setOwed(id, v),
    );
  }
}
