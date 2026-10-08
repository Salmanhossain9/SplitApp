import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Six boxes for the email code. One hidden text field does the typing, so paste and the
/// system one-time-code suggestion both work.
class CodeField extends StatefulWidget {
  const CodeField({super.key, required this.onChanged, this.onCompleted, this.length = 6, this.enabled = true});

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final int length;
  final bool enabled;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void clear() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          // Six separate boxes with a gap, as wide as fits (never wider than codeBoxMax).
          LayoutBuilder(
            builder: (context, box) {
              const gap = AppSpacing.s8;
              final width = ((box.maxWidth - gap * (widget.length - 1)) / widget.length).clamp(0.0, AppDims.codeBoxMax);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    AnimatedContainer(
                      duration: AppMotion.chip,
                      width: width,
                      height: AppDims.codeBoxHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < text.length
                            ? AppColors.lavender
                            : (i == text.length && _focus.hasFocus ? AppColors.lime : AppColors.white),
                        borderRadius: AppRadius.rMd,
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: AppType.title24.copyWith(color: AppColors.white, fontWeight: AppFonts.bold),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: (v) {
                  widget.onChanged(v);
                  if (v.length == widget.length) widget.onCompleted?.call(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
