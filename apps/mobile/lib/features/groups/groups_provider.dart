import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/person.dart';
import '../../ui/group_stack.dart';
import '../auth/auth_providers.dart';
import 'groups_repository.dart';

export '../../ui/group_stack.dart' show GroupCardData;

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  if (Env.isConfigured) {
    return SupabaseGroupsRepository(
      Supabase.instance.client,
      () => ref.read(authRepositoryProvider).userId!,
    );
  }
  return LocalGroupsRepository();
});

/// Saved groups for the logged in user.
final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<GroupCardData>>(GroupsNotifier.new);

class GroupsNotifier extends AsyncNotifier<List<GroupCardData>> {
  @override
  Future<List<GroupCardData>> build() async {
    if (ref.watch(sessionProvider).value == null) return const [];
    return ref.read(groupsRepositoryProvider).load();
  }

  Future<GroupCardData> create(String name, List<Person> members) async {
    final group = await ref.read(groupsRepositoryProvider).create(name, members);
    state = AsyncData([...?state.value, group]);
    return group;
  }
}
