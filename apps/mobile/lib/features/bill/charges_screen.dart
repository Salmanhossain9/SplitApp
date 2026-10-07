import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_core/split_core.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../share/share_bills_sheet.dart';
import 'draft_bill_notifier.dart';

/// Screen 9: vat and service, how extras are split, whose bill is what, send bills.
class ChargesScreen extends ConsumerStatefulWidget {
  const ChargesScreen({super.key});

  @override
  ConsumerState<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends ConsumerState<ChargesScreen> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final result = await ref.read(draftBillProvider.notifier).sendBills();
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.ok) {
      // Send bills opens the share sheet, then moves on to settle up.
      await showShareBillsSheet(context);
      if (!mounted) return;
      context.pushReplacement('/bill/${ref.read(draftBillProvider).id}/settle');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.coral,
          content: Text(result.message ?? 'could not send the bills.', style: AppType.body16.copyWith(color: AppColors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftBillProvider);
    final n = ref.read(draftBillProvider.notifier);
    final result = d.result;
    final byItems = d.splitMode == SplitMode.items;

    final String extrasPill;
    if (!byItems || d.extrasMode == ExtrasMode.equally) {
      final count = d.participants.isEmpty ? 1 : d.participants.length;
      extrasPill = '${formatTaka(d.extras ~/ count)} extra each';
    } else {
      extrasPill = 'extras follow the order';
    }

    return ScreenFrame(
      header: Column(
        children: [
          AppTopBar(
            title: 'vat and service',
            trailing: const StepPill('final check'),
            onBack: () => context.pop(),
          ),
          const SizedBox(height: AppSpacing.s16),
          const StepperBar(current: 3),
        ],
      ),
      bottom: WideButton(
        label: 'send bills',
        variant: WideButtonVariant.done,
        enabled: result != null,
        loading: _sending,
        onPressed: _send,
      ),
      gap: AppSpacing.s24,
      children: [
        Text('how should we split the extras?', style: AppType.body16),
        if (byItems)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OptionTile(
                  title: 'equally',
                  subtitle: 'same extra for everyone',
                  on: d.extrasMode == ExtrasMode.equally,
                  onTap: () => n.setExtrasMode(ExtrasMode.equally),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: OptionTile(
                  title: 'by what they ate',
                  subtitle: 'bigger order, bigger share',
                  on: d.extrasMode == ExtrasMode.byItems,
                  onTap: () => n.setExtrasMode(ExtrasMode.byItems),
                ),
              ),
            ],
          )
        else
          Text(
            d.splitMode == SplitMode.equally
                ? 'you are splitting the whole bill equally, so the extras are already inside every share.'
                : 'you typed each share yourself, so the extras are already inside them.',
            style: AppType.label14.copyWith(color: AppColors.slate),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s24),
          decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
          child: Column(
            children: [
              _line('items subtotal', Money(d.subtotal, style: AppType.body16)),
              const SizedBox(height: AppSpacing.s12),
              ChargeRow(
                label: 'VAT',
                rateBp: d.vatRateBp,
                amount: d.vatAmount,
                onRateChanged: n.setVatRate,
                amountBuilder: (a) => Money(a, style: AppType.body16),
              ),
              const SizedBox(height: AppSpacing.s12),
              ChargeRow(
                label: 'Service charge',
                rateBp: d.serviceRateBp,
                amount: d.serviceAmount,
                onRateChanged: n.setServiceRate,
                amountBuilder: (a) => Money(a, style: AppType.body16),
              ),
              const SizedBox(height: AppSpacing.s16),
              _line('bill total', Money(d.total, style: AppType.title24)),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: Text('whose bill is what?', style: AppType.heading20)),
            AppPill(extrasPill, background: AppColors.lime),
          ],
        ),
        if (result != null)
          BillCardGrid(
            cards: [
              for (var i = 0; i < result.shares.length; i++)
                BillCard(
                  person: d.participants[i],
                  index: i,
                  total: result.shares[i].total,
                  itemsAmount: result.shares[i].itemsAmount,
                  extrasAmount: result.shares[i].extrasAmount,
                ),
            ],
          ),
        result != null
            ? ClaimedBanner(text: 'bills add up to ${formatTaka(result.total)}')
            : const ClaimedBanner(text: 'go back, the bills do not add up', variant: BannerVariant.error),
      ],
    );
  }

  Widget _line(String label, Widget value) => Row(
        children: [
          Expanded(child: Text(label, style: AppType.body16)),
          value,
        ],
      );
}
