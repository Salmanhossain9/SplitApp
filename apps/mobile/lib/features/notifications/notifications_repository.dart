import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_core/split_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../auth/auth_providers.dart';

/// A row from `notifications`: someone reminded you, a bill was shared, a tab was paid.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  factory AppNotification.fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        kind: r['kind'] as String,
        payload: (r['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        readAt: r['read_at'] == null ? null : DateTime.parse(r['read_at'] as String).toLocal(),
      );

  /// (title, body) in the app's voice.
  (String, String) get text {
    final place = payload['place'] as String? ?? 'a bill';
    final host = payload['host_name'] as String? ?? 'your friend';
    final owed = (payload['owed_amount'] as num?)?.toInt();
    return switch (kind) {
      'remind' => ('a friendly nudge', 'You still owe $host${owed == null ? '' : ' ${formatTaka(owed)}'} for $place.'),
      'bill_shared' => ('$host split $place', 'Open it to see your share.'),
      'tab_paid' => ('tab paid', '${payload['name'] ?? 'Someone'} paid their tab for $place.'),
      _ => ('splitbit', place),
    };
  }
}

String timeAgo(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${then.day}/${then.month}';
}

abstract class NotificationsRepository {
  Stream<List<AppNotification>> watch();
  Future<void> markAllRead();
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client, this._userId);
  final SupabaseClient _client;
  final String? Function() _userId;

  @override
  Stream<List<AppNotification>> watch() {
    final id = _userId();
    if (id == null) return const Stream.empty();
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => [for (final r in rows) AppNotification.fromRow(r)]);
  }

  @override
  Future<void> markAllRead() async {
    final id = _userId();
    if (id == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', id)
        .isFilter('read_at', null);
  }
}

class EmptyNotificationsRepository implements NotificationsRepository {
  @override
  Stream<List<AppNotification>> watch() => Stream.value(const []);

  @override
  Future<void> markAllRead() async {}
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  if (!Env.isConfigured) return EmptyNotificationsRepository();
  return SupabaseNotificationsRepository(Supabase.instance.client, () => ref.read(authRepositoryProvider).userId);
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  if (ref.watch(sessionProvider).value == null) return Stream.value(const []);
  return ref.watch(notificationsRepositoryProvider).watch();
});

/// Drives the coral dot on the bell.
final hasUnreadProvider = Provider<bool>((ref) {
  return ref.watch(notificationsProvider).value?.any((n) => n.unread) ?? false;
});
