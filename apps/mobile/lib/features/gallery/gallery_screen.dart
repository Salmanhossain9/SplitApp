import 'package:flutter/material.dart';

import '../../core/person.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';

const _you = Person(id: 'you', name: 'You', isHost: true);
const _rafi = Person(id: 'rafi', name: 'Rafi', avatarColor: 'coral');
const _nabil = Person(id: 'nabil', name: 'Nabil', avatarColor: 'sky');
const _tania = Person(id: 'tania', name: 'Tania', avatarColor: 'lime');
const _people = [_you, _rafi, _nabil, _tania];

class GallerySection {
  const GallerySection(this.title, this.builder);
  final String title;
  final Widget Function() builder;
}

Widget _gap() => const SizedBox(height: AppSpacing.s16);

/// Every widget and variant, one named section each. Also drives the golden tests.
final gallerySections = <GallerySection>[
  GallerySection('type', () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('all settled.', style: AppType.display36),
          Text('split it. skip the awkward.', style: AppType.title24),
          Money(223600, style: AppType.amount56, lightDecimals: true),
          Money(41250, style: AppType.amount56, lightDecimals: true),
          Text('heading20 ৳1,422', style: AppType.heading20),
          Text('body16 ৳200 and label14 ৳69', style: AppType.body16),
        ],
      )),
  GallerySection('icons', () => Wrap(
        spacing: AppSpacing.s16,
        runSpacing: AppSpacing.s16,
        children: [for (final i in AppIcons.values) AppIcon(i, size: AppSize.icon + AppSpacing.s12)],
      )),
  GallerySection('buttons', () => Column(
        children: [
          for (final v in WideButtonVariant.values) ...[
            WideButton(
              label: switch (v) {
                WideButtonVariant.primary => 'scan receipt',
                WideButtonVariant.photo => 'take photo',
                WideButtonVariant.upload => 'upload from photos',
                WideButtonVariant.next => 'vat and service charge',
                WideButtonVariant.done => 'send bills',
                WideButtonVariant.home => 'back to home',
                WideButtonVariant.another => 'split another bill',
                WideButtonVariant.start => 'split a bill',
                WideButtonVariant.login => 'log in / sign up',
              },
              variant: v,
              onPressed: () {},
            ),
            _gap(),
          ],
          WideButton(label: 'vat and service charge', variant: WideButtonVariant.next, onPressed: null, enabled: false),
          _gap(),
          WideButton(label: 'send bills', variant: WideButtonVariant.done, onPressed: () {}, loading: true),
          _gap(),
          Align(alignment: Alignment.centerLeft, child: NewBillPill(onTap: () {})),
        ],
      )),
  GallerySection('header', () => Column(
        children: [
          const AppTopBar(title: 'who had what?', trailing: StepPill('step 3 of 3')),
          _gap(),
          const StepperBar(current: 1),
          _gap(),
          const StepperBar(current: 3),
          _gap(),
          const Align(alignment: Alignment.centerLeft, child: Logo()),
        ],
      )),
  GallerySection('nav', () => Column(
        children: [
          BottomNav(index: 0, onTap: (_) {}, unreadNotifications: true),
          _gap(),
          BottomNav(index: 1, onTap: (_) {}),
        ],
      )),
  GallerySection('chips', () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: AppSpacing.s8, children: const [
            NameChip(label: 'Rafi', on: true),
            NameChip(label: 'Nabil', on: false),
          ]),
          _gap(),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarChip(person: _you, selected: true),
                const SizedBox(width: AppSpacing.s8),
                AvatarChip(person: _rafi, selected: true),
                const SizedBox(width: AppSpacing.s8),
                AvatarChip(person: _nabil, selected: false),
                const SizedBox(width: AppSpacing.s8),
                const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: AddFriendButton(),
                ),
              ],
            ),
          ),
        ],
      )),
  GallerySection('switches', () => Column(
        children: [
          TabSwitch(selected: ItemsTab.scan, onChanged: (_) {}),
          _gap(),
          ModeSwitch(selected: ClaimMode.items, onChanged: (_) {}),
          _gap(),
          Row(children: const [
            Expanded(child: OptionTile(title: 'equally', subtitle: 'same extra for everyone', on: true)),
            SizedBox(width: AppSpacing.s12),
            Expanded(child: OptionTile(title: 'by what they ate', subtitle: 'bigger order, bigger share', on: false)),
          ]),
        ],
      )),
  GallerySection('summary', () => Column(
        children: [
          const SummaryCard(
            label: 'this month',
            amount: 1842000,
            caption: 'split across 7 bills',
            settled: 1320000,
            pending: 522000,
          ),
          _gap(),
          BalanceCard(title: 'you are owed', amount: 20000, actionLabel: 'remind', onAction: () {}),
          _gap(),
          Row(children: const [
            Expanded(child: ActionTile(variant: ActionTileVariant.split, label: 'split a bill')),
            SizedBox(width: AppSpacing.s12),
            Expanded(child: ActionTile(variant: ActionTileVariant.request, label: 'request')),
          ]),
        ],
      )),
  GallerySection('rows', () => Column(
        children: const [
          BillRow(name: 'Chillox', meta: '12 Sep . 4 friends', amount: 223600, status: BillStatus.tab),
          SizedBox(height: AppSpacing.s12),
          BillRow(name: 'Pizza Roma', meta: '9 Sep . 3 friends', amount: 154050, status: BillStatus.settled, avatarColor: 'coral'),
          SizedBox(height: AppSpacing.s12),
          BillRow(name: 'Star Kabab', meta: '2 Sep . 5 friends', amount: 98000, status: BillStatus.pending, avatarColor: 'sky'),
          SizedBox(height: AppSpacing.s12),
          TabCard(name: 'Tania', amount: 20000),
        ],
      )),
  GallerySection('claim', () => Column(
        children: [
          const ClaimedBanner(text: '3 of 6 items assigned'),
          _gap(),
          const ClaimedBanner(text: '৳200 left', variant: BannerVariant.error),
          _gap(),
          ItemCard(
            name: 'Coke',
            qty: 3,
            lineTotal: 27000,
            people: _people,
            claimedIds: const {'you', 'rafi', 'tania'},
            onToggle: (_) {},
          ),
          _gap(),
          CustomRow(person: _rafi, poisha: 72150, onChanged: (_) {}),
        ],
      )),
  GallerySection('bill cards', () => BillCardGrid(
        cards: [
          BillCard(person: _you, index: 0, total: 61400, itemsAmount: 55500, extrasAmount: 5900),
          BillCard(person: _rafi, index: 1, total: 72150, itemsAmount: 66250, extrasAmount: 5900),
          BillCard(person: _nabil, index: 2, total: 63150, itemsAmount: 57250, extrasAmount: 5900),
          BillCard(person: _tania, index: 3, total: 26900, itemsAmount: 21000, extrasAmount: 5900),
        ],
      )),
  GallerySection('settle', () => Column(
        children: [
          SettleRow(person: _rafi, amount: 72150, method: SettleMethod.bkash, onMethod: (_) {}),
          _gap(),
          SettleRow(
            person: _tania,
            amount: 26900,
            method: SettleMethod.owesMe,
            onMethod: (_) {},
            cover: CoverControl(
              covered: 20000,
              caption: 'Tania owes you ৳200. The other ৳69 is paid in cash.',
              onMinus: () {},
              onPlus: () {},
              onChanged: (_) {},
            ),
          ),
        ],
      )),
  GallerySection('groups', () => GroupStack(
        groups: const [
          GroupCardData(id: 'nsu', name: 'NSU boys', members: _people, absentIds: {'tania'}),
          GroupCardData(id: 'room', name: 'Roommates', members: [_you, _nabil]),
          GroupCardData(id: 'office', name: 'Office lunch', members: [_you, _rafi, _tania]),
        ],
        frontId: 'nsu',
        onTap: (_) {},
      )),
  GallerySection('recap', () => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: RecapTile(value: Money(223600, style: AppType.title24), label: 'split', background: AppColors.sky)),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: RecapTile(value: Text('4', style: AppType.title24.copyWith(fontWeight: AppFonts.bold)), label: 'friends', background: AppColors.lime)),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: RecapTile(value: Text('1', style: AppType.title24.copyWith(fontWeight: AppFonts.bold)), label: 'open tab', background: AppColors.white)),
          ],
        ),
      )),
  GallerySection('viewfinder', () => const ReceiptViewfinder()),
];

/// Debug-only visual QA page.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          children: [
            for (final s in gallerySections) ...[
              Text(s.title, style: AppType.label14.copyWith(color: AppColors.slate)),
              const SizedBox(height: AppSpacing.s8),
              s.builder(),
              const SizedBox(height: AppSpacing.s32),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: Sparkle(size: AppSize.icon * 2),
            ),
          ],
        ),
      ),
    );
  }
}
