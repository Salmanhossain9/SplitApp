import 'package:flutter/material.dart';
import 'package:split_core/split_core.dart';

import '../theme/tokens.dart';
import 'amount_field.dart';
import 'app_icon.dart';
import 'pressable_scale.dart';
import 'settle_row.dart';

/// Cream pill text input (item name, guest name, phone).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.keyboardType,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: const BoxDecoration(color: AppColors.cream, borderRadius: AppRadius.rFull),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: AppType.body16,
        cursorColor: AppColors.lavender,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppType.body16.copyWith(color: AppColors.slate),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Big flat headline input: the place name ("Chillox").
class HeadlineField extends StatelessWidget {
  const HeadlineField({super.key, required this.controller, required this.hint, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: AppType.display36,
      cursorColor: AppColors.lavender,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: AppType.display36.copyWith(color: AppColors.slate.withValues(alpha: AppOpacity.awayChip)),
      ),
      onChanged: onChanged,
    );
  }
}

/// Editable line item: name, quantity stepper, unit price, delete.
class ItemEditCard extends StatefulWidget {
  const ItemEditCard({
    super.key,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.onName,
    required this.onQty,
    required this.onUnitPrice,
    required this.onDelete,
  });

  final String name;
  final int qty;
  final int unitPrice;
  final ValueChanged<String> onName;
  final ValueChanged<int> onQty;
  final ValueChanged<int> onUnitPrice;
  final VoidCallback onDelete;

  @override
  State<ItemEditCard> createState() => _ItemEditCardState();
}

class _ItemEditCardState extends State<ItemEditCard> {
  late final TextEditingController _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: AppRadius.rLg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(controller: _name, hint: 'item name', onChanged: widget.onName),
              ),
              const SizedBox(width: AppSpacing.s8),
              CircleIconButton(icon: AppIcons.minus, color: AppColors.coral, onTap: widget.onDelete),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              CircleIconButton(
                icon: AppIcons.minus,
                onTap: widget.qty > 1 ? () => widget.onQty(widget.qty - 1) : null,
              ),
              SizedBox(
                width: AppSize.avatarRow,
                child: Center(child: Text('${widget.qty}', style: AppType.heading20)),
              ),
              CircleIconButton(icon: AppIcons.plus, onTap: () => widget.onQty(widget.qty + 1)),
              const Spacer(),
              Text('each ', style: AppType.label14.copyWith(color: AppColors.slate)),
              AmountField(poisha: widget.unitPrice, onChanged: widget.onUnitPrice),
            ],
          ),
          if (widget.qty > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'line total ${formatTaka(widget.qty * widget.unitPrice)}',
                  style: AppType.label14.copyWith(color: AppColors.slate),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _splitBarColors = [AppColors.lavender, AppColors.coral, AppColors.lime, AppColors.sky];

/// One segment per person, proportional to their share (the bottom sheet split bar).
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.parts});
  final List<int> parts;

  @override
  Widget build(BuildContext context) {
    final nonZero = parts.where((p) => p > 0).length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDims.progressRadius),
      child: SizedBox(
        height: AppSize.progressBar,
        child: nonZero == 0
            ? const ColoredBox(color: AppColors.white)
            : Row(
                children: [
                  for (var i = 0; i < parts.length; i++)
                    if (parts[i] > 0) ...[
                      if (i > 0) const SizedBox(width: AppDims.splitBarGap),
                      Expanded(
                        flex: parts[i],
                        child: ColoredBox(color: _splitBarColors[i % _splitBarColors.length]),
                      ),
                    ],
                ],
              ),
      ),
    );
  }
}

/// Quiet text-style link button ("split the rest equally").
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Text(
          label,
          style: AppType.body16.copyWith(
            color: onTap == null ? AppColors.slate : AppColors.lavender,
            fontWeight: AppFonts.bold,
          ),
        ),
      ),
    );
  }
}
