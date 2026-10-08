import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:split_core/split_core.dart' show formatTaka;

import '../../core/env.dart';
import '../../core/phone.dart';
import '../../ui/settle_row.dart' show SettleMethod;
import 'bill_rows.dart';
import 'bill_summary.dart';
import 'draft_bill.dart';

class FinalizeResult {
  const FinalizeResult({required this.shareUrl, required this.total});
  final String shareUrl;
  final int total;
}

class BillSyncException implements Exception {
  const BillSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HostInfo {
  const HostInfo({required this.userId, required this.name});
  final String userId;
  final String name;
}

/// What happened when the host tapped `remind`.
sealed class RemindOutcome {
  const RemindOutcome();
}

/// A push or in-app notification went out.
class RemindSent extends RemindOutcome {
  const RemindSent();
}

/// A guest has no push: open this WhatsApp link with the message ready.
class RemindWhatsapp extends RemindOutcome {
  const RemindWhatsapp(this.link);
  final String link;
}

class RemindTooSoon extends RemindOutcome {
  const RemindTooSoon(this.hours);
  final int hours;
}

class RemindFailed extends RemindOutcome {
  const RemindFailed(this.message);
  final String message;
}

/// Where bills live. Screens never talk to Supabase; they go through the notifier, which goes
/// through this.
abstract class BillRepository {
  /// False in local demo mode: nothing is synced.
  bool get enabled;

  /// Create or update the draft bill, its people, items, claims and charges.
  Future<void> saveDraft(DraftBill draft);

  /// Save, then ask the `finalize-bill` function to recompute the shares on the server,
  /// store them, open the bill and mint the share link. [saved] says the server already has
  /// this exact draft (the background sync did it), so only the function call is left.
  Future<FinalizeResult> finalize(DraftBill draft, {bool saved = false});

  /// Write one friend's settle row (method, paid, tab).
  Future<void> saveSettlement(DraftBill draft, String personId);

  Future<void> markSettled(String billId);

  /// Settle rows changing on another device, keyed by person id (milestone 4 realtime).
  Stream<Map<String, SettleEntry>> watchSettlements(DraftBill draft);

  /// The host's sent bills (open and settled), newest first.
  Future<List<BillSummary>> listBills();

  /// Nudge a friend about their open tab: push or notification for app users, a WhatsApp
  /// link for guests. One reminder per tab per 24 hours.
  Future<RemindOutcome> remind(OpenTab tab);
}

SettleMethod? methodFromDb(String? v) => switch (v) {
      'cash' => SettleMethod.cash,
      'bkash' => SettleMethod.bkash,
      'bank' => SettleMethod.bank,
      'owes_me' => SettleMethod.owesMe,
      _ => null,
    };

String? methodToDb(SettleMethod? m) => switch (m) {
      SettleMethod.cash => 'cash',
      SettleMethod.bkash => 'bkash',
      SettleMethod.bank => 'bank',
      SettleMethod.owesMe => 'owes_me',
      null => null,
    };

/// The settlements row for a friend. `paid + owed` always equals the share, which the
/// database trigger also enforces.
Map<String, dynamic> settlementRow(DraftBill d, String personId) {
  final e = d.entryOf(personId);
  final share = d.shareOf(personId);
  if (e.method == null) {
    return {'method': null, 'paid_amount': 0, 'owed_amount': 0, 'covered_amount': 0};
  }
  return {
    'method': methodToDb(e.method),
    'paid_amount': share - e.owed,
    'owed_amount': e.owed,
    'covered_amount': e.owed,
  };
}

class SupabaseBillRepository implements BillRepository {
  SupabaseBillRepository(this._client, this._host);

  final SupabaseClient _client;
  final HostInfo? Function() _host;

  @override
  bool get enabled => true;

  HostInfo _requireHost() {
    final h = _host();
    if (h == null) throw const BillSyncException('you are signed out. log in again.');
    return h;
  }

  @override
  Future<void> saveDraft(DraftBill d) async {
    final host = _requireHost();
    final rows = draftToRows(d, hostUserId: host.userId, hostName: host.name);
    try {
      // Four rounds instead of nine one after another. Within a round the requests do not depend
      // on each other; each round needs the one before it (rows point at friends, bills, items).
      await Future.wait<void>([
        if (rows.friends.isNotEmpty) _client.from('friends').upsert(rows.friends).then((_) {}),
        _client.from('bills').upsert(rows.bill).then((_) {}),
      ]);

      final itemIds = rows.items.map((r) => r['id'] as String).toList();
      await Future.wait<void>([
        _client.from('bill_participants').upsert(rows.participants).then((_) {}),
        if (rows.items.isNotEmpty) _client.from('items').upsert(rows.items).then((_) {}),
        _client.from('charges').upsert(rows.charges).then((_) {}),
      ]);

      await Future.wait<void>([
        _deleteMissing('bill_participants', 'bill_id', d.id, rows.participants.map((r) => r['id'] as String)),
        _deleteMissing('items', 'bill_id', d.id, itemIds),
        if (itemIds.isNotEmpty) _client.from('claims').delete().inFilter('item_id', itemIds).then((_) {}),
      ]);

      if (rows.claims.isNotEmpty) await _client.from('claims').insert(rows.claims);
    } on PostgrestException catch (e) {
      throw BillSyncException(_friendly(e));
    }
  }

  Future<void> _deleteMissing(String table, String column, String billId, Iterable<String> keep) async {
    final ids = keep.toList();
    var q = _client.from(table).delete().eq(column, billId);
    if (ids.isNotEmpty) q = q.not('id', 'in', '(${ids.join(',')})');
    await q;
  }

  @override
  Future<FinalizeResult> finalize(DraftBill d, {bool saved = false}) async {
    if (!saved) await saveDraft(d);
    try {
      final res = await _client.functions.invoke('finalize-bill', body: {'bill_id': d.id});
      final data = res.data as Map<String, dynamic>;
      return FinalizeResult(shareUrl: data['share_url'] as String, total: data['total'] as int);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] is Map ? details['error']['message'] : null;
      throw BillSyncException(message is String ? message : 'could not send the bills. try again.');
    }
  }

  @override
  Future<void> saveSettlement(DraftBill d, String personId) async {
    try {
      await _client
          .from('settlements')
          .update(settlementRow(d, personId))
          .eq('bill_id', d.id)
          .eq('participant_id', participantIdFor(d.id, personId));
    } on PostgrestException catch (e) {
      throw BillSyncException(_friendly(e));
    }
  }

  @override
  Future<void> markSettled(String billId) async {
    try {
      await _client.from('bills').update({'status': 'settled'}).eq('id', billId);
    } on PostgrestException catch (e) {
      throw BillSyncException(_friendly(e));
    }
  }

  @override
  Stream<Map<String, SettleEntry>> watchSettlements(DraftBill d) {
    final byParticipant = {for (final p in d.friends) participantIdFor(d.id, p.id): p.id};
    return _client
        .from('settlements')
        .stream(primaryKey: ['bill_id', 'participant_id'])
        .eq('bill_id', d.id)
        .map((rows) => {
              for (final r in rows)
                if (byParticipant[r['participant_id']] != null)
                  byParticipant[r['participant_id']]!: SettleEntry(
                    method: methodFromDb(r['method'] as String?),
                    owed: (r['owed_amount'] as num).toInt(),
                  ),
            });
  }

  @override
  Future<List<BillSummary>> listBills() async {
    final host = _requireHost();
    try {
      final rows = await _client
          .from('bills')
          // The hint matters: shares and settlements also join bills to bill_participants, so
          // without it PostgREST refuses the query (PGRST201) and the home screen never loads.
          .select('id, place, total, status, billed_at, '
              'bill_participants!bill_participants_bill_id_fkey(id, name, is_host, user_id), '
              'shares(participant_id, total), '
              'settlements(participant_id, method, paid_amount, owed_amount, last_reminded_at)')
          .eq('created_by', host.userId)
          .neq('status', 'draft')
          .order('billed_at', ascending: false)
          .limit(200);
      return [for (final r in rows) BillSummary.fromRow(r)];
    } on PostgrestException catch (e) {
      debugPrint('listBills failed: $e');
      throw BillSyncException(_friendly(e));
    }
  }

  @override
  Future<RemindOutcome> remind(OpenTab tab) async {
    try {
      final res = await _client.functions.invoke(
        'send-reminders',
        body: {'bill_id': tab.billId, 'participant_id': tab.participantId},
      );
      final data = res.data as Map<String, dynamic>;
      final link = data['whatsapp'] as String?;
      return link != null ? RemindWhatsapp(link) : const RemindSent();
    } on FunctionException catch (e) {
      final d = e.details;
      if (e.status == 429 && d is Map) return RemindTooSoon((d['retry_in_hours'] as num?)?.toInt() ?? 24);
      return const RemindFailed('could not send the reminder. try again.');
    } catch (_) {
      return const RemindFailed('could not send the reminder. try again.');
    }
  }

  String _friendly(PostgrestException e) {
    final text = e.message.toLowerCase();
    if (text.contains('row-level security') || text.contains('permission denied')) {
      return 'you cannot change this bill.';
    }
    if (text.contains('can no longer be edited')) return 'this bill is already sent. void it to change it.';
    return 'could not save. check your connection and try again.';
  }
}

/// Offline mode (no Supabase configured): nothing leaves the device. Bills sent in this session
/// are kept in memory so the home screen shows them. Starts empty; [seed] only exists so tests
/// can start from a populated dashboard.
class LocalBillRepository implements BillRepository {
  LocalBillRepository({bool seed = false, DateTime? now}) : _now = now {
    if (seed) _seedSamples(now ?? DateTime.now());
  }

  /// Fixed "now" for tests; real time when null.
  final DateTime? _now;

  final Map<String, BillSummary> _bills = {};
  final Map<String, DateTime> _lastReminded = {};

  void _seedSamples(DateTime now) {
    BillSummary sample(String id, String place, int daysAgo, int total, int friends, int target, int collected,
        {List<OpenTab> tabs = const [], bool settled = true}) {
      return BillSummary(
        id: id,
        place: place,
        billedAt: now.subtract(Duration(days: daysAgo)),
        total: total,
        status: settled ? DraftStatus.settled : DraftStatus.open,
        friendCount: friends,
        target: target,
        collected: collected,
        tabs: tabs,
      );
    }

    _bills['demo-1'] = sample('demo-1', 'Pizza Roma', 3, 154050, 3, 103500, 103500);
    _bills['demo-2'] = sample('demo-2', 'Star Kabab', 7, 98000, 4, 73000, 40000, settled: false);
  }

  @override
  bool get enabled => false;

  @override
  Future<void> saveDraft(DraftBill draft) async {}

  @override
  Future<FinalizeResult> finalize(DraftBill draft, {bool saved = false}) async {
    final token = List.generate(22, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(36)]).join();
    _bills[draft.id] = BillSummary.fromDraft(draft.copyWith(status: DraftStatus.open), now: _now);
    return FinalizeResult(shareUrl: '${Env.shareBaseUrl}/s/$token', total: draft.total);
  }

  @override
  Future<void> saveSettlement(DraftBill draft, String personId) async {
    final existing = _bills[draft.id];
    _bills[draft.id] = BillSummary.fromDraft(draft, now: existing?.billedAt ?? _now);
  }

  @override
  Future<void> markSettled(String billId) async {
    final b = _bills[billId];
    if (b == null) return;
    _bills[billId] = BillSummary(
      id: b.id,
      place: b.place,
      billedAt: b.billedAt,
      total: b.total,
      status: DraftStatus.settled,
      friendCount: b.friendCount,
      target: b.target,
      collected: b.collected,
      tabs: b.tabs,
    );
  }

  @override
  Stream<Map<String, SettleEntry>> watchSettlements(DraftBill draft) => const Stream.empty();

  @override
  Future<List<BillSummary>> listBills() async =>
      _bills.values.toList()..sort((a, b) => b.billedAt.compareTo(a.billedAt));

  @override
  Future<RemindOutcome> remind(OpenTab tab) async {
    final key = '${tab.billId}/${tab.participantId}';
    final last = _lastReminded[key];
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 24)) {
      return RemindTooSoon(24 - DateTime.now().difference(last).inHours);
    }
    _lastReminded[key] = DateTime.now();
    final phone = tab.phone;
    if (phone != null && phone.isNotEmpty) {
      final link = whatsappChatUri(phone, 'You still owe ${formatTaka(tab.owed)} for ${tab.place}.');
      if (link != null) return RemindWhatsapp(link.toString());
    }
    return const RemindSent();
  }
}
