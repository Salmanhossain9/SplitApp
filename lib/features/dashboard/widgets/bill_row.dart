import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/money.dart';
import 'package:splitup/core/widgets/avatar.dart';
import 'package:splitup/core/widgets/pill_tag.dart';
import 'package:splitup/models/bill.dart';

class BillRow extends StatelessWidget {
  const BillRow({
    super.key,
    required this.bill,
    required this.avatarColor,
  });

  final Bill bill;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Avatar(
            letter: bill.place[0].toUpperCase(),
            color: avatarColor,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading20,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${bill.peopleCount} people · ${bill.dateLabel}',
                  style: AppText.label14.copyWith(color: AppColors.slate),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTaka(bill.totalPoisha),
                style: AppText.heading20.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.s4),
              PillTag(
                label: bill.isSettled ? 'settled' : 'pending',
                backgroundColor:
                    bill.isSettled ? AppColors.lime : AppColors.coral,
                textColor: bill.isSettled ? AppColors.navy : AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}