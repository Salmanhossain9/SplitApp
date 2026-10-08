import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/clock.dart';
import '../auth/auth_providers.dart';
import 'bill_repository.dart';
import 'bill_summary.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  if (!Env.isConfigured) return LocalBillRepository();
  return SupabaseBillRepository(Supabase.instance.client, () {
    final id = ref.read(authRepositoryProvider).userId;
    if (id == null) return null;
    return HostInfo(userId: id, name: ref.read(profileProvider).value?.name ?? 'Host');
  });
});

/// The host's sent bills, newest first. Refreshed after sending, settling and finishing.
final billsProvider = AsyncNotifierProvider<BillsNotifier, List<BillSummary>>(BillsNotifier.new);

class BillsNotifier extends AsyncNotifier<List<BillSummary>> {
  @override
  Future<List<BillSummary>> build() async {
    if (ref.watch(sessionProvider).value == null) return const [];
    try {
      return await ref.read(billRepositoryProvider).listBills();
    } catch (e) {
      debugPrint('could not load bills: $e'); // The home screen only says "could not load".
      rethrow;
    }
  }
}

/// Home dashboard numbers, recomputed whenever the list changes.
final dashboardProvider = Provider<AsyncValue<Dashboard>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref.watch(billsProvider).whenData((bills) => Dashboard.from(bills, now));
});
