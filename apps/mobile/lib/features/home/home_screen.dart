import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../bill/bill_summary.dart';
import '../bill/bills_provider.dart';
import '../bill/draft_bill.dart';
import '../bill/draft_bill_notifier.dart';
import '../bill/remind.dart';
import '../groups/groups_provider.dart';

/// Screens 2 and 12: one screen driven by data. After settling a bill the new bill sits on top
/// with a coral "tab" pill and the open tab shows as a lavender card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Pick up a half-finished bill that was saved when the app was closed.
    Future.microtask(() async {
      final draft = ref.read(draftBillProvider);
      if (draft.items.isEmpty && draft.place.isEmpty) {
        await ref.read(draftBillProvider.notifier).restore();
      }
    });
    // Warm the groups so the new bill screen opens instantly.
    ref.read(groupsProvider);
  }

  Future<void> _newBill() async {
    await ref.read(draftBillProvider.notifier).clear();
    if (mounted) context.push('/bill/new');
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final bills = ref.watch(billsProvider);
    final dash = ref.watch(dashboardProvider);
    final draft = ref.watch(draftBillProvider);

    final list = bills.value ?? const <BillSummary>[];
    final d = dash.value;
    final isNew = bills.hasValue && list.isEmpty;

    return ScreenFrame(
      reserveBottom: true,
      gap: AppSpacing.s24,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One line, shrinking if it has to ("good afternoon." is the longest).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(greetingFor(now), maxLines: 1, style: AppType.display36),
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                Expanded(child: Text('your splits', style: AppType.body16.copyWith(color: AppColors.slate))),
                NewBillPill(onTap: _newBill),
              ],
            ),
          ],
        ),
        if (isResumable(draft))
          _ResumeCard(
            place: draft.place,
            sent: draft.status == DraftStatus.open,
            onTap: () => context.push(resumeLocation(draft)),
          ),
        if (bills.isLoading && !bills.hasValue)
          const SizedBox(height: AppSize.banner, child: Center(child: Sparkle()))
        else if (bills.hasError && !bills.hasValue)
          ClaimedBanner(text: 'could not load your bills. pull to retry.', variant: BannerVariant.error)
        else if (isNew) ...[
          ActionTile(variant: ActionTileVariant.split, label: 'split a bill', onTap: _newBill),
          Text(
            'Split your first bill. Scan the receipt, tap who had what, done.',
            style: AppType.body16.copyWith(color: AppColors.slate),
          ),
        ] else if (d != null) ...[
          SummaryCard(
            label: 'this month',
            amount: d.monthTotal,
            caption: d.monthBills == 1 ? 'split across 1 bill' : 'split across ${d.monthBills} bills',
            settled: d.monthSettled,
            pending: d.monthPending,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(monthNames[list.first.billedAt.month - 1], style: AppType.heading20)),
                  PillButton(label: 'see all', onTap: () => StatefulNavigationShell.of(context).goBranch(1)),
                ],
              ),
              for (final (i, b) in list.take(5).indexed) ...[
                const SizedBox(height: AppSpacing.s12),
                BillRow(
                  name: b.place,
                  meta: billMeta(b),
                  amount: b.total,
                  status: b.pill,
                  avatarColor: const ['lavender', 'lime', 'sky'][i % 3],
                ),
              ],
            ],
          ),
          if (d.tabs.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('open tabs', style: AppType.heading20)),
                    AppPill('${d.tabs.length} open', background: AppColors.coral),
                  ],
                ),
                for (final t in d.tabs) ...[
                  const SizedBox(height: AppSpacing.s12),
                  TabCard(
                    name: t.personName,
                    amount: t.owed,
                    onRemind: () => remindFriend(context, ref, t),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.place, required this.sent, required this.onTap});
  final String place;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sent ? 'finish settling' : 'pick up where you left off', style: AppType.label14.copyWith(color: AppColors.slate)),
                Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.heading20),
              ],
            ),
          ),
          PillButton(label: 'continue', onTap: onTap, background: AppColors.lavender),
        ],
      ),
    );
  }
}
