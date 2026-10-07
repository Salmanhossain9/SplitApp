import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../scan/scan_models.dart';
import '../scan/scan_tab.dart';
import 'draft_bill_notifier.dart';

/// Screen 4: add items by scanning (milestone 5) or by hand. Items stay editable.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  late ItemsTab _tab =
      ref.read(draftBillProvider).items.isEmpty ? ItemsTab.scan : ItemsTab.manual;

  int? _foundCount;

  void _onScanned(ScanResult result) {
    ref.read(draftBillProvider.notifier).applyScan(result);
    setState(() {
      _foundCount = result.items.length;
      _tab = ItemsTab.manual; // The editable list: the person confirms it before moving on.
    });
    if (result.items.isEmpty) _ensureOneRow();
  }

  void _ensureOneRow() {
    if (ref.read(draftBillProvider).items.isEmpty) {
      ref.read(draftBillProvider.notifier).addItem();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftBillProvider);
    final notifier = ref.read(draftBillProvider.notifier);

    return ScreenFrame(
      header: Column(
        children: [
          AppTopBar(
            title: 'add items',
            trailing: const StepPill('step 2 of 3'),
            onBack: () => context.pop(),
          ),
          const SizedBox(height: AppSpacing.s16),
          TabSwitch(
            selected: _tab,
            onChanged: (t) {
              setState(() => _tab = t);
              if (t == ItemsTab.manual) _ensureOneRow();
            },
          ),
        ],
      ),
      // Nothing to continue with until the items list is confirmed, so no button on the scan tab.
      bottom: _tab == ItemsTab.manual
          ? WideButton(
              label: 'who had what?',
              variant: WideButtonVariant.next,
              enabled: draft.itemsStepValid,
              onPressed: () => context.push('/bill/${draft.id}/claim'),
            )
          : null,
      children: _tab == ItemsTab.scan
          ? [ScanTab(onScanned: _onScanned)]
          : [
              if (_foundCount != null)
                ClaimedBanner(
                  text: _foundCount == 0
                      ? 'we could not find items. add them below.'
                      : 'found $_foundCount ${_foundCount == 1 ? 'item' : 'items'}. check them against the receipt.',
                  variant: _foundCount == 0 ? BannerVariant.error : BannerVariant.ok,
                ),
              for (final item in draft.items)
                ItemEditCard(
                  key: ValueKey(item.id),
                  name: item.name,
                  qty: item.qty,
                  unitPrice: item.unitPrice,
                  onName: (v) => notifier.updateItem(item.id, name: v),
                  onQty: (v) => notifier.updateItem(item.id, qty: v),
                  onUnitPrice: (v) => notifier.updateItem(item.id, unitPrice: v),
                  onDelete: () => notifier.removeItem(item.id),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  label: 'add item',
                  onTap: notifier.addItem,
                  background: AppColors.lavender,
                  icon: AppIcons.plus,
                  iconColor: AppColors.lime,
                ),
              ),
              _TotalsCard(subtotal: draft.subtotal),
              _ConfirmCard(
                confirmed: draft.itemsConfirmed,
                receiptTotal: draft.scannedTotal,
                ourTotal: draft.total,
                onToggle: () => notifier.setItemsConfirmed(!draft.itemsConfirmed),
              ),
            ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.subtotal});
  final int subtotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('items subtotal', style: AppType.body16),
          const SizedBox(height: AppSpacing.s4),
          Money(subtotal, style: AppType.amount56, lightDecimals: true),
          const SizedBox(height: AppSpacing.s4),
          Text('vat and service are added on the last step', style: AppType.label14),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.confirmed,
    required this.onToggle,
    required this.receiptTotal,
    required this.ourTotal,
  });

  final bool confirmed;
  final VoidCallback onToggle;

  /// What the scanner read as the receipt's total, if it saw one.
  final int? receiptTotal;

  /// Items plus vat and service at the current rates.
  final int ourTotal;

  @override
  Widget build(BuildContext context) {
    final matches = receiptTotal != null && receiptTotal == ourTotal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('does this match your receipt?', style: AppType.body16)),
              NameChip(label: confirmed ? 'yes' : 'not yet', on: confirmed, onTap: onToggle),
            ],
          ),
          if (receiptTotal != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Text('receipt total ', style: AppType.label14.copyWith(color: AppColors.slate)),
                Money(receiptTotal!, style: AppType.label14),
                Text('  .  ours ', style: AppType.label14.copyWith(color: AppColors.slate)),
                Money(ourTotal, style: AppType.label14),
                const Spacer(),
                AppPill(matches ? 'matches' : 'differs', background: matches ? AppColors.lime : AppColors.coral),
              ],
            ),
            if (!matches)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: Text(
                  'vat and service rates are set on the last step. fix any item that looks off.',
                  style: AppType.micro12.copyWith(color: AppColors.slate),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
