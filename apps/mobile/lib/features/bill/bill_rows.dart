import 'package:split_core/split_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/ids.dart';
import 'draft_bill.dart';

const _uuid = Uuid();

/// The `bill_participants.id` for a person on a bill. Deterministic (uuid v5), so saving the
/// same draft twice updates the same rows and the draft never has to store these ids.
String participantIdFor(String billId, String personId) =>
    _uuid.v5(Namespace.url.value, 'splitup:$billId:$personId');

/// A draft bill laid out as rows for the tables, ready for upserts. Pure, so it is unit tested
/// without a database.
class BillRows {
  const BillRows({
    required this.friends,
    required this.bill,
    required this.participants,
    required this.items,
    required this.claims,
    required this.charges,
  });

  final List<Map<String, dynamic>> friends;
  final Map<String, dynamic> bill;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> claims;
  final List<Map<String, dynamic>> charges;
}

BillRows draftToRows(DraftBill d, {required String hostUserId, required String hostName}) {
  final people = d.participants;
  final here = people.map((p) => p.id).toSet();
  final friends = [
    for (final p in people)
      if (!p.isHost)
        {
          'id': p.id,
          'owner_id': hostUserId,
          'name': p.name,
          'phone': p.phone,
          'avatar_color': p.avatarColor,
        },
  ];
  final custom = d.splitMode == SplitMode.custom;
  final sharing = d.sharing;
  final participants = [
    for (var i = 0; i < people.length; i++)
      {
        'id': participantIdFor(d.id, people[i].id),
        'bill_id': d.id,
        'friend_id': people[i].isHost ? null : people[i].id,
        'user_id': people[i].isHost ? hostUserId : null,
        'name': people[i].isHost ? hostName : people[i].name,
        'is_host': people[i].isHost,
        'position': i,
        'in_split': sharing.contains(people[i].id),
        'custom_amount': custom ? (d.customAmounts[people[i].id] ?? 0) : null,
      },
  ];
  final items = [
    for (var i = 0; i < d.items.length; i++)
      {
        'id': d.items[i].id,
        'bill_id': d.id,
        'name': d.items[i].name.trim(),
        'qty': d.items[i].qty,
        'unit_price': d.items[i].unitPrice,
        'position': i,
      },
  ];
  final claims = [
    for (final item in d.items)
      for (final personId in (d.claims[item.id] ?? const <String>{}))
        if (here.contains(personId))
          {'item_id': item.id, 'participant_id': participantIdFor(d.id, personId)},
  ];
  return BillRows(
    friends: friends,
    bill: {
      'id': d.id,
      'place': d.place.trim(),
      'created_by': hostUserId,
      'group_id': isUuid(d.groupId) ? d.groupId : null,
      'split_mode': d.splitMode.name,
      'extras_mode': d.extrasMode == ExtrasMode.byItems ? 'by_items' : 'equally',
      'status': 'draft',
      'receipt_path': d.receiptPath,
      'subtotal': d.subtotal,
      'total': d.total,
    },
    participants: participants,
    items: items,
    claims: claims,
    charges: [
      {'bill_id': d.id, 'type': 'vat', 'rate_bp': d.vatRateBp, 'amount': d.vatAmount},
      {'bill_id': d.id, 'type': 'service', 'rate_bp': d.serviceRateBp, 'amount': d.serviceAmount},
    ],
  );
}
