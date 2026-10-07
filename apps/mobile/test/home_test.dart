import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup/core/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:splitup/core/person.dart';
import 'package:splitup/core/phone.dart';
import 'package:splitup/features/auth/auth_providers.dart';
import 'package:splitup/features/bill/bill_repository.dart';
import 'package:splitup/features/bill/bill_summary.dart';
import 'package:splitup/features/bill/bills_provider.dart';
import 'package:splitup/features/bill/draft_bill.dart';
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/features/notifications/notifications_repository.dart';
import 'package:splitup/features/notifications/push_service.dart';
import 'package:splitup/features/share/share_service.dart';
import 'package:splitup/router.dart';
import 'package:splitup/theme/app_theme.dart';
import 'package:splitup/ui/ui.dart';

import 'scan_share_test.dart' show FakeShare;

final now = DateTime(2026, 9, 14, 20, 30); // a Monday evening in September


BillSummary bill(String id, DateTime at, int total, {int target = 0, int collected = 0, List<OpenTab> tabs = const [], bool settled = false}) =>
    BillSummary(
      id: id,
      place: id,
      billedAt: at,
      total: total,
      status: settled ? DraftStatus.settled : DraftStatus.open,
      friendCount: 3,
      target: target,
      collected: collected,
      tabs: tabs,
    );

OpenTab tab(String name, int owed) =>
    OpenTab(billId: 'b', participantId: 'p-$name', personName: name, place: 'Chillox', owed: owed);

void main() {
  group('greeting and dates', () {
    test('changes through the day', () {
      String at(int h) => greetingFor(DateTime(2026, 1, 1, h));
      expect(at(4), 'good night.');
      expect(at(5), 'good morning.');
      expect(at(11), 'good morning.');
      expect(at(12), 'good afternoon.');
      expect(at(16), 'good afternoon.');
      expect(at(17), 'good evening.');
      expect(at(20), 'good evening.');
      expect(at(21), 'good night.');
      expect(at(0), 'good night.');
    });

    test('bill dates and relative times', () {
      expect(formatBillDate(DateTime(2026, 9, 12)), 'Sep 12');
      expect(billMeta(bill('x', DateTime(2026, 9, 21), 1)), '4 people · Sep 21');
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), '5m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3h ago');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now), '2d ago');
      expect(timeAgo(DateTime(2026, 8, 1), now), '1/8');
    });
  });

  group('dashboard maths', () {
    test('this month, settled vs pending, and what is owed overall', () {
      final bills = [
        // This month.
        bill('Chillox', DateTime(2026, 9, 12), 223600, target: 162200, collected: 142200, tabs: [tab('Tania', 20000)], settled: true),
        bill('Pizza', DateTime(2026, 9, 3), 150000, target: 100000, collected: 100000, settled: true),
        // Last month: not in "this month", but still owed.
        bill('Old', DateTime(2026, 8, 20), 98000, target: 73000, collected: 40000),
      ];
      final d = Dashboard.from(bills, now);
      expect(d.monthBills, 2);
      expect(d.monthTotal, 373600);
      expect(d.monthPending, 20000);
      expect(d.monthSettled, 353600);
      expect(d.monthSettled + d.monthPending, d.monthTotal);
      expect(d.owedToMe, 20000 + 0 + 33000);
      expect(d.tabs.map((t) => t.personName), ['Tania']);
    });

    test('empty list is all zeros', () {
      final d = Dashboard.from(const [], now);
      expect([d.monthTotal, d.monthBills, d.owedToMe, d.tabs.length], [0, 0, 0, 0]);
    });

    test('the status pill: tab beats settled, open is pending', () {
      expect(bill('a', now, 1, tabs: [tab('T', 1)], settled: true).pill, BillStatus.tab);
      expect(bill('a', now, 1, settled: true).pill, BillStatus.settled);
      expect(bill('a', now, 1).pill, BillStatus.pending);
    });
  });

  group('summaries from rows and drafts', () {
    test('fromRow reads the nested query (Chillox with Tania on a 200 tab)', () {
      final s = BillSummary.fromRow({
        'id': 'b1',
        'place': 'Chillox',
        'total': 223600,
        'status': 'settled',
        'billed_at': '2026-09-12T14:42:00Z',
        'bill_participants': [
          {'id': 'p0', 'name': 'Demo', 'is_host': true, 'user_id': 'u'},
          {'id': 'p1', 'name': 'Rafi', 'is_host': false, 'user_id': null},
          {'id': 'p2', 'name': 'Nabil', 'is_host': false, 'user_id': null},
          {'id': 'p3', 'name': 'Tania', 'is_host': false, 'user_id': 'tania-user'},
        ],
        'shares': [
          {'participant_id': 'p0', 'total': 61400},
          {'participant_id': 'p1', 'total': 72150},
          {'participant_id': 'p2', 'total': 63150},
          {'participant_id': 'p3', 'total': 26900},
        ],
        'settlements': [
          {'participant_id': 'p1', 'method': 'bkash', 'paid_amount': 72150, 'owed_amount': 0, 'last_reminded_at': null},
          {'participant_id': 'p2', 'method': 'cash', 'paid_amount': 63150, 'owed_amount': 0, 'last_reminded_at': null},
          {'participant_id': 'p3', 'method': 'owes_me', 'paid_amount': 6900, 'owed_amount': 20000, 'last_reminded_at': '2026-09-13T10:00:00Z'},
        ],
      });
      expect(s.friendCount, 3);
      expect(s.target, 162200);
      expect(s.collected, 142200);
      expect(s.outstanding, 20000);
      expect(s.status, DraftStatus.settled);
      expect(s.pill, BillStatus.tab);
      final t = s.tabs.single;
      expect([t.personName, t.owed, t.isAppUser, t.participantId], ['Tania', 20000, true, 'p3']);
      expect(t.lastRemindedAt, isNotNull);
    });

    test('an unticked friend is outstanding but not a tab', () {
      final s = BillSummary.fromRow({
        'id': 'b', 'place': 'X', 'total': 1000, 'status': 'open', 'billed_at': '2026-09-12T14:42:00Z',
        'bill_participants': [
          {'id': 'p0', 'name': 'H', 'is_host': true, 'user_id': 'u'},
          {'id': 'p1', 'name': 'R', 'is_host': false, 'user_id': null},
        ],
        'shares': [{'participant_id': 'p0', 'total': 400}, {'participant_id': 'p1', 'total': 600}],
        'settlements': [{'participant_id': 'p1', 'method': null, 'paid_amount': 0, 'owed_amount': 0, 'last_reminded_at': null}],
      });
      expect([s.target, s.collected, s.outstanding, s.tabs.length], [600, 0, 600, 0]);
      expect(s.pill, BillStatus.pending);
    });
  });

  group('resume', () {
    test('goes to the right step', () {
      final empty = DraftBill.fresh();
      expect(isResumable(empty), isFalse);
      var d = empty.copyWith(place: 'Chillox');
      expect(isResumable(d), isFalse); // No items yet.
      d = d.copyWith(items: const [DraftItem(id: 'i', name: 'Tea', unitPrice: 5000)]);
      expect(isResumable(d), isTrue);
      expect(resumeLocation(d), '/bill/new'); // Only the host is here.
      d = d.copyWith(people: [hostPerson, const Person(id: 'rafi', name: 'Rafi')], presentIds: {hostId, 'rafi'});
      expect(resumeLocation(d), '/bill/${d.id}/items'); // Not confirmed.
      d = d.copyWith(itemsConfirmed: true);
      expect(resumeLocation(d), '/bill/${d.id}/claim');
      d = d.copyWith(claims: {'i': {hostId}});
      expect(resumeLocation(d), '/bill/${d.id}/charges');
      d = d.copyWith(status: DraftStatus.open);
      expect(resumeLocation(d), '/bill/${d.id}/settle');
      expect(isResumable(d.copyWith(status: DraftStatus.settled)), isFalse);
    });
  });

  group('notifications', () {
    test('text in the app\'s voice', () {
      final n = AppNotification(
        id: '1', kind: 'remind', createdAt: now,
        payload: {'place': 'Chillox', 'host_name': 'Salman', 'owed_amount': 20000},
      );
      expect(n.text, ('a friendly nudge', 'You still owe Salman ৳200 for Chillox.'));
      expect(n.unread, isTrue);
      expect(AppNotification.fromRow({'id': '2', 'kind': 'x', 'payload': {}, 'created_at': '2026-09-14T00:00:00Z', 'read_at': '2026-09-14T01:00:00Z'}).unread, isFalse);
    });
  });

  group('push registration', () {
    PushRegistrar make({bool allowed = true, String? token = 'tok-1', required List<(String, String?)> saved, Stream<String>? refresh}) => PushRegistrar(
          requestPermission: () async => allowed,
          fetchToken: () async => token,
          onTokenRefresh: () => refresh ?? const Stream.empty(),
          saveToken: (u, t) async => saved.add((u, t)),
        );

    test('stores the token, and again when it rotates', () async {
      final saved = <(String, String?)>[];
      final refresh = StreamController<String>();
      final r = make(saved: saved, refresh: refresh.stream);
      expect(await r.register('u1'), isTrue);
      refresh.add('tok-2');
      await Future<void>.delayed(Duration.zero);
      expect(saved, [('u1', 'tok-1'), ('u1', 'tok-2')]);
      await r.unregister('u1');
      expect(saved.last, ('u1', null));
      await refresh.close();
    });

    test('does nothing without permission or a token', () async {
      final saved = <(String, String?)>[];
      expect(await make(allowed: false, saved: saved).register('u'), isFalse);
      expect(await make(token: null, saved: saved).register('u'), isFalse);
      expect(saved, isEmpty);
    });

    test('the profile column row', () => expect(pushTokenRow('t'), {'push_token': 't'}));
  });

  group('local reminders', () {
    test('guests with a phone get a WhatsApp link, once a day', () async {
      final repo = LocalBillRepository(seed: false, now: now);
      const t = OpenTab(billId: 'b', participantId: 'p', personName: 'Tania', place: 'Chillox', owed: 20000, phone: '01911222333');
      final first = await repo.remind(t);
      expect(first, isA<RemindWhatsapp>());
      expect((first as RemindWhatsapp).link, startsWith('https://wa.me/8801911222333?text='));
      expect(Uri.decodeComponent(first.link), contains('You still owe ৳200 for Chillox.'));
      expect(await repo.remind(t), isA<RemindTooSoon>());
    });

    test('whatsapp numbers get the Bangladesh country code', () {
      expect(whatsappDigits('01711-111111'), '8801711111111');
      expect(whatsappDigits('+88 01911 222333'), '8801911222333');
      expect(whatsappDigits('008801911222333'), '8801911222333');
      expect(whatsappDigits('12345'), isNull);
      expect(whatsappChatUri('017', 'hi'), isNull);
    });

    test('people without a phone are just "sent"', () async {
      final repo = LocalBillRepository(seed: false, now: now);
      expect(await repo.remind(tab('Nabil', 100)), isA<RemindSent>());
    });
  });

  group('screens', () {
    late FakeShare share;

    Future<(ProviderContainer, GoRouter)> pump(
      WidgetTester tester, {
      bool seed = true,
      List<AppNotification> notifications = const [],
      String route = '/home',
      Size size = const Size(390, 844),
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      share = FakeShare();
      final c = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => now),
        billRepositoryProvider.overrideWithValue(LocalBillRepository(seed: seed, now: now)),
        shareServiceProvider.overrideWithValue(share),
        notificationsProvider.overrideWith((ref) => Stream.value(notifications)),
      ]);
      addTearDown(c.dispose);
      c.listen(routerProvider, (_, _) {});
      final router = c.read(routerProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
      ));
      await tester.pumpAndSettle();
      if (route != '/home') {
        router.go(route);
        await tester.pumpAndSettle();
      }
      return (c, router);
    }

    testWidgets('new user: greeting, one big split a bill tile, no numbers yet', (tester) async {
      await pump(tester, seed: false);
      expect(find.text('good evening.'), findsOneWidget);
      expect(find.byType(ActionTile), findsOneWidget);
      expect(find.byType(SummaryCard), findsNothing);
      expect(find.byType(BottomNav), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/home_new_user.png'));
    });

    testWidgets('dashboard: this month, you are owed, month header, bill rows', (tester) async {
      await pump(tester);
      expect(find.byType(SummaryCard), findsOneWidget);
      expect(find.text('this month'), findsOneWidget);
      expect(find.text('split across 2 bills'), findsOneWidget);
      expect(find.text('September'), findsOneWidget);
      expect(find.byType(BillRow), findsNWidgets(2));
      expect(find.text('Pizza Roma'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/home_dashboard.png'));
    });

    testWidgets('home after settle: the new bill on top with a tab pill, and the open tab', (tester) async {
      final (c, _) = await pump(tester, size: const Size(390, 1500));
      final n = c.read(draftBillProvider.notifier);
      n.setPlace('Chillox');
      final ids = {
        'rafi': n.addGuest('Rafi').id,
        'nabil': n.addGuest('Nabil').id,
        'tania': n.addGuest('Tania', phone: '01911222333').id,
      };
      n.addItem(name: 'Chicken burger', unitPrice: 34500);
      n.addItem(name: 'Beef kala bhuna', unitPrice: 114500);
      n.addItem(name: 'Fries', unitPrice: 24000);
      n.addItem(name: 'Coke', qty: 3, unitPrice: 9000);
      final items = c.read(draftBillProvider).items;
      void claim(int i, List<String> who) {
        for (final w in who) {
          n.toggleClaim(items[i].id, w == 'you' ? hostId : ids[w]!);
        }
      }

      claim(0, ['you']);
      claim(1, ['rafi', 'nabil']);
      claim(2, ['you', 'tania']);
      claim(3, ['you', 'rafi', 'tania']);
      expect((await n.sendBills()).ok, isTrue);
      n.setMethod(ids['rafi']!, SettleMethod.bkash);
      n.setMethod(ids['nabil']!, SettleMethod.cash);
      n.setMethod(ids['tania']!, SettleMethod.owesMe);
      n.setOwed(ids['tania']!, 20000);
      expect(await n.finishBill(), isTrue);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      // The dashboard picked the bill up.
      expect(find.text('Chillox'), findsOneWidget);
      expect(find.text('tab'), findsOneWidget);
      expect(find.text('Tania owes you'), findsOneWidget);
      expect(find.text('open tabs'), findsOneWidget);
      expect(find.text('1 open'), findsOneWidget);
      // Chillox is the newest, so it is first in the list.
      final rows = tester.widgetList<BillRow>(find.byType(BillRow)).toList();
      expect(rows.first.name, 'Chillox');
      expect(rows.first.status, BillStatus.tab);
      expect(rows.first.amount, 223600);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/home_after_settle.png'));

      // Remind: a guest with a phone opens a WhatsApp message.
      await tester.ensureVisible(find.text('remind'));
      await tester.tap(find.text('remind'));
      await tester.pumpAndSettle();
      expect(share.opened.single, startsWith('https://wa.me/'));
      expect(Uri.decodeComponent(share.opened.single), contains('You still owe ৳200 for Chillox.'));
      // A second tap the same day is refused with a friendly note.
      await tester.tap(find.text('remind'));
      await tester.pumpAndSettle();
      expect(find.textContaining('you already nudged Tania'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the nav switches tabs and the bell shows the coral dot for unread', (tester) async {
      await pump(tester, notifications: [
        AppNotification(
          id: '1', kind: 'remind', createdAt: now.subtract(const Duration(hours: 2)),
          payload: const {'place': 'Chillox', 'host_name': 'Salman', 'owed_amount': 20000},
        ),
      ]);
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).unreadNotifications, isTrue);
      await tester.tap(find.descendant(of: find.byType(BottomNav), matching: find.byType(AppIcon)).at(2));
      await tester.pumpAndSettle();
      expect(find.text('notifications'), findsOneWidget);
      expect(find.text('a friendly nudge'), findsOneWidget);
      expect(find.text('You still owe Salman ৳200 for Chillox.'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/notifications.png'));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('money: history grouped by month with filters', (tester) async {
      await pump(tester, route: '/money');
      expect(find.text('money'), findsOneWidget);
      expect(find.text('September'), findsOneWidget);
      expect(find.byType(BillRow), findsNWidgets(2));
      await tester.tap(find.widgetWithText(NameChip, 'settled'));
      await tester.pumpAndSettle();
      expect(find.byType(BillRow), findsOneWidget);
      expect(find.text('Pizza Roma'), findsOneWidget);
      await tester.tap(find.widgetWithText(NameChip, 'tabs'));
      await tester.pumpAndSettle();
      expect(find.byType(BillRow), findsNothing);
      expect(find.text('Nothing here.'), findsOneWidget);
      await tester.tap(find.widgetWithText(NameChip, 'all'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/money.png'));
    });

    testWidgets('settings: edit the profile and log out', (tester) async {
      final (c, _) = await pump(tester, route: '/settings');
      expect(find.text('settings'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Salman');
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '01700000000');
      await tester.pump();
      await tester.tap(find.text('save changes'));
      await tester.pumpAndSettle();
      final profile = c.read(profileProvider).value!;
      expect([profile.name, profile.bkashNumber], ['Salman', '01700000000']);
      expect(find.text('saved'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/screens/settings.png'));

      await tester.ensureVisible(find.text('log out'));
      await tester.tap(find.text('log out'));
      // The welcome sparkle loops forever, so pump time instead of settling.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('split it. skip the awkward.'), findsOneWidget); // Back on the welcome screen.
    });
  });
}
