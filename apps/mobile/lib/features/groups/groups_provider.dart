import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/person.dart';
import '../../ui/group_stack.dart';

export '../../ui/group_stack.dart' show GroupCardData;

const _rafi = Person(id: 'f_rafi', name: 'Rafi', avatarColor: 'coral');
const _nabil = Person(id: 'f_nabil', name: 'Nabil', avatarColor: 'sky');
const _tania = Person(id: 'f_tania', name: 'Tania', avatarColor: 'lime');
const _arif = Person(id: 'f_arif', name: 'Arif', avatarColor: 'lavender');
const _mim = Person(id: 'f_mim', name: 'Mim', avatarColor: 'coral');

/// Saved groups. Local sample data for now; milestone 4 swaps this for the Supabase repository.
final groupsProvider = NotifierProvider<GroupsNotifier, List<GroupCardData>>(GroupsNotifier.new);

class GroupsNotifier extends Notifier<List<GroupCardData>> {
  @override
  List<GroupCardData> build() => const [
        GroupCardData(id: 'g_nsu', name: 'NSU boys', members: [_rafi, _nabil, _tania]),
        GroupCardData(id: 'g_room', name: 'Roommates', members: [_arif, _nabil]),
        GroupCardData(id: 'g_office', name: 'Office lunch', members: [_mim, _arif, _rafi, _tania, _nabil]),
      ];
}
