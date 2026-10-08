import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Standard screen: cream background, 24 side padding, 56 top (or the safe area, whichever is
/// larger), a pinned [header], a scrolling body, and an optional floating bottom element
/// (CTA or nav) that is 24 above the bottom edge. The body scrolls under it.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.children,
    this.header,
    this.bottom,
    this.background = AppColors.cream,
    this.gap = AppSpacing.s16,
    this.controller,
    this.reserveBottom = false,
    this.bottomHeight = AppSize.button,
    this.onRefresh,
  });

  /// Pull down to refresh (home, money, notifications).
  final Future<void> Function()? onRefresh;

  /// Leave room at the bottom for a floating element someone else draws (the tab bar).
  final bool reserveBottom;

  /// How tall the floating [bottom] is, so the body scrolls clear of it (two buttons are taller).
  final double bottomHeight;

  final List<Widget> children;
  final Widget? header;
  final Widget? bottom;
  final Color background;
  final double gap;
  final ScrollController? controller;

  Widget _maybeRefresh(Widget list) => onRefresh == null
      ? list
      : RefreshIndicator(
          color: AppColors.lavender,
          backgroundColor: AppColors.white,
          onRefresh: onRefresh!,
          child: list,
        );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = math.max(AppDims.screenTop, mq.padding.top + AppSpacing.s16);
    final bottomInset = mq.padding.bottom;
    final floating = (bottom == null && !reserveBottom)
        ? 0.0
        : bottomHeight + AppSpacing.s24;
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Column(
            children: [
              if (header != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s24,
                    top,
                    AppSpacing.s24,
                    0,
                  ),
                  child: header,
                ),
              Expanded(
                child: _maybeRefresh(
                  ListView(
                    controller: controller,
                    physics: onRefresh == null
                        ? null
                        : const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      header == null ? top : AppSpacing.s16,
                      AppSpacing.s24,
                      AppSpacing.s24 + floating + bottomInset,
                    ),
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) SizedBox(height: gap),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (bottom != null)
            Positioned(
              left: AppSpacing.s24,
              right: AppSpacing.s24,
              bottom: AppSpacing.s24 + bottomInset,
              child: bottom!,
            ),
        ],
      ),
    );
  }
}
