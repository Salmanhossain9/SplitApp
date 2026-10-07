import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/widgets/avatar.dart';
import 'package:splitup/core/widgets/pill_tag.dart';
import 'package:splitup/core/widgets/pressable.dart';
import 'package:splitup/models/group.dart';

class GroupStack extends StatelessWidget {
  const GroupStack({
    super.key,
    required this.groups,
    required this.selectedIndex,
    required this.awayIds,
    required this.onSelect,
  }) : assert(groups.length <= 3, 'The design only shows three stacked cards');

  final List<Group> groups;
  final int selectedIndex;
  final Set<String> awayIds;
  final ValueChanged<int> onSelect;

  static const double frameHeight = 324;
  // Each group keeps its own colour, whichever position it is in.
  static const _cardColors = [
    AppColors.lavender,
    AppColors.coral,
    AppColors.lime,
  ];
  // Position 0 is the front card. Values come from the spec.
  static const _tops = [0.0, 144.0, 204.0];
  static const _heights = [200.0, 116.0, 120.0];

  // Front card is slot 0; the others keep their order in slots 1 and 2.
  int _slotOf(int index) {
    if (index == selectedIndex) return 0;
    return index < selectedIndex ? index + 1 : index;
  }

  @override
  Widget build(BuildContext context) {
    // Paint the back card first and the front card last, so the front is on top.
    final paintOrder = List.generate(groups.length, (i) => i)
      ..sort((a, b) => _slotOf(b).compareTo(_slotOf(a)));

    return SizedBox(
      height: frameHeight,
      child: Stack(
        children: [
          for (final i in paintOrder)
            AnimatedPositioned(
              key: ValueKey(groups[i].id),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              top: _tops[_slotOf(i)],
              height: _heights[_slotOf(i)],
              child: _GroupCard(
                group: groups[i],
                color: _cardColors[i],
                isFront: i == selectedIndex,
                awayIds: awayIds,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.color,
    required this.isFront,
    required this.awayIds,
    required this.onTap,
  });

  final Group group;
  final Color color;
  final bool isFront;
  final Set<String> awayIds;
  final VoidCallback onTap;

  // Spec: white text on lavender and coral, navy on lime.
  Color get _textColor =>
      color == AppColors.lime ? AppColors.navy : AppColors.white;

  // Lime and lavender always pair, so lime cards get lavender accents.
  Color get _accent =>
      color == AppColors.lime ? AppColors.lavender : AppColors.lime;

  Color get _accentTextColor =>
      _accent == AppColors.lime ? AppColors.navy : AppColors.white;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.fromLTRB(24, isFront ? 24 : 70, 24, 0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        // Lets the content lay out at its natural size while the card is
        // still animating, instead of triggering overflow warnings.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: isFront ? _buildFront() : _buildTitleRow(),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title24.copyWith(color: _textColor),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        PillTag(
          label: '${group.members.length} members',
          backgroundColor: _accent,
          textColor: _accentTextColor,
        ),
      ],
    );
  }

  Widget _buildFront() {
    final awayCount = group.members.where((m) => awayIds.contains(m.id)).length;
    final hereCount = group.members.length - awayCount;
    final detailStyle = AppText.label14.copyWith(color: _textColor);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleRow(),
        const SizedBox(height: AppSpacing.s4),
        Text('Last out ${group.lastOutLabel}', style: detailStyle),
        const SizedBox(height: AppSpacing.s4),
        Text('$hereCount here · $awayCount away', style: detailStyle),
        const SizedBox(height: 36),
        Row(
          children: [
            _buildAvatarStrip(),
            const Spacer(),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
              child: Icon(Icons.chevron_right_rounded, size: 24, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarStrip() {
    const size = 36.0;
    const step = 28.0; // 36 wide, overlapping the next one by 8
    final count = group.members.length;

    return SizedBox(
      height: size,
      width: size + (count - 1) * step,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * step,
              child: Opacity(
                opacity: awayIds.contains(group.members[i].id) ? 0.45 : 1,
                child: Avatar(
                  letter: group.members[i].name[0].toUpperCase(),
                  color: AppColors.personPalette[
                      i % AppColors.personPalette.length],
                  size: size,
                  ringColor: color,
                  ringWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}