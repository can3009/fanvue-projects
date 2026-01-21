/// Strongly-typed settings for an AI persona.
class CreatorSettings {
  CreatorSettings({
    this.name,
    this.age,
    this.location,
    this.occupation,
    this.personalityTraits = const [],
    this.speakingStyle,
    this.hobbies = const [],
    this.backstory,
    this.doRules = const [],
    this.dontRules = const [],
    this.flirtiness = 5,
    this.lewdness = 5,
    this.emojiUsage = 5,
    this.arrogance = 0,
    this.dominance = 0,
    this.replyLength = 'medium',
    this.aiDeflectionResponses = const [],
  });

  final String? name;
  final int? age;
  final String? location;
  final String? occupation;
  final List<String> personalityTraits;
  final String? speakingStyle;
  final List<String> hobbies;
  final String? backstory;
  final List<String> doRules;
  final List<String> dontRules;
  final int flirtiness;
  final int lewdness;
  final int emojiUsage;
  final int arrogance;
  final int dominance;
  final String replyLength;
  final List<String> aiDeflectionResponses;

  factory CreatorSettings.fromMap(Map<String, dynamic> map) {
    return CreatorSettings(
      name: map['name'] as String?,
      age: map['age'] as int?,
      location: map['location'] as String?,
      occupation: map['occupation'] as String?,
      personalityTraits: _toStringList(map['personality_traits']),
      speakingStyle: map['speaking_style'] as String?,
      hobbies: _toStringList(map['hobbies']),
      backstory: map['backstory'] as String?,
      doRules: _toStringList(map['do_rules']),
      dontRules: _toStringList(map['dont_rules']),
      flirtiness: (map['flirtiness'] as int?) ?? 5,
      lewdness: (map['lewdness'] as int?) ?? 5,
      emojiUsage: (map['emoji_usage'] as int?) ?? 5,
      arrogance: (map['arrogance'] as int?) ?? 0,
      dominance: (map['dominance'] as int?) ?? 0,
      replyLength: (map['reply_length'] as String?) ?? 'medium',
      aiDeflectionResponses: _toStringList(map['ai_deflection_responses']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'location': location,
      'occupation': occupation,
      'personality_traits': personalityTraits,
      'speaking_style': speakingStyle,
      'hobbies': hobbies,
      'backstory': backstory,
      'do_rules': doRules,
      'dont_rules': dontRules,
      'flirtiness': flirtiness,
      'lewdness': lewdness,
      'emoji_usage': emojiUsage,
      'arrogance': arrogance,
      'dominance': dominance,
      'reply_length': replyLength,
      'ai_deflection_responses': aiDeflectionResponses,
    };
  }

  CreatorSettings copyWith({
    String? name,
    int? age,
    String? location,
    String? occupation,
    List<String>? personalityTraits,
    String? speakingStyle,
    List<String>? hobbies,
    String? backstory,
    List<String>? doRules,
    List<String>? dontRules,
    int? flirtiness,
    int? lewdness,
    int? emojiUsage,
    int? arrogance,
    int? dominance,
    String? replyLength,
    List<String>? aiDeflectionResponses,
  }) {
    return CreatorSettings(
      name: name ?? this.name,
      age: age ?? this.age,
      location: location ?? this.location,
      occupation: occupation ?? this.occupation,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      hobbies: hobbies ?? this.hobbies,
      backstory: backstory ?? this.backstory,
      doRules: doRules ?? this.doRules,
      dontRules: dontRules ?? this.dontRules,
      flirtiness: flirtiness ?? this.flirtiness,
      lewdness: lewdness ?? this.lewdness,
      emojiUsage: emojiUsage ?? this.emojiUsage,
      arrogance: arrogance ?? this.arrogance,
      dominance: dominance ?? this.dominance,
      replyLength: replyLength ?? this.replyLength,
      aiDeflectionResponses:
          aiDeflectionResponses ?? this.aiDeflectionResponses,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreatorSettings &&
          other.name == name &&
          other.age == age &&
          other.location == location &&
          other.occupation == occupation &&
          other.backstory == backstory &&
          other.speakingStyle == speakingStyle &&
          other.flirtiness == flirtiness &&
          other.lewdness == lewdness &&
          other.emojiUsage == emojiUsage &&
          other.arrogance == arrogance &&
          other.dominance == dominance &&
          other.replyLength == replyLength);

  @override
  int get hashCode =>
      Object.hash(name, age, location, occupation, flirtiness, lewdness);
}

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
  final CreatorSettings settings;
  final String fanvueCreatorId;

  factory Creator.fromMap(Map<String, dynamic> map) {
    final displayName =
        map['display_name']?.toString() ??
        map['email']?.toString() ??
        'Unknown';
    final rawSettings = Map<String, dynamic>.from(
      map['settings'] ?? map['settings_json'] ?? {},
    );
    return Creator(
      id: map['id']?.toString() ?? '',
      displayName: displayName,
      isActive: map['is_active'] ?? map['active'] ?? true,
      settings: CreatorSettings.fromMap(rawSettings),
      fanvueCreatorId: map['fanvue_creator_id']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Creator && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
