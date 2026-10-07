import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/widgets/bottom_nav.dart';
import 'package:splitup/core/widgets/pill_button.dart';
import 'package:splitup/core/widgets/pill_tag.dart';
import 'package:splitup/features/dashboard/widgets/bill_row.dart';
import 'package:splitup/features/dashboard/widgets/summary_card.dart';
import 'package:splitup/features/new_bill/new_bill_screen.dart';
import 'package:splitup/models/bill.dart';

// Temporary fake data. We'll replace this with real data much later.
const _sampleBills = [
  Bill(
    place: 'Chillox',
    peopleCount: 4,
    dateLabel: 'Sep 21',
    totalPoisha: 470800,
    isSettled: true,
  ),
  Bill(
    place: 'Pizza Roma',
    peopleCount: 3,
    dateLabel: 'Sep 14',
    totalPoisha: 294000,
    isSettled: false,
  ),
  Bill(
    place: 'North End',
    peopleCount: 5,
    dateLabel: 'Sep 10',
    totalPoisha: 521000,
    isSettled: true,
  ),
  Bill(
    place: 'The Backyard',
    peopleCount: 4,
    dateLabel: 'Sep 3',
    totalPoisha: 356000,
    isSettled: false,
  ),
];

// The design colours the dashboard avatars lavender, lime, sky, then repeats.
const _rowColors = [AppColors.lavender, AppColors.lime, AppColors.sky];

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s16,
                AppSpacing.s24,
                // Room for the floating nav so the last row can scroll clear of it.
                AppSpacing.s24 + BottomNav.height + AppSpacing.s24,
              ),
              children: [
                const _Header(),
                const SizedBox(height: AppSpacing.s24),
                const SummaryCard(
                  settledPoisha: 1380000,
                  pendingPoisha: 462000,
                  billCount: 7,
                ),
                const SizedBox(height: AppSpacing.s24),
                const _SectionHeader(title: 'September'),
                const SizedBox(height: AppSpacing.s12),
                for (var i = 0; i < _sampleBills.length; i++) ...[
                  BillRow(
                    bill: _sampleBills[i],
                    avatarColor: _rowColors[i % _rowColors.length],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],
              ],
            ),
            const Positioned(
              left: AppSpacing.s24,
              right: AppSpacing.s24,
              bottom: AppSpacing.s24,
              child: BottomNav(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.heading20),
        const PillTag(label: 'see all', backgroundColor: AppColors.lime),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('good evening.', style: AppText.display36),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'your splits',
              style: AppText.label14.copyWith(color: AppColors.slate),
            ),
            PillButton(
              label: 'new bill',
              backgroundColor: AppColors.lavender,
              textColor: AppColors.white,
              iconColor: AppColors.lime,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewBillScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}