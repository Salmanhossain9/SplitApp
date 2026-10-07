import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Cream sheet with a big top radius over a navy scrim at 55%.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: AppColors.clear,
    barrierColor: AppColors.navy.withValues(alpha: AppOpacity.scrim),
    builder: (ctx) => AppSheetFrame(child: builder(ctx)),
  );
}

class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s12,
        AppSpacing.s24,
        AppSpacing.s24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDims.sheetTopRadius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDims.sheetHandleWidth,
            height: AppDims.sheetHandleHeight,
            decoration: BoxDecoration(
              color: AppColors.slate.withValues(alpha: AppOpacity.addFriend),
              borderRadius: AppRadius.rFull,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          child,
        ],
      ),
    );
  }
}
