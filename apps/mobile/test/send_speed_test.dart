import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitbit/features/bill/bill_repository.dart';
import 'package:splitbit/features/bill/bills_provider.dart';
import 'package:splitbit/features/bill/draft_bill.dart';
import 'package:splitbit/features/bill/draft_bill_notifier.dart';
import 'package:splitbit/features/groups/groups_provider.dart';
import 'package:splitbit/features/groups/groups_repository.dart';
import 'package:splitbit/features/share/share_service.dart';
import 'package:splitbit/router.dart';
import 'package:splitbit/theme/app_theme.dart';

import 'scan_share_test.dart' show FakeShare;

/// A server that answers when the test says so, and counts what it was asked.
class SlowServer extends LocalBillRepository {
  int saves = 0;
  int finalizes = 0;
  bool lastFinalizeSaved = false;
  Completer<void>? gate;
  Object? failWith;

  @override
  bool get enabled => true; // Background sync on, like a logged in phone.

  @override
  Future<void> saveDraft(DraftBill draft) async => saves++;

  @override
  Future<FinalizeResult> finalize(DraftBill draft, {bool saved = false}) async {
    finalizes++;
    lastFinalizeSaved = saved;
    if (!saved) saves++;
    await gate?.future;
    if (failWith != null) throw failWith!;
    return FinalizeResult(shareUrl: 'https://example.test/s/abc', total: draft.total);
  }
}

Future<(ProviderContainer, DraftBillNotifier, FakeShare)> openCharges(WidgetTester tester, SlowServer server) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final share = FakeShare();
  final c = ProviderContainer(overrides: [
    billRepositoryProvider.overrideWithValue(server),
    shareServiceProvider.overrideWithValue(share),
    groupsRepositoryProvider.overrideWithValue(LocalGroupsRepository()),
  ]);
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Rustic');
  final ids = <String>[hostId, n.addGuest('Adnan').id];
  n.addItem(name: 'Pizza', unitPrice: 55000);
  n.setItemsConfirmed(true);
  for (final id in ids) {
    n.toggleClaim(c.read(draftBillProvider).items.first.id, id);
  }
  c.listen(routerProvider, (_, _) {});
  final router = c.read(routerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: router),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  router.go('/bill/draft/charges');
  await tester.pump(const Duration(milliseconds: 500));
  return (c, n, share);
}

Future<void> settleTimers(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2000));
}

void main() {
  testWidgets('the sheet opens at once, while the server is still answering', (tester) async {
    final server = SlowServer()..gate = Completer<void>();
    final (_, _, share) = await openCharges(tester, server);
    await settleTimers(tester); // The background sync saves the draft.
    await tester.tap(find.text('send bills'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('sending...'), findsOneWidget); // No waiting on the server to see the sheet.
    expect(find.text('bills sent.'), findsNothing);
    await tester.tap(find.text('send link'), warnIfMissed: false);
    await tester.pump();
    expect(share.texts, isEmpty, reason: 'the link is not ready yet');

    server.gate!.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('bills sent.'), findsOneWidget);
    await tester.tap(find.text('send link'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(share.texts.single, contains('https://example.test/s/abc'));
    await tester.tap(find.text('settle up'));
    await tester.pump(const Duration(milliseconds: 800));
    await settleTimers(tester);
  });

  testWidgets('a send that fails closes the sheet and says why', (tester) async {
    final server = SlowServer()
      ..gate = Completer<void>()
      ..failWith = const BillSyncException('the server said no.');
    await openCharges(tester, server);
    await settleTimers(tester);
    await tester.tap(find.text('send bills'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('sending...'), findsOneWidget);

    server.gate!.complete();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('sending...'), findsNothing);
    expect(find.text('bills sent.'), findsNothing);
    expect(find.text('the server said no.'), findsOneWidget);
    expect(find.text('send bills'), findsOneWidget, reason: 'still on the screen, ready to try again');
    await settleTimers(tester);
  });

  testWidgets('a draft the background sync already saved is not saved again', (tester) async {
    final server = SlowServer();
    await openCharges(tester, server);
    await settleTimers(tester);
    final savedBefore = server.saves;
    expect(savedBefore, greaterThan(0));

    await tester.tap(find.text('send bills'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(server.saves, savedBefore, reason: 'nothing changed, so nothing to save');
    expect(server.finalizes, 1);
    expect(server.lastFinalizeSaved, isTrue);
    await settleTimers(tester);
  });

  testWidgets('a change not yet synced is saved before sending', (tester) async {
    final server = SlowServer();
    final (_, n, _) = await openCharges(tester, server);
    await settleTimers(tester);
    final savedBefore = server.saves;
    n.setVatRate(500); // Changed just now: the 1.2 s sync has not fired.
    await tester.tap(find.text('send bills'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(server.saves, savedBefore + 1);
    expect(server.finalizes, 1);
    await settleTimers(tester);
  });
}
