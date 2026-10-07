import '../../ui/pills.dart' show BillStatus;
import 'bill_repository.dart' show methodFromDb;
import 'draft_bill.dart';

/// A tab someone still owes the host: a settlement with `owed > 0`.
class OpenTab {
  const OpenTab({
    required this.billId,
    required this.participantId,
    required this.personName,
    required this.owed,
    required this.place,
    this.isAppUser = false,
    this.phone,
    this.lastRemindedAt,
  });

  final String billId;
  final String participantId;
  final String personName;
  final String place;

  /// poisha
  final int owed;
  final bool isAppUser;
  final String? phone;
  final DateTime? lastRemindedAt;
}

/// One line on the home and money screens.
class BillSummary {
  const BillSummary({
    required this.id,
    required this.place,
    required this.billedAt,
    required this.total,
    required this.status,
    required this.friendCount,
    required this.target,
    required this.collected,
    required this.tabs,
  });

  final String id;
  final String place;
  final DateTime billedAt;

  /// The whole bill (poisha).
  final int total;

  /// 'open' or 'settled'. Drafts never show up in the list.
  final DraftStatus status;
  final int friendCount;

  /// What friends owe the host in total, and how much of it has come in.
  final int target;
  final int collected;
  final List<OpenTab> tabs;

  int get outstanding => (target - collected).clamp(0, target);
  int get tabTotal => tabs.fold(0, (a, t) => a + t.owed);

  /// Coral "tab" when someone still owes, lime "settled" when done, coral "pending" otherwise.
  BillStatus get pill {
    if (tabs.isNotEmpty) return BillStatus.tab;
    return status == DraftStatus.settled ? BillStatus.settled : BillStatus.pending;
  }

  /// Rows from the `bills` query (with participants and settlements nested).
  factory BillSummary.fromRow(Map<String, dynamic> row) {
    final people = [for (final p in (row['bill_participants'] as List? ?? const [])) p as Map<String, dynamic>];
    final byId = {for (final p in people) p['id'] as String: p};
    final settlements = [for (final s in (row['settlements'] as List? ?? const [])) s as Map<String, dynamic>];
    final shares = {
      for (final s in (row['shares'] as List? ?? const []))
        (s as Map<String, dynamic>)['participant_id'] as String: (s['total'] as num).toInt(),
    };
    var target = 0, collected = 0;
    final tabs = <OpenTab>[];
    for (final s in settlements) {
      final pid = s['participant_id'] as String;
      final share = shares[pid] ?? 0;
      target += share;
      final owed = (s['owed_amount'] as num?)?.toInt() ?? 0;
      if (methodFromDb(s['method'] as String?) != null) collected += (s['paid_amount'] as num?)?.toInt() ?? 0;
      if (owed > 0) {
        final p = byId[pid];
        tabs.add(OpenTab(
          billId: row['id'] as String,
          participantId: pid,
          personName: (p?['name'] as String?) ?? 'a friend',
          place: row['place'] as String,
          owed: owed,
          isAppUser: p?['user_id'] != null,
          lastRemindedAt: s['last_reminded_at'] == null ? null : DateTime.parse(s['last_reminded_at'] as String),
        ));
      }
    }
    return BillSummary(
      id: row['id'] as String,
      place: row['place'] as String,
      billedAt: DateTime.parse(row['billed_at'] as String).toLocal(),
      total: (row['total'] as num).toInt(),
      status: row['status'] == 'settled' ? DraftStatus.settled : DraftStatus.open,
      friendCount: people.where((p) => p['is_host'] != true).length,
      target: target,
      collected: collected,
      tabs: tabs,
    );
  }

  /// The same summary from the local draft (demo mode, and the screen right after settling).
  factory BillSummary.fromDraft(DraftBill d, {DateTime? now}) {
    final friends = d.friends;
    final tabs = [
      for (final f in friends)
        if (d.entryOf(f.id).owed > 0)
          OpenTab(
            billId: d.id,
            participantId: f.id,
            personName: f.name,
            place: d.place,
            owed: d.entryOf(f.id).owed,
            phone: f.phone,
          ),
    ];
    final s = d.settleSummary;
    return BillSummary(
      id: d.id,
      place: d.place,
      billedAt: now ?? DateTime.now(),
      total: d.total,
      status: d.status == DraftStatus.settled ? DraftStatus.settled : DraftStatus.open,
      friendCount: friends.length,
      target: s.target,
      collected: s.collected,
      tabs: tabs,
    );
  }
}

/// Numbers for the home dashboard, computed from the bill list.
class Dashboard {
  const Dashboard({
    required this.monthTotal,
    required this.monthBills,
    required this.monthSettled,
    required this.monthPending,
    required this.owedToMe,
    required this.tabs,
  });

  /// Everything split in the current month, and across how many bills.
  final int monthTotal;
  final int monthBills;

  /// Of that, how much is settled (host share + collected) and how much is still to come in.
  final int monthSettled;
  final int monthPending;

  /// Outstanding across all bills, any month.
  final int owedToMe;
  final List<OpenTab> tabs;

  factory Dashboard.from(List<BillSummary> bills, DateTime now) {
    final month = bills.where((b) => b.billedAt.year == now.year && b.billedAt.month == now.month).toList();
    final total = month.fold(0, (a, b) => a + b.total);
    final pending = month.fold(0, (a, b) => a + b.outstanding);
    return Dashboard(
      monthTotal: total,
      monthBills: month.length,
      monthSettled: total - pending,
      monthPending: pending,
      owedToMe: bills.fold(0, (a, b) => a + b.outstanding),
      tabs: [for (final b in bills) ...b.tabs],
    );
  }
}

/// "good morning." / afternoon / evening / night.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'good morning.';
  if (h >= 12 && h < 17) return 'good afternoon.';
  if (h >= 17 && h < 21) return 'good evening.';
  return 'good night.';
}

String formatBillDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Where "continue" should take a half-finished bill.
String resumeLocation(DraftBill d) {
  if (d.status == DraftStatus.open) return '/bill/${d.id}/settle';
  if (d.place.trim().isEmpty || d.participants.length < 2) return '/bill/new';
  if (d.items.isEmpty || !d.itemsConfirmed) return '/bill/${d.id}/items';
  if (!d.claimStepValid) return '/bill/${d.id}/claim';
  return '/bill/${d.id}/charges';
}

/// A bill is worth resuming once it has a place and at least one item.
bool isResumable(DraftBill d) =>
    d.status != DraftStatus.settled && d.place.trim().isNotEmpty && d.items.isNotEmpty;
