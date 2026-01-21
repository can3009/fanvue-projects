class Fan {
  Fan({
    required this.id,
    required this.fanvueId,
    required this.username,
    required this.displayName,
    this.lastMessageAt,
  });

  final String id;
  final String fanvueId;
  final String username;
  final String displayName;
  final DateTime? lastMessageAt;

  factory Fan.fromMap(Map<String, dynamic> map) {
    return Fan(
      id: map['id']?.toString() ?? '',
      fanvueId:
          map['fanvue_fan_id']?.toString() ??
          map['fanvue_id']?.toString() ??
          '',
      username: map['username']?.toString() ?? '',
      displayName:
          map['display_name']?.toString() ??
          map['displayName']?.toString() ??
          '',
      lastMessageAt: DateTime.tryParse(
        map['last_message_at']?.toString() ?? '',
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Fan && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
