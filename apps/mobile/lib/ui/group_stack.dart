import 'package:flutter/material.dart';

import '../core/person.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'pressable_scale.dart';

class GroupCardData {
  const GroupCardData({
    required this.id,
    required this.name,
    required this.members,
    this.absentIds = const {},
  });

  final String id;
  final String name;
  final List<Person> members;

  /// Members who are not here tonight; shown at 45%.
  final Set<String> absentIds;
}

const _slotColors = [AppColors.lavender, AppColors.coral, AppColors.lime];
const _slotHeights = [AppDims.groupFront, AppDims.groupSecond, AppDims.groupThird];

/// Stacked deck of up to three group cards. Tapping a card lifts it to the front.
/// Paint order: third (back), second, front.
class GroupStack extends StatelessWidget {
  const GroupStack({
    super.key,
    required this.groups,
    required this.frontId,
    required this.onTap,
  });

  final List<GroupCardData> groups;

  /// The group currently in front. The rest keep their relative order behind it.
  final String? frontId;
  final ValueChanged<GroupCardData> onTap;

  List<GroupCardData> get _ordered {
    final shown = groups.take(3).toList();
    final front = shown.where((g) => g.id == frontId).toList();
    return [...front, ...shown.where((g) => g.id != frontId)];
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    // Keep widget identity (keys) stable so AnimatedPositioned animates the reorder,
    // and paint back-to-front by sorting a copy by slot descending.
    final byId = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
    final paintOrder = [...groups.take(3)]..sort((a, b) => byId[b.id]!.compareTo(byId[a.id]!));
    return SizedBox(
      height: AppDims.groupFrame,
      child: Stack(
        children: [
          for (final g in paintOrder)
            _GroupCard(
              key: ValueKey(g.id),
              data: g,
              slot: byId[g.id]!,
              onTap: () => onTap(g),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({super.key, required this.data, required this.slot, required this.onTap});

  final GroupCardData data;
  final int slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = _slotColors[slot];
    final fg = AppColors.onColor(bg);
    final front = slot == 0;
    final here = data.members.length - data.absentIds.length;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      top: AppDims.groupY[slot],
      left: 0,
      right: 0,
      height: _slotHeights[slot],
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          padding: EdgeInsets.only(
            left: AppSpacing.s24,
            right: AppSpacing.s24,
            top: front ? AppSpacing.s24 : AppDims.groupTopInset,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rLg),
          // The front layout sits in an OverflowBox so it never overflows while the
          // card is still growing from a back slot; the card clips what is not there yet.
          child: front
              ? OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: AppDims.groupFront - AppSpacing.s24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.name, style: AppType.title24.copyWith(color: fg)),
                      Text(
                        '${data.members.length} friends . $here here',
                        style: AppType.label14.copyWith(color: fg),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s24),
                        child: _Members(data: data, ring: bg),
                      ),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.heading20.copyWith(color: fg),
                      ),
                    ),
                    _Members(data: data, ring: bg),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({required this.data, required this.ring});
  final GroupCardData data;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final shown = data.members.take(5).toList();
    const step = AppSize.avatarGroup - AppDims.groupOverlap;
    return SizedBox(
      width: shown.isEmpty ? 0 : step * (shown.length - 1) + AppSize.avatarGroup,
      height: AppSize.avatarGroup,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: Avatar(
                name: shown[i].name,
                // An avatar the same colour as its card would vanish; swap to lime.
                color: avatarColorOf(shown[i].avatarColor) == ring
                    ? (ring == AppColors.lime ? AppColors.lavender : AppColors.lime)
                    : avatarColorOf(shown[i].avatarColor),
                size: AppSize.avatarGroup,
                ringColor: ring,
                ringWidth: AppSize.avatarRingGroup,
                opacity: data.absentIds.contains(shown[i].id) ? AppOpacity.absentMember : 1,
              ),
            ),
        ],
      ),
    );
  }
}
