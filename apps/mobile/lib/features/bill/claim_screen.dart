import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_core/split_core.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import 'draft_bill.dart';
import 'draft_bill_notifier.dart';

/// With this many people or more, items are claimed in a bottom sheet (screen 6).
const sheetClaimThreshold = 5;

ClaimMode _toClaimMode(SplitMode m) => ClaimMode.values.byName(m.name);
SplitMode _toSplitMode(ClaimMode m) => SplitMode.values.byName(m.name);

/// Screens 5, 6, 7 and 8: the mode switch decides which body shows.
class ClaimScreen extends ConsumerStatefulWidget {
  const ClaimScreen({super.key});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    // Screen 6: with 5+ people the sheet opens on the first unclaimed item.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoOpened) return;
      _autoOpened = true;
      final d = ref.read(draftBillProvider);
      if (d.splitMode == SplitMode.items && d.participants.length >= sheetClaimThreshold) {
        _openNextUnclaimed();
      }
    });
  }

  void _openNextUnclaimed({String? after}) {
    final d = ref.read(draftBillProvider);
    final unclaimed = unclaimedItemIds(d.splitItems, d.claimLists);
    if (unclaimed.isEmpty) return;
    final order = d.items.map((i) => i.id).toList();
    final start = after == null ? -1 : order.indexOf(after);
    final next = unclaimed.firstWhere(
      (id) => order.indexOf(id) > start,
      orElse: () => unclaimed.first,
    );
    _openSheet(next);
  }

  Future<void> _openSheet(String itemId) async {
    final done = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => _ItemSheet(itemId: itemId),
    );
    if (done == true && mounted) _openNextUnclaimed(after: itemId);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftBillProvider);
    final n = ref.read(draftBillProvider.notifier);
    final body = switch (d.splitMode) {
      SplitMode.items => _itemsBody(d, n),
      SplitMode.equally => _equallyBody(d, n),
      SplitMode.custom => _customBody(d, n),
    };

    return ScreenFrame(
      header: Column(
        children: [
          AppTopBar(
            title: 'who had what?',
            trailing: const StepPill('step 3 of 3'),
            onBack: () => context.pop(),
          ),
          const SizedBox(height: AppSpacing.s16),
          const StepperBar(current: 3),
          const SizedBox(height: AppSpacing.s16),
          ModeSwitch(
            selected: _toClaimMode(d.splitMode),
            onChanged: (m) => n.setSplitMode(_toSplitMode(m)),
          ),
        ],
      ),
      bottom: WideButton(
        label: 'vat and service charge',
        variant: WideButtonVariant.next,
        enabled: d.claimStepValid,
        onPressed: () => context.push('/bill/${d.id}/charges'),
      ),
      children: body,
    );
  }

  List<Widget> _itemsBody(DraftBill d, DraftBillNotifier n) {
    final sheetMode = d.participants.length >= sheetClaimThreshold;
    return [
      if (sheetMode)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('who had what?', style: AppType.display36),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${d.claimedCount} of ${d.items.length} items assigned',
              style: AppType.micro12.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: AppSpacing.s12),
            ProgressSplitBar(
              done: d.claimedCount,
              pending: d.items.length - d.claimedCount,
              pendingColor: AppColors.slate.withValues(alpha: AppOpacity.stepNext),
            ),
          ],
        )
      else
        ClaimedBanner(
          text: d.allClaimed ? 'every item is claimed' : '${d.claimedCount} of ${d.items.length} items assigned',
        ),
      for (final item in d.items)
        ItemCard(
          key: ValueKey(item.id),
          name: item.name,
          qty: item.qty,
          lineTotal: item.lineTotal,
          people: d.participants,
          claimedIds: d.claims[item.id] ?? const {},
          onToggle: sheetMode ? null : (p) => n.toggleClaim(item.id, p.id),
          onTapCard: sheetMode ? () => _openSheet(item.id) : null,
        ),
    ];
  }

  List<Widget> _equallyBody(DraftBill d, DraftBillNotifier n) {
    final sharing = d.sharing;
    final each = sharing.isEmpty ? 0 : splitEqually(d.total, sharing.length).first;
    return [
      Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('total bill', style: AppType.title24)),
                const AppPill('incl. vat and service', background: AppColors.lime),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Money(d.total, style: AppType.amount44, lightDecimals: true, fit: true),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('who is sharing?', style: AppType.body16)),
              AppPill('${sharing.length} ${sharing.length == 1 ? 'person' : 'people'}', background: AppColors.lime),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in d.participants) ...[
                  AvatarChip(
                    person: p,
                    selected: sharing.contains(p.id),
                    onTap: () => n.toggleSharing(p.id),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                ],
              ],
            ),
          ),
        ],
      ),
      Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: const BoxDecoration(color: AppColors.lavender, borderRadius: AppRadius.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('each pays', style: AppType.title24.copyWith(color: AppColors.white))),
                AppPill('${formatTaka(d.total)} ÷ ${sharing.length}', background: AppColors.lime),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Money(each, style: AppType.amount44, color: AppColors.white, lightDecimals: true, fit: true),
          ],
        ),
      ),
    ];
  }

  List<Widget> _customBody(DraftBill d, DraftBillNotifier n) {
    final diff = d.customDifference;
    final exact = diff == 0 && d.total > 0;
    final hasEmpty = d.participantIds.any((id) => (d.customAmounts[id] ?? 0) == 0);
    return [
      ClaimedBanner(
        text: exact
            ? '${formatTaka(d.customAssigned)} of ${formatTaka(d.total)} assigned'
            : diff > 0
                ? '${formatTaka(diff)} left'
                : '${formatTaka(-diff)} over',
        variant: exact ? BannerVariant.ok : BannerVariant.error,
      ),
      for (final p in d.participants)
        CustomRow(
          key: ValueKey(p.id),
          person: p,
          poisha: d.customAmounts[p.id] ?? 0,
          onChanged: (v) => n.setCustomAmount(p.id, v),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: LinkButton(
          label: 'split the rest equally',
          onTap: diff > 0 && hasEmpty ? n.splitRestEqually : null,
        ),
      ),
    ];
  }
}

/// Screen 6 bottom sheet: pick who shared one item.
class _ItemSheet extends ConsumerWidget {
  const _ItemSheet({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(draftBillProvider);
    final n = ref.read(draftBillProvider.notifier);
    final item = d.items.firstWhere((i) => i.id == itemId);
    final claimed = d.claims[itemId] ?? const <String>{};
    final claimants = [for (final p in d.participants) if (claimed.contains(p.id)) p];
    final parts = claimants.isEmpty ? <int>[] : splitEqually(item.lineTotal, claimants.length);
    final eachText = claimants.isEmpty
        ? 'tap names to share it'
        : '${claimants.length} ${claimants.length == 1 ? 'person' : 'people'} · ${formatTaka(parts.first)} each';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.name, style: AppType.body16),
        const SizedBox(height: AppSpacing.s4),
        Money(item.lineTotal, style: AppType.display36),
        const SizedBox(height: AppSpacing.s16),
        Text('who shared this?', style: AppType.body16),
        const SizedBox(height: AppSpacing.s12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in d.participants) ...[
                AvatarChip(
                  person: p,
                  selected: claimed.contains(p.id),
                  onTap: () => n.toggleClaim(itemId, p.id),
                ),
                const SizedBox(width: AppSpacing.s8),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        SplitBar(parts: parts, labelBuilder: (part) => Money(part, style: AppType.body16)),
        const SizedBox(height: AppSpacing.s8),
        Center(child: Text(eachText, style: AppType.micro12.copyWith(color: AppColors.slate))),
        const SizedBox(height: AppSpacing.s24),
        WideButton(
          label: 'done',
          variant: WideButtonVariant.done,
          enabled: claimed.isNotEmpty,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
