import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_core/split_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/ids.dart';
import '../../core/person.dart';
import '../../ui/settle_row.dart' show SettleMethod;
import '../auth/auth_providers.dart';
import '../groups/groups_provider.dart';
import '../scan/scan_models.dart';
import 'bill_repository.dart';
import 'draft_bill.dart';

const _prefsKey = 'draft_bill_v1';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  if (!Env.isConfigured) return LocalBillRepository();
  return SupabaseBillRepository(Supabase.instance.client, () {
    final id = ref.read(authRepositoryProvider).userId;
    if (id == null) return null;
    return HostInfo(userId: id, name: ref.read(profileProvider).value?.name ?? 'Host');
  });
});

/// The last problem syncing with the server (null when fine). Screens show it once and clear it.
final syncErrorProvider = NotifierProvider<SyncErrorNotifier, String?>(SyncErrorNotifier.new);

class SyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void report(String message) => state = message;
  void clear() => state = null;
}

class SendResult {
  const SendResult.ok() : ok = true, message = null;
  const SendResult.failed(this.message) : ok = false;
  final bool ok;
  final String? message;
}

final draftBillProvider = NotifierProvider<DraftBillNotifier, DraftBill>(DraftBillNotifier.new);

/// Holds the half-finished bill across screens 3 to 10. It is saved locally so a killed app
/// does not lose a half-claimed bill, and synced to the server (debounced) when logged in.
class DraftBillNotifier extends Notifier<DraftBill> {
  Timer? _saveTimer;
  Timer? _syncTimer;
  StreamSubscription<Map<String, SettleEntry>>? _settleSub;

  @override
  DraftBill build() {
    ref.onDispose(() {
      _saveTimer?.cancel();
      _syncTimer?.cancel();
      _settleSub?.cancel();
    });
    return DraftBill.fresh();
  }

  BillRepository get _repo => ref.read(billRepositoryProvider);

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
    _scheduleServerSync();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  /// Draft changes go to the server a moment after the last edit, once there is something
  /// worth saving: a place, two people and an item.
  void _scheduleServerSync() {
    if (!_repo.enabled || state.status != DraftStatus.draft) return;
    final d = state;
    if (d.place.trim().isEmpty || d.participants.length < 2 || d.items.isEmpty) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 1200), () async {
      try {
        await _repo.saveDraft(state);
      } catch (e) {
        ref.read(syncErrorProvider.notifier).report(e.toString());
      }
    });
  }

  Future<void> clear() async {
    _saveTimer?.cancel();
    _syncTimer?.cancel();
    _settleSub?.cancel();
    state = DraftBill.fresh();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

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

  void setGroup(String groupId) => _set(state.copyWith(groupId: groupId));

  Person addGuest(String name, {String? phone, String? avatarColor}) {
    final colors = ['coral', 'sky', 'lime', 'lavender'];
    final guest = Person(
      id: newUuid(), // Becomes the friends row id when the draft syncs.
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
      items: [...state.items, DraftItem(id: newUuid(), name: name, qty: qty, unitPrice: unitPrice)],
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

  /// Fill the draft from a scan: items, the place if it is still empty, the detected VAT and
  /// service as rates, and the receipt total to check against. Nothing is final until the
  /// person confirms the editable list.
  void applyScan(ScanResult r) {
    final subtotal = r.subtotal;
    _set(state.copyWith(
      items: r.toDraftItems(),
      claims: const {},
      itemsConfirmed: false,
      place: state.place.trim().isEmpty && (r.place ?? '').isNotEmpty ? r.place : null,
      vatRateBp: rateBpFromAmount(r.vat, subtotal),
      serviceRateBp: rateBpFromAmount(r.service, subtotal),
      scannedTotal: r.total,
      clearScannedTotal: r.total == null,
      receiptPath: r.receiptPath,
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

  /// "send bills". With a backend this saves the draft and has `finalize-bill` recompute and
  /// store the shares; without one it only flips the local state.
  Future<SendResult> sendBills() async {
    if (state.result == null) return const SendResult.failed('the bills do not add up yet.');
    _syncTimer?.cancel();
    try {
      final r = await _repo.finalize(state);
      _set(state.copyWith(status: DraftStatus.open, settlements: const {}, shareUrl: r.shareUrl));
      return const SendResult.ok();
    } on BillSyncException catch (e) {
      return SendResult.failed(e.message);
    } catch (_) {
      return const SendResult.failed('could not send the bills. try again.');
    }
  }

  // ---- settle --------------------------------------------------------------

  void setMethod(String personId, SettleMethod method) {
    final share = state.shareOf(personId);
    final entry = method == SettleMethod.owesMe
        ? SettleEntry(method: method, owed: share)
        : SettleEntry(method: method);
    _set(state.copyWith(settlements: {...state.settlements, personId: entry}));
    _pushSettlement(personId);
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
    _pushSettlement(personId);
  }

  void _pushSettlement(String personId) {
    if (!_repo.enabled) return;
    _repo.saveSettlement(state, personId).catchError((Object e) {
      ref.read(syncErrorProvider.notifier).report(e.toString());
    });
  }

  /// Keep the settle screen in sync when the host ticks things off on another device.
  void watchSettlements() {
    _settleSub?.cancel();
    _settleSub = _repo.watchSettlements(state).listen((remote) {
      final merged = {...state.settlements};
      var changed = false;
      for (final e in remote.entries) {
        final local = merged[e.key];
        if (local == null || local.method != e.value.method || local.owed != e.value.owed) {
          if (e.value.method != null) {
            merged[e.key] = e.value;
            changed = true;
          }
        }
      }
      if (changed) state = state.copyWith(settlements: merged);
    }, onError: (Object _) {});
  }

  void stopWatchingSettlements() {
    _settleSub?.cancel();
    _settleSub = null;
  }

  /// Marks the bill settled. Open tabs stay open.
  Future<bool> finishBill() async {
    if (!state.allFriendsSettled) return false;
    try {
      await _repo.markSettled(state.id);
    } catch (e) {
      ref.read(syncErrorProvider.notifier).report(e.toString());
      return false;
    }
    _set(state.copyWith(status: DraftStatus.settled));
    return true;
  }
}
