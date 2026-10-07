import 'package:flutter/material.dart';
import 'package:splitup/app/app_colors.dart';
import 'package:splitup/app/app_sizes.dart';
import 'package:splitup/app/app_text.dart';
import 'package:splitup/core/widgets/circle_back_button.dart';
import 'package:splitup/core/widgets/pill_button.dart';
import 'package:splitup/core/widgets/pill_tag.dart';
import 'package:splitup/core/widgets/wide_button.dart';
import 'package:splitup/features/new_bill/widgets/group_stack.dart';
import 'package:splitup/features/new_bill/widgets/person_chip.dart';
import 'package:splitup/models/group.dart';
import 'package:splitup/models/person.dart';

// Temporary fake data, replaced by real data much later.
const _you = Person(id: 'you', name: 'You');

const _sampleGroups = [
  Group(
    id: 'nsu',
    name: 'NSU boys',
    lastOutLabel: 'Sep 21 · Chillox',
    lastPlace: 'Chillox',
    members: [
      _you,
      Person(id: 'rafi', name: 'Rafi'),
      Person(id: 'nabil', name: 'Nabil'),
      Person(id: 'tania', name: 'Tania'),
    ],
  ),
  Group(
    id: 'roommates',
    name: 'Roommates',
    lastOutLabel: 'Sep 8 · Pizza Roma',
    lastPlace: 'Pizza Roma',
    members: [
      _you,
      Person(id: 'imran', name: 'Imran'),
      Person(id: 'sadia', name: 'Sadia'),
    ],
  ),
  Group(
    id: 'office',
    name: 'Office lunch',
    lastOutLabel: 'Aug 30 · Kacchi Bhai',
    lastPlace: 'Kacchi Bhai',
    members: [
      _you,
      Person(id: 'arif', name: 'Arif'),
      Person(id: 'maliha', name: 'Maliha'),
      Person(id: 'tarek', name: 'Tarek'),
      Person(id: 'nusrat', name: 'Nusrat'),
      Person(id: 'zara', name: 'Zara'),
    ],
  ),
];

class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  late final TextEditingController _placeController;
  int _selectedGroup = 0;
  final Set<String> _awayIds = {'tania'};
  bool _placeEdited = false;

  Group get _group => _sampleGroups[_selectedGroup];

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(text: _group.lastPlace);
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  void _selectGroup(int index) {
    setState(() {
      _selectedGroup = index;
      // Keep the name the user typed; otherwise follow the group's last place.
      if (!_placeEdited) _placeController.text = _group.lastPlace;
    });
  }

  void _togglePerson(String id) {
    setState(() {
      if (_awayIds.contains(id)) {
        _awayIds.remove(id);
      } else {
        _awayIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final hereCount =
        group.members.where((m) => !_awayIds.contains(m.id)).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s16,
                AppSpacing.s24,
                AppSpacing.s16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleBackButton(),
                  PillTag(
                    label: 'step 1 of 3',
                    backgroundColor: AppColors.lavender,
                    textColor: AppColors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      AppSpacing.s8,
                      AppSpacing.s24,
                      AppSpacing.s24 + WideButton.height + AppSpacing.s24,
                    ),
                    children: [
                      const Text('where are we eating?', style: AppText.body16),
                      const SizedBox(height: AppSpacing.s4),
                      TextField(
                        controller: _placeController,
                        onChanged: (_) => _placeEdited = true,
                        maxLines: 1,
                        textCapitalization: TextCapitalization.words,
                        cursorColor: AppColors.lavender,
                        style: AppText.display36,
                        decoration: InputDecoration.collapsed(
                          hintText: 'restaurant name',
                          hintStyle: AppText.display36.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text.rich(
                        TextSpan(
                          style: AppText.label14.copyWith(
                            color: AppColors.slate,
                          ),
                          children: [
                            const TextSpan(text: 'with '),
                            TextSpan(
                              text: group.name,
                              style: const TextStyle(
                                color: AppColors.lavender,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' · $hereCount of ${group.members.length} here',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      SizedBox(
                        height: PersonChip.height,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < group.members.length; i++) ...[
                                PersonChip(
                                  name: group.members[i].name,
                                  avatarColor: AppColors.personPalette[
                                      i % AppColors.personPalette.length],
                                  isHere:
                                      !_awayIds.contains(group.members[i].id),
                                  onTap: () =>
                                      _togglePerson(group.members[i].id),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                              ],
                              const Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: _AddFriendButton(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('your groups', style: AppText.heading20),
                          PillButton(
                            label: 'new group',
                            backgroundColor: AppColors.lime,
                            textColor: AppColors.navy,
                            iconColor: AppColors.lavender,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      GroupStack(
                        groups: _sampleGroups,
                        selectedIndex: _selectedGroup,
                        awayIds: _awayIds,
                        onSelect: _selectGroup,
                      ),
                    ],
                  ),
                  const Positioned(
                    left: AppSpacing.s24,
                    right: AppSpacing.s24,
                    bottom: AppSpacing.s24,
                    child: WideButton(
                      label: 'scan receipt',
                      icon: Icons.document_scanner_rounded,
                      backgroundColor: AppColors.navy,
                      textColor: AppColors.white,
                      circleColor: AppColors.lime,
                      iconColor: AppColors.navy,
                      // onTap comes when step 2 exists.
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.slate.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.add, size: 14, color: AppColors.white),
    );
  }
}