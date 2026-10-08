import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../bill/draft_bill_notifier.dart';
import 'share_service.dart';

/// The picture friends get: the place, the total and one bill card per person.
class ShareImageCard extends StatelessWidget {
  const ShareImageCard({super.key, required this.place, required this.total, required this.cards});

  final String place;
  final int total;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Logo(),
          const SizedBox(height: AppSpacing.s16),
          Text(place, style: AppType.display36),
          Row(
            children: [
              Text('total ', style: AppType.body16.copyWith(color: AppColors.slate)),
              Money(total, style: AppType.body16),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          BillCardGrid(cards: cards),
        ],
      ),
    );
  }
}

/// Opens after "send bills": link, WhatsApp, or a picture of everyone's share. Returns when
/// the person is done (they can also just swipe it away).
Future<void> showShareBillsSheet(BuildContext context) {
  return showAppBottomSheet<void>(context: context, builder: (_) => const ShareBillsSheet());
}

class ShareBillsSheet extends ConsumerStatefulWidget {
  const ShareBillsSheet({super.key});

  @override
  ConsumerState<ShareBillsSheet> createState() => _ShareBillsSheetState();
}

class _ShareBillsSheetState extends ConsumerState<ShareBillsSheet> {
  final _imageKey = GlobalKey();
  String? _message;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftBillProvider);
    final result = d.result;
    final share = ref.read(shareServiceProvider);
    final text = shareMessage(d);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        if (mounted) setState(() => _message = null);
      } catch (_) {
        if (mounted) setState(() => _message = 'could not open sharing. copy the link instead.');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('bills sent.', style: AppType.display36),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'Friends do not need the app. The link shows each of them their share.',
          style: AppType.label14.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: AppSpacing.s16),
        if (result != null)
          ClipRRect(
            borderRadius: AppRadius.rLg,
            child: RepaintBoundary(
              key: _imageKey,
              child: ShareImageCard(
                place: d.place,
                total: d.total,
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
            ),
          ),
        const SizedBox(height: AppSpacing.s16),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            PillButton(
              label: 'send link',
              background: AppColors.lavender,
              icon: AppIcons.arrowUpRight,
              iconColor: AppColors.lime,
              onTap: () => run(() => share.shareText(text)),
            ),
            PillButton(
              label: 'whatsapp',
              onTap: () => run(() async {
                if (!await share.openWhatsapp(text)) throw StateError('whatsapp');
              }),
            ),
            PillButton(
              label: 'share as image',
              background: AppColors.white,
              onTap: () => run(() async {
                final png = await capturePng(_imageKey);
                await share.shareImage(png, text: text, fileName: 'splitbit-${d.place.trim().toLowerCase()}.png');
              }),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.s12),
          ClaimedBanner(text: _message!, variant: BannerVariant.error),
        ],
        const SizedBox(height: AppSpacing.s24),
        WideButton(
          label: 'settle up',
          variant: WideButtonVariant.next,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
