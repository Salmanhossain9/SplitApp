class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.avatarColor = 'lavender',
    this.bkashNumber,
  });

  final String id;
  final String name;
  final String avatarColor;

  /// Shown to friends on the share page so they know where to send money.
  final String? bkashNumber;

  Profile copyWith({String? name, String? avatarColor, String? bkashNumber}) => Profile(
        id: id,
        name: name ?? this.name,
        avatarColor: avatarColor ?? this.avatarColor,
        bkashNumber: bkashNumber ?? this.bkashNumber,
      );

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        name: row['name'] as String,
        avatarColor: row['avatar_color'] as String? ?? 'lavender',
        bkashNumber: row['bkash_number'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'name': name.trim(),
        'avatar_color': avatarColor,
        'bkash_number': (bkashNumber == null || bkashNumber!.trim().isEmpty) ? null : bkashNumber!.trim(),
      };
}
