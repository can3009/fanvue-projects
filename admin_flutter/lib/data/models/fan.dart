class Fan {
  Fan({
    required this.id,
    required this.fanvueId,
    required this.username,
    required this.displayName,
  });

  final String id;
  final String fanvueId;
  final String username;
  final String displayName;

  factory Fan.fromMap(Map<String, dynamic> map) {
    return Fan(
      id: map['id']?.toString() ?? '',
      fanvueId: map['fanvue_fan_id']?.toString() ??
          map['fanvue_id']?.toString() ??
          '',
      username: map['username']?.toString() ?? '',
      displayName: map['display_name']?.toString() ??
          map['displayName']?.toString() ??
          map['username']?.toString() ??
          'Unknown',
    );
  }
}
