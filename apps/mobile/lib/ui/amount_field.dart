import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_core/split_core.dart';

import '../theme/tokens.dart';

/// Digits with at most one dot and two decimals.
class DecimalInputFormatter extends TextInputFormatter {
  static final _ok = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _ok.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Cream pill with right aligned bold text. Holds no state beyond the text:
/// the value is integer [valueUnits] (poisha, or basis points) and never a double.
class _PillNumberField extends StatefulWidget {
  const _PillNumberField({
    required this.valueUnits,
    required this.onChanged,
    required this.toText,
    required this.fromText,
    required this.width,
    this.height,
    this.prefix,
    this.enabled = true,
  });

  final int valueUnits;
  final ValueChanged<int> onChanged;
  final String Function(int) toText;
  final int? Function(String) fromText;
  final double width;
  final double? height;
  final String? prefix;
  final bool enabled;

  @override
  State<_PillNumberField> createState() => _PillNumberFieldState();
}

class _PillNumberFieldState extends State<_PillNumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.toText(widget.valueUnits));

  @override
  void didUpdateWidget(_PillNumberField old) {
    super.didUpdateWidget(old);
    // Only overwrite when the outside value really changed (e.g. "split the rest equally").
    if (widget.fromText(_controller.text) != widget.valueUnits) {
      _controller.text = widget.toText(widget.valueUnits);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppType.heading20.copyWith(fontWeight: AppFonts.bold);
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(color: AppColors.cream, borderRadius: AppRadius.rFull),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.prefix != null) Text(widget.prefix!, style: style.copyWith(color: AppColors.slate)),
          Flexible(
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: AppSpacing.s24),
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  style: style,
                  cursorColor: AppColors.lavender,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: style.copyWith(color: AppColors.slate),
                  ),
                  onChanged: (text) => widget.onChanged(widget.fromText(text) ?? 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Taka input. Numeric keyboard, 2 decimals max, reports integer poisha.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.poisha,
    required this.onChanged,
    this.enabled = true,
    this.width = AppDims.amountFieldWidth,
  });

  final int poisha;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double width;

  @override
  Widget build(BuildContext context) => _PillNumberField(
        valueUnits: poisha,
        onChanged: onChanged,
        toText: poishaToInput,
        fromText: parsePoisha,
        width: width,
        prefix: takaSign,
        enabled: enabled,
      );
}

/// Rate input in percent, reports basis points (5.9 -> 590).
class RateField extends StatelessWidget {
  const RateField({super.key, required this.rateBp, required this.onChanged});

  final int rateBp;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _PillNumberField(
        valueUnits: rateBp,
        onChanged: onChanged,
        toText: rateBpToInput,
        fromText: parseRateBp,
        width: AppDims.rateFieldWidth,
        height: AppDims.rateFieldHeight,
      );
}

/// Label, rate field, percent sign, computed amount.
class ChargeRow extends StatelessWidget {
  const ChargeRow({
    super.key,
    required this.label,
    required this.rateBp,
    required this.amount,
    required this.onRateChanged,
    required this.amountBuilder,
  });

  final String label;
  final int rateBp;
  final int amount;
  final ValueChanged<int> onRateChanged;

  /// Renders the amount (the screen decides whether it uses [Money]).
  final Widget Function(int amount) amountBuilder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppType.body16)),
        RateField(rateBp: rateBp, onChanged: onRateChanged),
        const SizedBox(width: AppSpacing.s8),
        Text('%', style: AppType.body16.copyWith(color: AppColors.slate)),
        const SizedBox(width: AppSpacing.s12),
        SizedBox(width: AppDims.amountFieldWidth - AppSpacing.s32, child: Align(alignment: Alignment.centerRight, child: amountBuilder(amount))),
      ],
    );
  }
}
