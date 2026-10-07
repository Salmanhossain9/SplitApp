import 'package:splitup/models/person.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.lastOutLabel,
    required this.lastPlace,
  });

  final String id;
  final String name;
  final List<Person> members;
  final String lastOutLabel; // e.g. "Sep 21 · Chillox"
  final String lastPlace; // e.g. "Chillox"
}