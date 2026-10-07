import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../bill/bill_summary.dart';
import '../bill/bills_provider.dart';
import '../bill/remind.dart';

enum MoneyFilter { all, pending, tabs, settled }

extension on MoneyFilter {
  String get label => switch (this) {
        MoneyFilter.all => 'all',
        MoneyFilter.pending => 'pending',
        MoneyFilter.tabs => 'tabs',
        MoneyFilter.settled => 'settled',
      };

  bool matches(BillSummary b) => switch (this) {
        MoneyFilter.all => true,
        MoneyFilter.pending => b.pill == BillStatus.pending,
        MoneyFilter.tabs => b.pill == BillStatus.tab,
        MoneyFilter.settled => b.pill == BillStatus.settled,
      };
}

/// History: every sent bill grouped by month, the open tabs on top, simple filters.
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  MoneyFilter _filter = MoneyFilter.all;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final bills = ref.watch(billsProvider);
    final dash = ref.watch(dashboardProvider).value;
    final all = bills.value ?? const <BillSummary>[];
    final shown = all.where(_filter.matches).toList();

    // Group by (year, month), newest first (the list is already newest first).
    final groups = <String, List<BillSummary>>{};
    for (final b in shown) {
      final label = b.billedAt.year == now.year
          ? monthNames[b.billedAt.month - 1]
          : '${monthNames[b.billedAt.month - 1]} ${b.billedAt.year}';
      groups.putIfAbsent(label, () => []).add(b);
    }

    return ScreenFrame(
      reserveBottom: true,
      onRefresh: () => ref.refresh(billsProvider.future),
      gap: AppSpacing.s16,
      children: [
        Text('money', style: AppType.display36),
        if (dash != null && dash.tabs.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text('open tabs', style: AppType.heading20)),
              AppPill('${dash.tabs.length} open', background: AppColors.coral),
            ],
          ),
          for (final t in dash.tabs)
            TabCard(name: t.personName, amount: t.owed, onRemind: () => remindFriend(context, ref, t)),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in MoneyFilter.values) ...[
                NameChip(label: f.label, on: _filter == f, onTap: () => setState(() => _filter = f)),
                const SizedBox(width: AppSpacing.s8),
              ],
            ],
          ),
        ),
        if (bills.isLoading && !bills.hasValue)
          const Center(child: Sparkle())
        else if (shown.isEmpty)
          Text(
            all.isEmpty ? 'No bills yet. The first one you split shows up here.' : 'Nothing here.',
            style: AppType.body16.copyWith(color: AppColors.slate),
          )
        else
          for (final entry in groups.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: AppType.heading20),
                for (final (i, b) in entry.value.indexed) ...[
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
      ],
    );
  }
}
