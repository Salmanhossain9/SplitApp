/// Someone on a bill, in a group or in the friends list. App users and guests look the same to the UI.
class Person {
  const Person({required this.id, required this.name, this.avatarColor = 'lavender', this.isHost = false});

  final String id;
  final String name;
  final String avatarColor;
  final bool isHost;

  Person copyWith({String? name, String? avatarColor, bool? isHost}) => Person(
        id: id,
        name: name ?? this.name,
        avatarColor: avatarColor ?? this.avatarColor,
        isHost: isHost ?? this.isHost,
      );

  @override
  bool operator ==(Object other) => other is Person && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
