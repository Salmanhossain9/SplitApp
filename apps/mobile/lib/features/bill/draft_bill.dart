import 'package:split_core/split_core.dart';

import '../../core/ids.dart';
import '../../core/person.dart';
import '../../ui/settle_row.dart' show SettleMethod;

const hostId = 'you';
const hostPerson = Person(id: hostId, name: 'You', isHost: true);

/// Sample rate from the designs (5.9%). Both charges default to it and are editable.
const defaultChargeRateBp = 590;

enum DraftStatus { draft, open, settled }

class DraftItem {
  const DraftItem({required this.id, required this.name, this.qty = 1, this.unitPrice = 0});

  final String id;
  final String name;
  final int qty;

  /// poisha
  final int unitPrice;

  int get lineTotal => qty * unitPrice;

  DraftItem copyWith({String? name, int? qty, int? unitPrice}) => DraftItem(
        id: id,
        name: name ?? this.name,
        qty: qty ?? this.qty,
        unitPrice: unitPrice ?? this.unitPrice,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'qty': qty, 'unitPrice': unitPrice};

  factory DraftItem.fromJson(Map<String, dynamic> j) => DraftItem(
        id: j['id'] as String,
        name: j['name'] as String,
        qty: j['qty'] as int,
        unitPrice: j['unitPrice'] as int,
      );
}

/// How one friend settles. `owed` is the open tab (poisha).
class SettleEntry {
  const SettleEntry({this.method, this.owed = 0});

  final SettleMethod? method;
  final int owed;

  Map<String, dynamic> toJson() => {'method': method?.name, 'owed': owed};

  factory SettleEntry.fromJson(Map<String, dynamic> j) => SettleEntry(
        method: j['method'] == null
            ? null
            : SettleMethod.values.byName(j['method'] as String),
        owed: j['owed'] as int,
      );
}

class DraftBill {
  const DraftBill({
    this.id = 'draft',
    this.place = '',
    this.groupId,
    this.people = const [hostPerson],
    this.presentIds = const {hostId},
    this.items = const [],
    this.claims = const {},
    this.splitMode = SplitMode.items,
    this.sharingIds,
    this.customAmounts = const {},
    this.vatRateBp = defaultChargeRateBp,
    this.serviceRateBp = defaultChargeRateBp,
    this.extrasMode = ExtrasMode.equally,
    this.itemsConfirmed = false,
    this.status = DraftStatus.draft,
    this.settlements = const {},
    this.shareUrl,
    this.scannedTotal,
  });

  /// A new draft with a real UUID, so it can become a `bills` row as is.
  factory DraftBill.fresh() => DraftBill(id: newUuid());

  final String id;
  final String place;
  final String? groupId;

  /// Everyone who could be on this bill (host first). `presentIds` says who is here.
  final List<Person> people;
  final Set<String> presentIds;
  final List<DraftItem> items;

  /// itemId -> participant ids
  final Map<String, Set<String>> claims;
  final SplitMode splitMode;

  /// "equally" mode: who shares. null means everyone present.
  final Set<String>? sharingIds;
  final Map<String, int> customAmounts;
  final int vatRateBp;
  final int serviceRateBp;
  final ExtrasMode extrasMode;
  final bool itemsConfirmed;
  final DraftStatus status;
  final Map<String, SettleEntry> settlements;

  /// The link friends open (set once the bills are sent).
  final String? shareUrl;

  /// The total the scanner read off the receipt, to check against ours (poisha).
  final int? scannedTotal;

  // ---- derived -------------------------------------------------------------

  List<Person> get participants => [for (final p in people) if (presentIds.contains(p.id)) p];

  List<String> get participantIds => [for (final p in participants) p.id];

  Person? personById(String id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<SplitItem> get splitItems => [
        for (final i in items) SplitItem(id: i.id, qty: i.qty, unitPrice: i.unitPrice),
      ];

  Map<String, List<String>> get claimLists => {
        for (final e in claims.entries) e.key: e.value.toList(),
      };

  ChargeInput get vat => ChargeInput(rateBp: vatRateBp);
  ChargeInput get service => ChargeInput(rateBp: serviceRateBp);

  int get subtotal => itemsSubtotal(splitItems);
  int get vatAmount => chargeAmount(subtotal, vat);
  int get serviceAmount => chargeAmount(subtotal, service);
  int get extras => vatAmount + serviceAmount;
  int get total => subtotal + extras;

  Set<String> get sharing =>
      (sharingIds ?? participantIds.toSet()).intersection(participantIds.toSet());

  int get unclaimedCount => unclaimedItemIds(splitItems, claimLists).length;
  int get claimedCount => items.length - unclaimedCount;
  bool get allClaimed => items.isNotEmpty && unclaimedCount == 0;

  /// Sum of the typed custom amounts for people who are here.
  int get customAssigned =>
      participantIds.fold(0, (a, id) => a + (customAmounts[id] ?? 0));

  /// Positive = still to assign, negative = over.
  int get customDifference => total - customAssigned;

  /// Everything the claim step needs before moving on.
  bool get claimStepValid => switch (splitMode) {
        SplitMode.items => allClaimed,
        SplitMode.equally => items.isNotEmpty && sharing.isNotEmpty,
        SplitMode.custom => items.isNotEmpty && total > 0 && customDifference == 0,
      };

  bool get itemsStepValid =>
      itemsConfirmed && items.isNotEmpty && items.every((i) => i.unitPrice > 0 && i.name.trim().isNotEmpty);

  /// Live shares, or null while the claim state is not valid yet.
  ComputeResult? get result {
    if (participants.isEmpty || !claimStepValid) return null;
    try {
      final r = computeShares(
        participants: participantIds,
        items: splitItems,
        claims: claimLists,
        vat: vat,
        service: service,
        splitMode: splitMode,
        extrasMode: extrasMode,
        customAmounts: customAmounts,
        sharing: sharing.toList(),
      );
      return r.sharesSum == r.total ? r : null;
    } on SplitException {
      return null;
    }
  }

  // ---- settle ---------------------------------------------------------------

  int shareOf(String personId) {
    final r = result;
    if (r == null) return 0;
    return r.shares.firstWhere((s) => s.participantId == personId).total;
  }

  /// Friends who owe the host (everyone present except the host).
  List<Person> get friends => [for (final p in participants) if (!p.isHost) p];

  SettleEntry entryOf(String personId) => settlements[personId] ?? const SettleEntry();

  /// How much a friend has actually paid the host so far.
  int paidBy(String personId) {
    final e = entryOf(personId);
    if (e.method == null) return 0;
    return shareOf(personId) - e.owed;
  }

  SettleSummary get settleSummary => summarizeSettlement([
        for (final p in participants)
          (
            isHost: p.isHost,
            shareTotal: shareOf(p.id),
            paid: paidBy(p.id),
            owed: p.isHost ? 0 : entryOf(p.id).owed,
          ),
      ]);

  bool get allFriendsSettled => friends.isNotEmpty && friends.every((f) => entryOf(f.id).method != null);

  // ---- copy / json ----------------------------------------------------------

  DraftBill copyWith({
    String? id,
    String? place,
    String? groupId,
    bool clearGroup = false,
    List<Person>? people,
    Set<String>? presentIds,
    List<DraftItem>? items,
    Map<String, Set<String>>? claims,
    SplitMode? splitMode,
    Set<String>? sharingIds,
    bool clearSharing = false,
    Map<String, int>? customAmounts,
    int? vatRateBp,
    int? serviceRateBp,
    ExtrasMode? extrasMode,
    bool? itemsConfirmed,
    DraftStatus? status,
    Map<String, SettleEntry>? settlements,
    String? shareUrl,
    int? scannedTotal,
    bool clearScannedTotal = false,
  }) =>
      DraftBill(
        id: id ?? this.id,
        place: place ?? this.place,
        groupId: clearGroup ? null : (groupId ?? this.groupId),
        people: people ?? this.people,
        presentIds: presentIds ?? this.presentIds,
        items: items ?? this.items,
        claims: claims ?? this.claims,
        splitMode: splitMode ?? this.splitMode,
        sharingIds: clearSharing ? null : (sharingIds ?? this.sharingIds),
        customAmounts: customAmounts ?? this.customAmounts,
        vatRateBp: vatRateBp ?? this.vatRateBp,
        serviceRateBp: serviceRateBp ?? this.serviceRateBp,
        extrasMode: extrasMode ?? this.extrasMode,
        itemsConfirmed: itemsConfirmed ?? this.itemsConfirmed,
        status: status ?? this.status,
        settlements: settlements ?? this.settlements,
        shareUrl: shareUrl ?? this.shareUrl,
        scannedTotal: clearScannedTotal ? null : (scannedTotal ?? this.scannedTotal),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'place': place,
        'groupId': groupId,
        'people': [
          for (final p in people)
            {
              'id': p.id,
              'name': p.name,
              'avatarColor': p.avatarColor,
              'isHost': p.isHost,
              'phone': p.phone,
            },
        ],
        'presentIds': presentIds.toList(),
        'items': [for (final i in items) i.toJson()],
        'claims': {for (final e in claims.entries) e.key: e.value.toList()},
        'splitMode': splitMode.name,
        'sharingIds': sharingIds?.toList(),
        'customAmounts': customAmounts,
        'vatRateBp': vatRateBp,
        'serviceRateBp': serviceRateBp,
        'extrasMode': extrasMode.name,
        'itemsConfirmed': itemsConfirmed,
        'status': status.name,
        'settlements': {for (final e in settlements.entries) e.key: e.value.toJson()},
        'shareUrl': shareUrl,
        'scannedTotal': scannedTotal,
      };

  factory DraftBill.fromJson(Map<String, dynamic> j) => DraftBill(
        id: j['id'] as String,
        place: j['place'] as String,
        groupId: j['groupId'] as String?,
        people: [
          for (final p in j['people'] as List)
            Person(
              id: p['id'] as String,
              name: p['name'] as String,
              avatarColor: p['avatarColor'] as String,
              isHost: p['isHost'] as bool,
              phone: p['phone'] as String?,
            ),
        ],
        presentIds: (j['presentIds'] as List).cast<String>().toSet(),
        items: [for (final i in j['items'] as List) DraftItem.fromJson(i as Map<String, dynamic>)],
        claims: {
          for (final e in (j['claims'] as Map<String, dynamic>).entries)
            e.key: (e.value as List).cast<String>().toSet(),
        },
        splitMode: SplitMode.values.byName(j['splitMode'] as String),
        sharingIds: (j['sharingIds'] as List?)?.cast<String>().toSet(),
        customAmounts: (j['customAmounts'] as Map<String, dynamic>).cast<String, int>(),
        vatRateBp: j['vatRateBp'] as int,
        serviceRateBp: j['serviceRateBp'] as int,
        extrasMode: ExtrasMode.values.byName(j['extrasMode'] as String),
        itemsConfirmed: j['itemsConfirmed'] as bool,
        status: DraftStatus.values.byName(j['status'] as String),
        settlements: {
          for (final e in (j['settlements'] as Map<String, dynamic>).entries)
            e.key: SettleEntry.fromJson(e.value as Map<String, dynamic>),
        },
      );
}
