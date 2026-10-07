import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';

import '../../core/person.dart';
import '../../ui/settle_row.dart' show SettleMethod;
import '../groups/groups_provider.dart';
import 'draft_bill.dart';

const _prefsKey = 'draft_bill_v1';

final draftBillProvider = NotifierProvider<DraftBillNotifier, DraftBill>(DraftBillNotifier.new);

/// Holds the half-finished bill across screens 3 to 10 and saves it locally so a killed app
/// does not lose a half-claimed bill.
class DraftBillNotifier extends Notifier<DraftBill> {
  Timer? _saveTimer;
  int _seq = 0;

  @override
  DraftBill build() {
    ref.onDispose(() => _saveTimer?.cancel());
    return const DraftBill();
  }

  // ---- persistence ----------------------------------------------------------

  /// Restore a saved draft, if any. Safe to call more than once.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return false;
      state = DraftBill.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return true;
    } catch (_) {
      return false; // A corrupt draft is not worth crashing for.
    }
  }

  void _set(DraftBill next) {
    state = next;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    _saveTimer?.cancel();
    state = const DraftBill();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  String _nextId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // ---- step 1: who and where ----------------------------------------------

  void setPlace(String place) => _set(state.copyWith(place: place));

  void toggleHere(String personId) {
    if (personId == hostId) return; // The host is always on the bill.
    final present = {...state.presentIds};
    if (!present.remove(personId)) present.add(personId);
    _set(_pruned(state.copyWith(presentIds: present)));
  }

  /// Load a saved group's members into "who is here" (host stays).
  void loadGroup(GroupCardData group) {
    final ids = {hostId, ...group.members.map((m) => m.id)};
    final known = state.people.map((p) => p.id).toSet();
    _set(_pruned(state.copyWith(
      groupId: group.id,
      people: [...state.people, ...group.members.where((m) => !known.contains(m.id))],
      presentIds: ids.difference(group.absentIds),
    )));
  }

  Person addGuest(String name, {String? phone, String? avatarColor}) {
    final colors = ['coral', 'sky', 'lime', 'lavender'];
    final guest = Person(
      id: _nextId('g'),
      name: name.trim(),
      avatarColor: avatarColor ?? colors[state.people.length % colors.length],
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    );
    _set(state.copyWith(
      people: [...state.people, guest],
      presentIds: {...state.presentIds, guest.id},
    ));
    return guest;
  }

  bool get canStartItems => state.place.trim().isNotEmpty && state.participants.length >= 2;

  // Drop claims, shares and custom amounts of people who left the bill.
  DraftBill _pruned(DraftBill b) {
    final here = b.presentIds;
    return b.copyWith(
      claims: {
        for (final e in b.claims.entries) e.key: e.value.intersection(here),
      },
      customAmounts: {
        for (final e in b.customAmounts.entries)
          if (here.contains(e.key)) e.key: e.value,
      },
      sharingIds: b.sharingIds?.intersection(here),
    );
  }

  // ---- step 2: items -------------------------------------------------------

  void addItem({String name = '', int qty = 1, int unitPrice = 0}) {
    _set(state.copyWith(
      items: [...state.items, DraftItem(id: _nextId('i'), name: name, qty: qty, unitPrice: unitPrice)],
      itemsConfirmed: false,
    ));
  }

  void replaceItems(List<DraftItem> items) {
    _set(state.copyWith(items: items, claims: const {}, itemsConfirmed: false));
  }

  void updateItem(String id, {String? name, int? qty, int? unitPrice}) {
    _set(state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id == id) i.copyWith(name: name, qty: qty, unitPrice: unitPrice) else i,
      ],
      itemsConfirmed: false,
    ));
  }

  void removeItem(String id) {
    _set(state.copyWith(
      items: [for (final i in state.items) if (i.id != id) i],
      claims: {...state.claims}..remove(id),
      itemsConfirmed: false,
    ));
  }

  void setItemsConfirmed(bool v) => _set(state.copyWith(itemsConfirmed: v));

  // ---- step 3: claims ------------------------------------------------------

  void setSplitMode(SplitMode mode) => _set(state.copyWith(splitMode: mode));

  void toggleClaim(String itemId, String personId) {
    final current = {...(state.claims[itemId] ?? const <String>{})};
    if (!current.remove(personId)) current.add(personId);
    _set(state.copyWith(claims: {...state.claims, itemId: current}));
  }

  void toggleSharing(String personId) {
    final current = {...state.sharing};
    if (!current.remove(personId)) current.add(personId);
    _set(state.copyWith(sharingIds: current));
  }

  void setCustomAmount(String personId, int poisha) {
    _set(state.copyWith(customAmounts: {...state.customAmounts, personId: poisha}));
  }

  /// Share what is left of the total between the people who have no amount yet.
  void splitRestEqually() {
    final rest = state.customDifference;
    final empty = [
      for (final id in state.participantIds)
        if ((state.customAmounts[id] ?? 0) == 0) id,
    ];
    if (rest <= 0 || empty.isEmpty) return;
    final parts = splitEqually(rest, empty.length);
    final next = {...state.customAmounts};
    for (var i = 0; i < empty.length; i++) {
      next[empty[i]] = parts[i];
    }
    _set(state.copyWith(customAmounts: next));
  }

  // ---- step 3b: charges ----------------------------------------------------

  void setVatRate(int bp) => _set(state.copyWith(vatRateBp: bp));
  void setServiceRate(int bp) => _set(state.copyWith(serviceRateBp: bp));
  void setExtrasMode(ExtrasMode mode) => _set(state.copyWith(extrasMode: mode));

  /// "send bills". Local only until the backend (milestone 4) finalizes it server side.
  bool sendBills() {
    if (state.result == null) return false;
    _set(state.copyWith(status: DraftStatus.open, settlements: const {}));
    return true;
  }

  // ---- settle --------------------------------------------------------------

  void setMethod(String personId, SettleMethod method) {
    final share = state.shareOf(personId);
    final entry = method == SettleMethod.owesMe
        ? SettleEntry(method: method, owed: share)
        : SettleEntry(method: method);
    _set(state.copyWith(settlements: {...state.settlements, personId: entry}));
  }

  /// The tab a friend still owes (host covers the rest). Clamped to their share.
  void setOwed(String personId, int owed) {
    final share = state.shareOf(personId);
    final current = state.entryOf(personId);
    _set(state.copyWith(settlements: {
      ...state.settlements,
      personId: SettleEntry(
        method: current.method ?? SettleMethod.owesMe,
        owed: owed.clamp(0, share),
      ),
    }));
  }

  /// Marks the bill settled. Open tabs stay open.
  bool finishBill() {
    if (!state.allFriendsSettled) return false;
    _set(state.copyWith(status: DraftStatus.settled));
    return true;
  }
}
