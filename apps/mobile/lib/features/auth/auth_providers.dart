import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import 'auth_repository.dart';
import 'profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.isConfigured) return SupabaseAuthRepository(Supabase.instance.client);
  return LocalAuthRepository();
});

/// The signed-in user id, or null. Loading until the first value arrives.
final sessionProvider = StreamProvider<String?>((ref) => ref.watch(authRepositoryProvider).userIdChanges);

/// The signed-in user's profile row, null while they have not finished the profile screen.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final userId = ref.watch(sessionProvider).value;
    if (userId == null) return null;
    return ref.read(authRepositoryProvider).loadProfile();
  }

  Future<void> save({required String name, required String avatarColor, String? bkash}) async {
    final id = ref.read(authRepositoryProvider).userId;
    if (id == null) return;
    final saved = await ref.read(authRepositoryProvider).saveProfile(
          Profile(id: id, name: name, avatarColor: avatarColor, bkashNumber: bkash),
        );
    state = AsyncData(saved);
  }
}
