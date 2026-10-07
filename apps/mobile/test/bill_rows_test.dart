import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';
import 'package:splitup/core/ids.dart';
import 'package:splitup/features/bill/bill_repository.dart';
import 'package:splitup/features/bill/bill_rows.dart';
import 'package:splitup/features/bill/draft_bill.dart';
import 'package:splitup/features/bill/draft_bill_notifier.dart';
import 'package:splitup/ui/settle_row.dart' show SettleMethod;

const hostUser = '00000000-0000-0000-0000-00000000000a';

(DraftBill, Map<String, String>) chillox({SplitMode mode = SplitMode.items}) {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final n = c.read(draftBillProvider.notifier);
  n.setPlace('  Chillox ');
  final ids = {
    'you': hostId,
    'rafi': n.addGuest('Rafi', phone: '01711111111').id,
    'nabil': n.addGuest('Nabil').id,
    'tania': n.addGuest('Tania').id,
  };
  n.addItem(name: 'Chicken burger', unitPrice: 34500);
  n.addItem(name: 'Beef kala bhuna', unitPrice: 114500);
  n.addItem(name: 'Fries', unitPrice: 24000);
  n.addItem(name: 'Coke', qty: 3, unitPrice: 9000);
  final items = c.read(draftBillProvider).items;
  void claim(int i, List<String> who) {
    for (final w in who) {
      n.toggleClaim(items[i].id, ids[w]!);
    }
  }

  claim(0, ['you']);
  claim(1, ['rafi', 'nabil']);
  claim(2, ['you', 'tania']);
  claim(3, ['you', 'rafi', 'tania']);
  n.setSplitMode(mode);
  return (c.read(draftBillProvider), ids);
}

void main() {
  test('a fresh draft has a real uuid and ids that fit the database', () {
    final (d, ids) = chillox();
    expect(isUuid(d.id), isTrue);
    expect(d.items.every((i) => isUuid(i.id)), isTrue);
    expect(ids.entries.where((e) => e.key != 'you').every((e) => isUuid(e.value)), isTrue);
  });

  test('rows: bill, people, items, claims and charges for Chillox', () {
    final (d, ids) = chillox();
    final r = draftToRows(d, hostUserId: hostUser, hostName: 'Salman');

    expect(r.bill, {
      'id': d.id,
      'place': 'Chillox', // trimmed
      'created_by': hostUser,
      'group_id': null,
      'split_mode': 'items',
      'extras_mode': 'equally',
      'status': 'draft',
      'subtotal': 200000,
      'total': 223600,
    });

    expect(r.participants.length, 4);
    final host = r.participants.first;
    expect(host['is_host'], isTrue);
    expect(host['user_id'], hostUser);
    expect(host['friend_id'], isNull);
    expect(host['name'], 'Salman'); // the profile name, not "You"
    expect(r.participants[1]['friend_id'], ids['rafi']);
    expect(r.participants[1]['user_id'], isNull);
    expect(r.participants.map((p) => p['position']), [0, 1, 2, 3]);
    expect(r.participants.every((p) => p['custom_amount'] == null), isTrue);

    expect(r.friends.length, 3); // the host is not a friend row
    expect(r.friends.first['owner_id'], hostUser);
    expect(r.friends.first['phone'], '01711111111');

    expect(r.items.map((i) => [i['name'], i['qty'], i['unit_price']]), [
      ['Chicken burger', 1, 34500],
      ['Beef kala bhuna', 1, 114500],
      ['Fries', 1, 24000],
      ['Coke', 3, 9000],
    ]);
    expect(r.claims.length, 8); // 1 + 2 + 2 + 3
    final participantIds = r.participants.map((p) => p['id']).toSet();
    expect(r.claims.every((c) => participantIds.contains(c['participant_id'])), isTrue);

    expect(r.charges, [
      {'bill_id': d.id, 'type': 'vat', 'rate_bp': 590, 'amount': 11800},
      {'bill_id': d.id, 'type': 'service', 'rate_bp': 590, 'amount': 11800},
    ]);
  });

  test('participant ids are stable across saves and unique per bill', () {
    final (d, _) = chillox();
    final a = draftToRows(d, hostUserId: hostUser, hostName: 'S').participants.map((p) => p['id']).toList();
    final b = draftToRows(d, hostUserId: hostUser, hostName: 'S').participants.map((p) => p['id']).toList();
    expect(a, b);
    expect(a.toSet().length, 4);
    expect(a.every((id) => isUuid(id as String)), isTrue);
    expect(participantIdFor(d.id, hostId), isNot(participantIdFor(newUuid(), hostId)));
  });

  test('custom mode stores typed amounts, equally mode stores who shares', () {
    var (d, ids) = chillox(mode: SplitMode.custom);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    d = d.copyWith(customAmounts: {hostId: 61400, ids['rafi']!: 72150});
    final custom = draftToRows(d, hostUserId: hostUser, hostName: 'S');
    expect(custom.bill['split_mode'], 'custom');
    expect(custom.participants.map((p) => p['custom_amount']), [61400, 72150, 0, 0]);

    final eq = draftToRows(
      d.copyWith(splitMode: SplitMode.equally, sharingIds: {hostId, ids['rafi']!}),
      hostUserId: hostUser,
      hostName: 'S',
    );
    expect(eq.participants.map((p) => p['in_split']), [true, true, false, false]);
    expect(eq.participants.every((p) => p['custom_amount'] == null), isTrue);
  });

  test('someone who left the bill has no row and no claims', () {
    final (d, ids) = chillox();
    final without = d.copyWith(presentIds: d.presentIds.difference({ids['rafi']!}));
    final r = draftToRows(without, hostUserId: hostUser, hostName: 'S');
    expect(r.participants.length, 3);
    expect(r.participants.any((p) => p['friend_id'] == ids['rafi']), isFalse);
    expect(r.friends.any((f) => f['id'] == ids['rafi']), isFalse);
    final rafiParticipant = participantIdFor(d.id, ids['rafi']!);
    expect(r.claims.any((c) => c['participant_id'] == rafiParticipant), isFalse);
  });

  test('group id is only sent when it is a real uuid (demo groups are not)', () {
    final (d, _) = chillox();
    expect(draftToRows(d.copyWith(groupId: 'g_nsu'), hostUserId: hostUser, hostName: 'S').bill['group_id'], isNull);
    final id = newUuid();
    expect(draftToRows(d.copyWith(groupId: id), hostUserId: hostUser, hostName: 'S').bill['group_id'], id);
  });

  test('settlement rows: paid + owed always equals the share', () {
    final (d0, ids) = chillox();
    var d = d0;
    // Rafi pays bKash in full, Tania owes a 200 tab, Nabil has not been ticked.
    d = d.copyWith(settlements: {
      ids['rafi']!: const SettleEntry(method: SettleMethod.bkash),
      ids['tania']!: const SettleEntry(method: SettleMethod.owesMe, owed: 20000),
    });
    expect(settlementRow(d, ids['rafi']!), {
      'method': 'bkash', 'paid_amount': 72150, 'owed_amount': 0, 'covered_amount': 0,
    });
    expect(settlementRow(d, ids['tania']!), {
      'method': 'owes_me', 'paid_amount': 6900, 'owed_amount': 20000, 'covered_amount': 20000,
    });
    expect(settlementRow(d, ids['nabil']!), {
      'method': null, 'paid_amount': 0, 'owed_amount': 0, 'covered_amount': 0,
    });
  });

  test('method names match the database enum', () {
    for (final m in SettleMethod.values) {
      expect(methodFromDb(methodToDb(m)), m);
    }
    expect(methodToDb(SettleMethod.owesMe), 'owes_me');
    expect(methodFromDb(null), isNull);
  });
}
