class Creator {
  Creator({
    required this.id,
    required this.displayName,
    required this.isActive,
    required this.settings,
    required this.fanvueCreatorId,
  });

  final String id;
  final String displayName;
  final bool isActive;
  final Map<String, dynamic> settings;
  final String fanvueCreatorId;

  factory Creator.fromMap(Map<String, dynamic> map) {
    final displayName = map['display_name']?.toString() ??
        map['email']?.toString() ??
        'Unknown';
    return Creator(
      id: map['id']?.toString() ?? '',
      displayName: displayName,
      isActive: map['is_active'] ?? map['active'] ?? true,
      settings: Map<String, dynamic>.from(
        map['settings'] ?? map['settings_json'] ?? {},
      ),
      fanvueCreatorId: map['fanvue_creator_id']?.toString() ?? '',
    );
  }
}
