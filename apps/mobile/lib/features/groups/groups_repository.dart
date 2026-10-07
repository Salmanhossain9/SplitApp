import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/person.dart';
import '../../ui/group_stack.dart';
import '../../core/ids.dart';

abstract class GroupsRepository {
  Future<List<GroupCardData>> load();

  /// Save a group of friends. Guests are saved as friend rows first.
  Future<GroupCardData> create(String name, List<Person> members);
}

class SupabaseGroupsRepository implements GroupsRepository {
  SupabaseGroupsRepository(this._client, this._ownerId);
  final SupabaseClient _client;
  final String Function() _ownerId;

  @override
  Future<List<GroupCardData>> load() async {
    final rows = await _client
        .from('groups')
        .select('id, name, group_members(friends(id, name, phone, avatar_color))')
        .order('created_at');
    return [
      for (final g in rows)
        GroupCardData(
          id: g['id'] as String,
          name: g['name'] as String,
          members: [
            for (final m in (g['group_members'] as List? ?? const []))
              if (m['friends'] != null)
                Person(
                  id: m['friends']['id'] as String,
                  name: m['friends']['name'] as String,
                  phone: m['friends']['phone'] as String?,
                  avatarColor: m['friends']['avatar_color'] as String? ?? 'lavender',
                ),
          ],
        ),
    ];
  }

  @override
  Future<GroupCardData> create(String name, List<Person> members) async {
    final owner = _ownerId();
    await _client.from('friends').upsert([
      for (final m in members)
        {'id': m.id, 'owner_id': owner, 'name': m.name, 'phone': m.phone, 'avatar_color': m.avatarColor},
    ]);
    final group = await _client.from('groups').insert({'name': name.trim(), 'owner_id': owner}).select().single();
    await _client.from('group_members').insert([
      for (final m in members) {'group_id': group['id'], 'friend_id': m.id},
    ]);
    return GroupCardData(id: group['id'] as String, name: name.trim(), members: members);
  }
}

/// Offline mode (no Supabase configured): groups live in memory. Starts empty; [initial] is for tests.
class LocalGroupsRepository implements GroupsRepository {
  LocalGroupsRepository({List<GroupCardData> initial = const []}) : _groups = [...initial];

  final List<GroupCardData> _groups;

  @override
  Future<List<GroupCardData>> load() async => List.of(_groups);

  @override
  Future<GroupCardData> create(String name, List<Person> members) async {
    final g = GroupCardData(id: newUuid(), name: name.trim(), members: members);
    _groups.add(g);
    return g;
  }
}
