import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';
import 'package:splitup/features/bill/draft_bill.dart';
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/ui/settle_row.dart' show SettleMethod;

/// Builds the Chillox bill from the spec through the same notifier the screens use.
(ProviderContainer, DraftBillNotifier, Map<String, String>) chillox() {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('Chillox');
  final ids = {
    'you': hostId,
    'rafi': n.addGuest('Rafi').id,
    'nabil': n.addGuest('Nabil').id,
    'tania': n.addGuest('Tania').id,
  };
  n.addItem(name: 'Chicken burger', unitPrice: 34500);
  n.addItem(name: 'Beef kala bhuna', unitPrice: 114500);
  n.addItem(name: 'Fries', unitPrice: 24000);
  n.addItem(name: 'Coke', qty: 3, unitPrice: 9000);
  final items = c.read(draftBillProvider).items;
  void claim(int item, List<String> who) {
    for (final w in who) {
      n.toggleClaim(items[item].id, ids[w]!);
    }
  }

  claim(0, ['you']);
  claim(1, ['rafi', 'nabil']);
  claim(2, ['you', 'tania']);
  claim(3, ['you', 'rafi', 'tania']);
  return (c, n, ids);
}

Map<String, int> totals(DraftBill d, Map<String, String> ids) => {
      for (final e in ids.entries) e.key: d.shareOf(e.value),
    };

void main() {
  test('Chillox: items mode with extras equally matches the golden table', () {
    final (c, n, ids) = chillox();
    final d = c.read(draftBillProvider);
    expect(d.total, 223600);
    expect(d.claimStepValid, isTrue);
    expect(totals(d, ids), {'you': 61400, 'rafi': 72150, 'nabil': 63150, 'tania': 26900});
    expect(n.canStartItems, isTrue);
  });

  test('Chillox: extras by what they ate matches the golden table', () {
    final (c, n, ids) = chillox();
    n.setExtrasMode(ExtrasMode.byItems);
    expect(totals(c.read(draftBillProvider), ids),
        {'you': 62049, 'rafi': 74067, 'nabil': 64006, 'tania': 23478});
  });

  test('next is blocked until every item has a claimant', () {
    final (c, n, ids) = chillox();
    final fries = c.read(draftBillProvider).items[2];
    n.toggleClaim(fries.id, ids['you']!);
    n.toggleClaim(fries.id, ids['tania']!);
    final d = c.read(draftBillProvider);
    expect(d.unclaimedCount, 1);
    expect(d.claimStepValid, isFalse);
    expect(d.result, isNull);
  });

  test('equally mode splits the whole total', () {
    final (c, n, ids) = chillox();
    n.setSplitMode(SplitMode.equally);
    expect(totals(c.read(draftBillProvider), ids).values.toSet(), {55900});
    n.toggleSharing(ids['tania']!);
    final d = c.read(draftBillProvider);
    expect(d.shareOf(ids['tania']!), 0);
    expect(sum(totals(d, ids).values), 223600);
  });

  test('custom mode blocks next until exact, helper fills the rest', () {
    final (c, n, ids) = chillox();
    n.setSplitMode(SplitMode.custom);
    n.setCustomAmount(ids['you']!, 60000);
    n.setCustomAmount(ids['rafi']!, 70000);
    var d = c.read(draftBillProvider);
    expect(d.customDifference, 93600);
    expect(d.claimStepValid, isFalse);
    n.splitRestEqually();
    d = c.read(draftBillProvider);
    expect(d.customDifference, 0);
    expect(d.claimStepValid, isTrue);
    expect(sum(totals(d, ids).values), d.total);
    // Typing too much shows "over" as a negative difference.
    n.setCustomAmount(ids['you']!, 999999);
    expect(c.read(draftBillProvider).customDifference, lessThan(0));
    expect(c.read(draftBillProvider).claimStepValid, isFalse);
  });

  test('settle: Tania covered by a 200 tab, 69 in cash', () {
    final (c, n, ids) = chillox();
    expect(n.sendBills(), isTrue);
    n.setMethod(ids['rafi']!, SettleMethod.bkash);
    n.setMethod(ids['nabil']!, SettleMethod.cash);
    n.setMethod(ids['tania']!, SettleMethod.owesMe);
    n.setOwed(ids['tania']!, 20000);
    var d = c.read(draftBillProvider);
    final s = d.settleSummary;
    // Host (You) owes their own 614, so the friends' target is 2,236 - 614 = 1,622.
    expect(s.target, 162200);
    expect(s.collected, 142200);
    expect(s.openTabs, 20000);
    expect(d.paidBy(ids['tania']!), 6900);
    expect(d.allFriendsSettled, isTrue);
    expect(n.finishBill(), isTrue);
    d = c.read(draftBillProvider);
    expect(d.status, DraftStatus.settled);
    expect(d.entryOf(ids['tania']!).owed, 20000); // The tab stays open.
  });

  test('tab is clamped to the friend\'s share', () {
    final (c, n, ids) = chillox();
    n.sendBills();
    n.setMethod(ids['tania']!, SettleMethod.owesMe);
    n.setOwed(ids['tania']!, 99999999);
    expect(c.read(draftBillProvider).entryOf(ids['tania']!).owed, 26900);
    n.setOwed(ids['tania']!, -5);
    expect(c.read(draftBillProvider).entryOf(ids['tania']!).owed, 0);
  });

  test('removing someone from the bill drops their claims', () {
    final (c, n, ids) = chillox();
    n.toggleHere(ids['rafi']!);
    final d = c.read(draftBillProvider);
    expect(d.claims.values.every((s) => !s.contains(ids['rafi'])), isTrue);
    expect(d.participants.length, 3);
  });

  test('draft survives a restart (json round trip via shared_preferences)', () async {
    final (c, _, ids) = chillox();
    await Future<void>.delayed(const Duration(milliseconds: 400)); // debounce
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    expect(await c2.read(draftBillProvider.notifier).restore(), isTrue);
    final d = c2.read(draftBillProvider);
    expect(d.place, 'Chillox');
    expect(d.total, 223600);
    expect(d.shareOf(ids['rafi']!), c.read(draftBillProvider).shareOf(ids['rafi']!));
  });

  test('place and at least two people are needed to start', () {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(draftBillProvider.notifier);
    expect(n.canStartItems, isFalse);
    n.setPlace('Chillox');
    expect(n.canStartItems, isFalse); // Only the host is here.
    n.addGuest('Rafi');
    expect(n.canStartItems, isTrue);
  });
}

int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
