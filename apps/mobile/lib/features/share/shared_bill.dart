import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';

/// What the `share-view` function returns for a share link: no emails, no phone numbers.
class SharedBill {
  const SharedBill({
    required this.place,
    required this.hostName,
    required this.status,
    required this.total,
    required this.billedAt,
    required this.people,
    this.hostBkash,
  });

  final String place;
  final String hostName;
  final String? hostBkash;
  final String status;
  final int total;
  final DateTime billedAt;
  final List<SharedPerson> people;

  factory SharedBill.fromJson(Map<String, dynamic> j) => SharedBill(
        place: j['place'] as String,
        hostName: j['host_name'] as String,
        hostBkash: j['host_bkash'] as String?,
        status: j['status'] as String,
        total: (j['total'] as num).toInt(),
        billedAt: DateTime.parse(j['billed_at'] as String),
        people: [
          for (final p in (j['people'] as List))
            SharedPerson(
              name: p['name'] as String,
              isHost: p['is_host'] as bool,
              itemsAmount: (p['items_amount'] as num).toInt(),
              extrasAmount: (p['extras_amount'] as num).toInt(),
              total: (p['total'] as num).toInt(),
              items: [
                for (final i in (p['items'] as List))
                  (i['qty'] as num).toInt() > 1 ? '${i['name']} x${i['qty']}' : '${i['name']}',
              ],
            ),
        ],
      );
}

class SharedPerson {
  const SharedPerson({
    required this.name,
    required this.isHost,
    required this.itemsAmount,
    required this.extrasAmount,
    required this.total,
    required this.items,
  });
  final String name;
  final bool isHost;
  final int itemsAmount;
  final int extrasAmount;
  final int total;
  final List<String> items;
}

abstract class SharedBillRepository {
  /// Null when the link does not exist.
  Future<SharedBill?> load(String token);
}

class SupabaseSharedBillRepository implements SharedBillRepository {
  SupabaseSharedBillRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<SharedBill?> load(String token) async {
    try {
      final res = await _client.functions.invoke('share-view', body: {'token': token});
      return SharedBill.fromJson(res.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }
}

class NoSharedBills implements SharedBillRepository {
  @override
  Future<SharedBill?> load(String token) async => null;
}

final sharedBillRepositoryProvider = Provider<SharedBillRepository>((ref) {
  if (!Env.isConfigured) return NoSharedBills();
  return SupabaseSharedBillRepository(Supabase.instance.client);
});

final sharedBillProvider = FutureProvider.autoDispose.family<SharedBill?, String>(
  (ref, token) => ref.read(sharedBillRepositoryProvider).load(token),
);
