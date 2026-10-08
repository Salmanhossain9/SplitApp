import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup/core/person.dart';
import 'package:splitup/features/bill/bill_summary.dart';
import 'package:splitup/features/bill/draft_bill.dart' show hostId;
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/features/groups/groups_provider.dart';
import 'package:splitup/features/groups/groups_repository.dart';
import 'package:splitup/features/share/share_bills_sheet.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/ui.dart';

/// Things that went wrong on a real phone and in a real database.
Widget phone(Widget child, {required double width, double textScale = 1}) => MaterialApp(
      theme: buildAppTheme(),
      builder: (c, app) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(width: width - 48, child: SingleChildScrollView(child: child)),
        ),
      ),
    );

class _SlowGroups implements GroupsRepository {
  final created = <String>[];
  final gate = Completer<void>();
  @override
  Future<List<GroupCardData>> load() async => const [];
  @override
  Future<GroupCardData> create(String name, List<Person> members) async {
    created.add(name);
    await gate.future;
    return GroupCardData(id: 'g${created.length}', name: name, members: members);
  }
}

Future<(ProviderContainer, DraftBillNotifier, GoRouterHandle)> openNewBill(
  WidgetTester tester, {
  GroupsRepository? groups,
  List<GroupCardData> initial = const [],
  double width = 411,
  double scale = 1,
  int friends = 3,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [
    groupsRepositoryProvider.overrideWithValue(groups ?? LocalGroupsRepository(initial: initial)),
  ]);
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Chillox');
  for (final name in ['Adnan', 'Siwom', 'Hasan', 'Karim', 'Rafi'].take(friends)) {
    n.addGuest(name);
  }
  c.listen(routerProvider, (_, _) {});
  final router = c.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  router.go('/bill/new');
  await tester.pumpAndSettle();
  return (c, n, router);
}

typedef GoRouterHandle = Object;

const nsu = [
  Person(id: 'f1', name: 'Adnan', avatarColor: 'sky'),
  Person(id: 'f2', name: 'Siwom', avatarColor: 'lime'),
  Person(id: 'f3', name: 'Hasan', avatarColor: 'lime'),
  Person(id: 'f4', name: 'Karim', avatarColor: 'coral'),
];

void main() {
  group('home screen data (real PostgREST output)', () {
    // Saved from a real PostgREST answering the query the home screen sends. Without the
    // relationship hint PostgREST refuses it (PGRST201) and the home screen never loads.
    final rows = (jsonDecode(File('test/fixtures/postgrest/bills.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

    test('every sent bill becomes a summary with its people, share and tab', () {
      final bills = [for (final r in rows) BillSummary.fromRow(r)];
      expect(bills.length, 2);
      final chillox = bills.firstWhere((b) => b.place == 'Chillox');
      expect(chillox.total, 223600);
      expect(chillox.friendCount, 3);
      expect(chillox.target, greaterThan(0));
    });
  });

  group('add items', () {
    for (final (width, scale) in [(320.0, 1.0), (320.0, 1.3), (360.0, 1.15), (411.0, 1.3)]) {
      testWidgets('the whole price shows at $width dp, font x$scale', (tester) async {
        await tester.pumpWidget(phone(
          ItemEditCard(
            name: 'Chocolate Brownie Cream',
            qty: 1,
            unitPrice: 114500,
            onName: (_) {},
            onQty: (_) {},
            onUnitPrice: (_) {},
            onDelete: () {},
          ),
          width: width,
          textScale: scale,
        ));
        expect(tester.takeException(), isNull);
        final field = find.descendant(of: find.byType(AmountField), matching: find.byType(EditableText));
        final editable = tester.widget<EditableText>(field);
        final painter = TextPainter(
          text: TextSpan(text: editable.controller.text, style: editable.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(tester.element(field)),
        )..layout();
        expect(editable.controller.text, '1145');
        expect(tester.getSize(field).width, greaterThanOrEqualTo(painter.width));
      });
    }
  });

  group('bills sent picture', () {
    for (final (width, scale) in [(320.0, 1.0), (312.0, 1.3), (360.0, 1.0)]) {
      testWidgets('cards stay compact at $width dp, font x$scale', (tester) async {
        await tester.pumpWidget(phone(
          ShareImageCard(
            place: 'Rustic',
            total: 293230,
            cards: [
              for (var i = 0; i < 4; i++)
                BillCard(person: Person(id: '$i', name: 'Friend $i'), index: i, total: 77744, itemsAmount: 74077, extrasAmount: 3667),
            ],
          ),
          width: width,
          textScale: scale,
        ));
        expect(tester.takeException(), isNull);
        final cards = tester.widgetList(find.byType(BillCard)).length;
        expect(cards, 4);
        for (var i = 0; i < 4; i++) {
          expect(tester.getSize(find.byType(BillCard).at(i)).height, lessThan(230));
        }
      });
    }
  });

  group('send bills', () {
    for (final (width, height, scale) in [(320.0, 640.0, 1.0), (320.0, 700.0, 1.3), (360.0, 740.0, 1.0)]) {
      testWidgets('the bills sent sheet scrolls on a $width x $height screen, font x$scale', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, height);
        addTearDown(tester.view.reset);
        final c = ProviderContainer(overrides: [
          groupsRepositoryProvider.overrideWithValue(LocalGroupsRepository()),
        ]);
        addTearDown(c.dispose);
        final n = c.read(draftBillProvider.notifier);
        n.setPlace('Rustic');
        final ids = <String>[hostId];
        for (final name in ['Adnan', 'Siwom', 'Hasan']) {
          ids.add(n.addGuest(name).id);
        }
        n.addItem(name: 'Chicken burger', unitPrice: 34500);
        n.addItem(name: 'Beef kala bhuna', unitPrice: 114500);
        n.setItemsConfirmed(true);
        final items = c.read(draftBillProvider).items;
        for (final id in ids) {
          n.toggleClaim(items[0].id, id);
          n.toggleClaim(items[1].id, id);
        }
        c.listen(routerProvider, (_, _) {});
        final router = c.read(routerProvider);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: app!,
            ),
            routerConfig: router,
          ),
        ));
        await tester.pumpAndSettle();
        router.go('/bill/draft/charges');
        await tester.pumpAndSettle();
        await tester.tap(find.text('send bills'));
        await tester.pumpAndSettle();
        expect(find.text('bills sent.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Everything is reachable by scrolling: the last button comes into view.
        await tester.dragUntilVisible(find.text('settle up'), find.byType(SingleChildScrollView).last, const Offset(0, -150));
        expect(find.text('settle up'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('settle up'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
      });
    }
  });

  group('who is here', () {
    for (final (friends, width, scale) in [(3, 320.0, 1.0), (3, 411.0, 1.3), (4, 320.0, 1.0), (4, 411.0, 1.0)]) {
      testWidgets('${friends + 1} people fit a $width dp screen, font x$scale', (tester) async {
        await openNewBill(tester, friends: friends, width: width, scale: scale);
        expect(tester.takeException(), isNull);
        final chips = find.byType(AvatarChip);
        expect(chips, findsNWidgets(friends + 1)); // The host and the friends.
        for (var i = 0; i < friends + 1; i++) {
          final r = tester.getRect(chips.at(i));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(width));
        }
        await tester.pump(const Duration(milliseconds: 400));
      });
    }
  });

  group('groups', () {
    testWidgets('the active group is ticked and says so; the others are not', (tester) async {
      final (c, n, _) = await openNewBill(tester, initial: [
        const GroupCardData(id: 'g1', name: 'NSU boys', members: nsu),
        const GroupCardData(id: 'g2', name: 'Roommates', members: [Person(id: 'f9', name: 'Arif')]),
      ]);
      expect(find.byKey(const ValueKey('active-group')), findsNothing);
      expect(find.textContaining('active ·'), findsNothing);
      await tester.tap(find.text('Roommates'));
      await tester.pumpAndSettle();
      expect(c.read(draftBillProvider).groupId, 'g2');
      expect(find.byKey(const ValueKey('active-group')), findsOneWidget);
      expect(find.textContaining('active · '), findsOneWidget);
      await tester.tap(find.text('NSU boys'));
      await tester.pumpAndSettle();
      expect(c.read(draftBillProvider).groupId, 'g1');
      expect(find.byKey(const ValueKey('active-group')), findsOneWidget);
      n.setPlace('Chillox');
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the arrow picks who is away and they leave the bill', (tester) async {
      final (c, _, _) = await openNewBill(tester, friends: 0, initial: [const GroupCardData(id: 'g1', name: 'NSU boys', members: nsu)]);
      await tester.tap(find.text('NSU boys'));
      await tester.pumpAndSettle();
      expect(find.textContaining('active · 5 here · 0 away'), findsNothing); // The host is not a member.
      expect(find.textContaining('active · 4 here · 0 away'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group-away')));
      await tester.pumpAndSettle();
      expect(find.text('who is here?'), findsOneWidget);
      expect(c.read(draftBillProvider).participants.length, 5); // You and the four.

      await tester.tap(find.byKey(const ValueKey('away-f2')));
      await tester.tap(find.byKey(const ValueKey('away-f4')));
      await tester.pumpAndSettle();
      final d = c.read(draftBillProvider);
      expect(d.participants.map((p) => p.name), ['You', 'Adnan', 'Hasan']);
      expect(find.text('away'), findsNWidgets(2));

      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(find.textContaining('active · 2 here · 2 away'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a second tap on save group does not make a second group', (tester) async {
      final repo = _SlowGroups();
      await openNewBill(tester, groups: repo, friends: 2);
      await tester.tap(find.text('new group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'NSU boys');
      await tester.tap(find.text('save group'));
      await tester.pump();
      await tester.tap(find.text('save group'), warnIfMissed: false);
      await tester.pump();
      expect(repo.created, ['NSU boys']);
      repo.gate.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a name you already use is refused with a reason', (tester) async {
      await openNewBill(tester, friends: 2, initial: [const GroupCardData(id: 'g1', name: 'NSU boys', members: nsu)]);
      await tester.tap(find.text('new group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'nsu BOYS');
      await tester.tap(find.text('save group'));
      await tester.pumpAndSettle();
      expect(find.textContaining('you already have a group called'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
