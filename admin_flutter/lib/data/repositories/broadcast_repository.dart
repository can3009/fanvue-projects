import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client_provider.dart';

/// Model for audience/smart list from Fanvue
class AudienceList {
  const AudienceList({
    required this.id,
    required this.name,
    required this.fanCount,
    required this.type,
    this.description,
  });

  final String id;
  final String name;
  final int fanCount;
  final String type; // 'smart' or 'custom'
  final String? description;

  factory AudienceList.fromJson(Map<String, dynamic> json, String listType) {
    return AudienceList(
      id: json['id'] as String? ?? json['uuid'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      fanCount: json['fanCount'] as int? ?? json['memberCount'] as int? ?? 0,
      type: json['type'] as String? ?? listType,
    );
  }
}

/// Model for broadcast template suggestion
class BroadcastSuggestion {
  const BroadcastSuggestion({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
  });

  final String id;
  final String title;
  final String content;
  final String category; // tease, ppv, re-engage, promo
}

class BroadcastRepository {
  BroadcastRepository(this._client);

  final SupabaseClient _client;

  /// Get available audience lists for a creator from Fanvue API
  /// Returns both Smart Lists and Custom Lists
  Future<List<AudienceList>> getAudienceLists(String creatorId) async {
    final response = await _client.functions.invoke(
      'get-fanvue-lists',
      body: {'creator_id': creatorId},
    );

    if (response.status != 200) {
      throw Exception('Failed to load lists: ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final List<AudienceList> results = [];

    // Parse Smart Lists
    final smartLists = data['smart'] as List<dynamic>? ?? [];
    for (final list in smartLists) {
      results.add(AudienceList.fromJson(list as Map<String, dynamic>, 'smart'));
    }

    // Parse Custom Lists
    final customLists = data['custom'] as List<dynamic>? ?? [];
    for (final list in customLists) {
      results.add(
        AudienceList.fromJson(list as Map<String, dynamic>, 'custom'),
      );
    }

    return results;
  }

  /// Generate message using LLM via Edge Function
  Future<String> generateBroadcastMessage({
    required String creatorId,
    required String style,
    required String topic,
    String language = 'German',
    String length = 'Medium',
    String? excludedWords,
    bool useEmojis = true,
  }) async {
    final response = await _client.functions.invoke(
      'generate-broadcast',
      body: {
        'creator_id': creatorId,
        'style': style,
        'topic': topic,
        'language': language,
        'length': length,
        'excluded_words': excludedWords,
        'use_emojis': useEmojis,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to generate message: ${response.data}');
    }

    return response.data['message'] as String;
  }

  /// Send broadcast to fans via Edge Function
  /// Now uses Fanvue list UUIDs directly
  Future<Map<String, dynamic>> sendBroadcast({
    required String creatorId,
    required List<String> targetAudienceIds,
    required List<String> excludeAudienceIds,
    required String message,
    required List<String> targetAudienceTypes,
    required List<String> excludeAudienceTypes,
  }) async {
    final response = await _client.functions.invoke(
      'send-broadcast',
      body: {
        'creator_id': creatorId,
        'target_audiences': targetAudienceIds,
        'target_audience_types': targetAudienceTypes,
        'exclude_audiences': excludeAudienceIds,
        'exclude_audience_types': excludeAudienceTypes,
        'message': message,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to send broadcast: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Get predefined broadcast templates
  List<BroadcastSuggestion> getBroadcastSuggestions() {
    return const [
      BroadcastSuggestion(
        id: '1',
        title: 'Tease Post',
        content:
            'Hey babe! 💖 Hab gerade was ganz besonderes gepostet... schau mal vorbei! 😉',
        category: 'tease',
      ),
      BroadcastSuggestion(
        id: '2',
        title: 'PPV Ankündigung',
        content:
            'Miss me? 😏 Hab was Exklusives nur für dich... check deine DMs 🔥',
        category: 'ppv',
      ),
      BroadcastSuggestion(
        id: '3',
        title: 'Re-Engage',
        content:
            'Hey Süßer! 💕 Hab dich schon vermisst... komm mal wieder vorbei 🥺',
        category: 're-engage',
      ),
      BroadcastSuggestion(
        id: '4',
        title: 'Weekend Vibes',
        content:
            'Happy Weekend babe! 🎉 Zeit für ein bisschen Spaß... was hast du vor? 😘',
        category: 'promo',
      ),
      BroadcastSuggestion(
        id: '5',
        title: 'Guten Morgen',
        content:
            'Guten Morgen Schatz! ☀️ Dachte grad an dich... wie startest du in den Tag?',
        category: 'tease',
      ),
      BroadcastSuggestion(
        id: '6',
        title: 'Neuer Content',
        content:
            'Psst... 🤫 Hab grad neuen Content hochgeladen den du LIEBEN wirst 💋',
        category: 'tease',
      ),
    ];
  }
}

final broadcastRepositoryProvider = Provider<BroadcastRepository>((ref) {
  return BroadcastRepository(ref.watch(supabaseClientProvider));
});
