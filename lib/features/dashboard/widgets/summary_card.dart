import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/money.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.settledPoisha,
    required this.pendingPoisha,
    required this.billCount,
  });

  final int settledPoisha;
  final int pendingPoisha;
  final int billCount;

  @override
  Widget build(BuildContext context) {
    final total = settledPoisha + pendingPoisha;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('this month', style: AppText.label14),
          const SizedBox(height: AppSpacing.s8),
          Text(formatTaka(total), style: AppText.amount56),
          const SizedBox(height: AppSpacing.s8),
          Text('split across $billCount bills', style: AppText.label14),
          const SizedBox(height: AppSpacing.s16),
          _ProgressBar(settled: settledPoisha, pending: pendingPoisha),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s4,
            children: [
              _LegendItem(
                color: AppColors.lavender,
                text: '${formatTaka(settledPoisha)} settled',
              ),
              _LegendItem(
                color: AppColors.lime,
                text: '${formatTaka(pendingPoisha)} pending',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.settled, required this.pending});

  final int settled;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          if (settled > 0)
            Expanded(
              flex: settled,
              child: const _BarSegment(color: AppColors.lavender),
            ),
          if (settled > 0 && pending > 0) const SizedBox(width: AppSpacing.s4),
          if (pending > 0)
            Expanded(
              flex: pending,
              child: const _BarSegment(color: AppColors.lime),
            ),
        ],
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  const _BarSegment({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: AppText.micro12),
      ],
    );
  }
}