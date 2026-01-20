import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator.dart';
import '../supabase_client_provider.dart';

class CreatorRepository {
  CreatorRepository(this._client);

  final SupabaseClient _client;

  Future<List<Creator>> listCreators() async {
    final data = await _client
        .from('creators')
        .select('*')
        .order('created_at', ascending: false);
    return (data as List).map((row) => Creator.fromMap(row)).toList();
  }

  Future<void> addCreator({
    required String displayName,
    required String fanvueCreatorId,
    required bool isActive,
  }) async {
    final resolvedFanvueId = fanvueCreatorId.isEmpty
        ? 'manual-${DateTime.now().millisecondsSinceEpoch}'
        : fanvueCreatorId;
    await _client.from('creators').insert({
      'display_name': displayName,
      'fanvue_creator_id': resolvedFanvueId,
      'is_active': isActive,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateCreatorSettings({
    required String creatorId,
    required Map<String, dynamic> settings,
    required bool isActive,
  }) async {
    final payload = {
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await _client
          .from('creators')
          .update({
            ...payload,
            'settings': settings,
          })
          .eq('id', creatorId);
    } catch (_) {
      await _client
          .from('creators')
          .update({
            ...payload,
            'settings_json': settings,
          })
          .eq('id', creatorId);
    }
  }

  Future<bool> hasOAuthToken(String creatorId) async {
    final row = await _client
        .from('creator_oauth_tokens')
        .select('*')
        .eq('creator_id', creatorId)
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  Uri buildOAuthUrl(String creatorId, String supabaseUrl) {
    final projectRef = supabaseUrl.split('//').last.split('.').first;
    return Uri.parse(
      'https://$projectRef.functions.supabase.co/oauth-connect?creatorId=$creatorId',
    );
  }
}

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return CreatorRepository(ref.watch(supabaseClientProvider));
});
