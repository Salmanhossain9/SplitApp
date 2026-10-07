import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
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

  void _scanComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'receipt scanning is coming soon. add items by hand for now.',
          style: AppType.body16.copyWith(color: AppColors.white),
        ),
        backgroundColor: AppColors.navy,
      ),
    );
    setState(() => _tab = ItemsTab.manual);
    _ensureOneRow();
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
      bottom: WideButton(
        label: 'who had what?',
        variant: WideButtonVariant.next,
        enabled: _tab == ItemsTab.manual && draft.itemsStepValid,
        onPressed: () => context.push('/bill/${draft.id}/claim'),
      ),
      children: _tab == ItemsTab.scan
          ? [
              const ReceiptViewfinder(),
              Center(
                child: Text(
                  'place the receipt inside the frame',
                  style: AppType.label14.copyWith(color: AppColors.slate),
                ),
              ),
              WideButton(label: 'take photo', variant: WideButtonVariant.photo, onPressed: _scanComingSoon),
              WideButton(label: 'upload from photos', variant: WideButtonVariant.upload, onPressed: _scanComingSoon),
            ]
          : [
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
  const _ConfirmCard({required this.confirmed, required this.onToggle});
  final bool confirmed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Row(
        children: [
          Expanded(child: Text('does this match your receipt?', style: AppType.body16)),
          NameChip(label: confirmed ? 'yes' : 'not yet', on: confirmed, onTap: onToggle),
        ],
      ),
    );
  }
}
