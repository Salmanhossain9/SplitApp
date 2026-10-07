import 'package:flutter/material.dart';

import '../core/person.dart';
import '../theme/tokens.dart';
import 'amount_field.dart';
import 'app_icon.dart';
import 'avatar.dart';
import 'money.dart';
import 'pills.dart';
import 'pressable_scale.dart';
import 'selectors.dart';

const _cardPadding = EdgeInsets.all(AppSpacing.s16);

/// Two-part progress bar. Lavender = settled, lime = pending.
class ProgressSplitBar extends StatelessWidget {
  const ProgressSplitBar({
    super.key,
    required this.done,
    required this.pending,
    this.doneColor = AppColors.lavender,
    this.pendingColor = AppColors.lime,
    this.trackColor = AppColors.white,
  });

  final int done;
  final int pending;
  final Color doneColor;
  final Color pendingColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDims.progressRadius),
      child: SizedBox(
        height: AppSize.progressBar,
        child: (done + pending) == 0
            ? ColoredBox(color: trackColor)
            : Row(
                children: [
                  if (done > 0) Expanded(flex: done, child: ColoredBox(color: doneColor)),
                  if (pending > 0) Expanded(flex: pending, child: ColoredBox(color: pendingColor)),
                ],
              ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, required this.poisha});
  final Color color;
  final String label;
  final int poisha;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppDims.dot,
          height: AppDims.dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text('$label ', style: AppType.label14),
        Money(poisha, style: AppType.label14),
      ],
    );
  }
}

/// Sky card: label, big amount, caption, settled vs pending bar and legend.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.caption,
    required this.settled,
    required this.pending,
  });

  final String label;
  final int amount;
  final String caption;
  final int settled;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.body16),
          const SizedBox(height: AppSpacing.s8),
          Money(amount, style: AppType.amount56, lightDecimals: true),
          const SizedBox(height: AppSpacing.s8),
          Text(caption, style: AppType.label14),
          const SizedBox(height: AppSpacing.s16),
          ProgressSplitBar(done: settled, pending: pending),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s4,
            children: [
              _LegendDot(color: AppColors.lavender, label: 'settled', poisha: settled),
              _LegendDot(color: AppColors.lime, label: 'pending', poisha: pending),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sky card "you are owed": title, big amount, currency pill, lime action pill.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.title,
    required this.amount,
    this.currency = 'BDT',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int amount;
  final String currency;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: const BoxDecoration(color: AppColors.sky, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.title24),
          const SizedBox(height: AppSpacing.s12),
          Money(amount, style: AppType.amount56, lightDecimals: true),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              PillButton(
                label: currency,
                onTap: null,
                background: AppColors.lavender,
                icon: AppIcons.chevronDown,
                trailingIcon: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 6),
              ),
              const Spacer(),
              if (actionLabel != null) PillButton(label: actionLabel!, onTap: onAction),
            ],
          ),
        ],
      ),
    );
  }
}

enum ActionTileVariant { split, request }

class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.variant, required this.label, this.onTap});

  final ActionTileVariant variant;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final split = variant == ActionTileVariant.split;
    final bg = split ? AppColors.lavender : AppColors.lime;
    final accent = split ? AppColors.lime : AppColors.lavender;
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: AppDims.actionTileHeight,
        padding: _cardPadding,
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              split ? AppIcons.arrowUpRight : AppIcons.arrowDownLeft,
              size: AppDims.actionArrow,
              color: accent,
              stroke: AppDims.actionArrowStroke / (AppDims.actionArrow / 24),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(label, style: AppType.heading20.copyWith(color: AppColors.onColor(bg))),
                ),
                Container(
                  width: AppDims.actionChevronButton,
                  height: AppDims.actionChevronButton,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: AppIcon(
                    AppIcons.chevronRight,
                    size: AppDims.chevronGlyph,
                    color: bg,
                    stroke: 3.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BillRow extends StatelessWidget {
  const BillRow({
    super.key,
    required this.name,
    required this.meta,
    required this.amount,
    required this.status,
    this.avatarColor = 'lavender',
    this.onTap,
  });

  final String name;
  final String meta;
  final int amount;
  final BillStatus status;
  final String avatarColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: AppDims.billRowHeight,
        padding: _cardPadding,
        decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
        child: Row(
          children: [
            Avatar(name: name, color: avatarColorOf(avatarColor), size: AppSize.avatarRow),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.heading20),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label14.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Money(amount, style: AppType.heading20),
                const SizedBox(height: 2),
                StatusPill(status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// White item card: name and quantity, line price, "each" line and a chip per participant.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.name,
    required this.qty,
    required this.lineTotal,
    required this.people,
    required this.claimedIds,
    this.onToggle,
    this.onTapCard,
  });

  final String name;
  final int qty;
  final int lineTotal;
  final List<Person> people;
  final Set<String> claimedIds;

  /// Inline chip mode (4 people or fewer).
  final ValueChanged<Person>? onToggle;

  /// Sheet mode (5 or more): the card is one big tap target and shows who has it.
  final VoidCallback? onTapCard;

  @override
  Widget build(BuildContext context) {
    final claimants = people.where((p) => claimedIds.contains(p.id)).toList();
    final card = Container(
      width: double.infinity,
      padding: _cardPadding,
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  qty > 1 ? '$name  x$qty' : name,
                  style: AppType.heading20,
                ),
              ),
              Money(lineTotal, style: AppType.heading20),
            ],
          ),
          if (qty > 1) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Money(lineTotal ~/ qty, style: AppType.label14, color: AppColors.slate),
                Text(' each', style: AppType.label14.copyWith(color: AppColors.slate)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          if (onTapCard == null)
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final p in people)
                  NameChip(
                    label: p.name,
                    on: claimedIds.contains(p.id),
                    onTap: onToggle == null ? null : () => onToggle!(p),
                  ),
              ],
            )
          else
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                if (claimants.isEmpty)
                  const NameChip(label: 'tap to assign', on: false)
                else
                  for (final p in claimants) NameChip(label: p.name, on: true),
              ],
            ),
        ],
      ),
    );
    return onTapCard == null ? card : PressableScale(onTap: onTapCard, child: card);
  }
}

enum BannerVariant { ok, error }

/// Lime banner with a lavender check, or coral when something is off.
class ClaimedBanner extends StatelessWidget {
  const ClaimedBanner({super.key, required this.text, this.variant = BannerVariant.ok, this.trailing});

  final String text;
  final BannerVariant variant;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ok = variant == BannerVariant.ok;
    final bg = ok ? AppColors.lime : AppColors.coral;
    return Container(
      height: AppSize.banner,
      padding: _cardPadding,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rLg),
      child: Row(
        children: [
          Container(
            width: AppDims.checkBadge,
            height: AppDims.checkBadge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ok ? AppColors.lavender : AppColors.white,
              shape: BoxShape.circle,
            ),
            child: ok
                ? const AppIcon(AppIcons.check, size: AppDims.chevronGlyph, color: AppColors.white, stroke: 3.4)
                : Text('!', style: AppType.label14.copyWith(color: AppColors.coral, fontWeight: AppFonts.bold)),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body16.copyWith(color: AppColors.onColor(bg))),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One person's bill. The background cycles lavender, lime, sky, coral by [index].
class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.person,
    required this.index,
    required this.total,
    required this.itemsAmount,
    required this.extrasAmount,
  });

  final Person person;
  final int index;
  final int total;
  final int itemsAmount;
  final int extrasAmount;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.billCardCycle[index % AppColors.billCardCycle.length];
    final fg = AppColors.onColor(bg);
    final avatarBg = bg == AppColors.lime || bg == AppColors.sky ? AppColors.lavender : AppColors.lime;
    return Container(
      padding: _cardPadding,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Avatar(name: person.name, color: avatarBg, size: AppSize.avatarBillCard),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.heading20.copyWith(color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Money(total, style: AppType.title24, color: fg, forceDecimals: true),
          const SizedBox(height: 10),
          Row(children: [
            Text('items ', style: AppType.label14.copyWith(color: fg)),
            Money(itemsAmount, style: AppType.label14, color: fg, forceDecimals: true),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Text('extras ', style: AppType.label14.copyWith(color: fg)),
            Money(extrasAmount, style: AppType.label14, color: fg, forceDecimals: true),
          ]),
        ],
      ),
    );
  }
}

class CustomRow extends StatelessWidget {
  const CustomRow({
    super.key,
    required this.person,
    required this.poisha,
    required this.onChanged,
  });

  final Person person;
  final int poisha;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDims.customRowHeight,
      padding: _cardPadding,
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Row(
        children: [
          Avatar(name: person.name, color: avatarColorOf(person.avatarColor), size: AppSize.avatarRow),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.heading20)),
          AmountField(poisha: poisha, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Lavender "owes you" card with a lime avatar and a lime remind pill.
class TabCard extends StatelessWidget {
  const TabCard({
    super.key,
    required this.name,
    required this.amount,
    this.onRemind,
    this.label,
  });

  final String name;
  final int amount;
  final VoidCallback? onRemind;

  /// Defaults to "{name} owes you".
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _cardPadding,
      decoration: const BoxDecoration(color: AppColors.lavender, borderRadius: AppRadius.rLg),
      child: Row(
        children: [
          Avatar(name: name, color: AppColors.lime, size: AppSize.avatarRow),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label ?? '$name owes you', style: AppType.label14.copyWith(color: AppColors.white)),
                Money(amount, style: AppType.title24, color: AppColors.white),
              ],
            ),
          ),
          PillButton(label: 'remind', onTap: onRemind),
        ],
      ),
    );
  }
}

/// 2 x N grid of equal height cards (the "whose bill is what?" grid).
class BillCardGrid extends StatelessWidget {
  const BillCardGrid({super.key, required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.s12));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
