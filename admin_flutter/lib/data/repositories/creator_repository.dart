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

  /// Adds a new creator with Fanvue integration credentials.
  Future<void> addCreator({
    required String displayName,
    required String fanvueCreatorId,
    required bool isActive,
    String? fanvueClientId,
    String? fanvueClientSecret,
    String? fanvueWebhookSecret,
  }) async {
    final resolvedFanvueId = fanvueCreatorId.isEmpty
        ? 'manual-${DateTime.now().millisecondsSinceEpoch}'
        : fanvueCreatorId;

    // Insert the creator
    final response = await _client
        .from('creators')
        .insert({
          'display_name': displayName,
          'fanvue_creator_id': resolvedFanvueId,
          'is_active': isActive,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    final creatorId = response['id'] as String;

    // If credentials provided, create the integration entry
    if (fanvueClientId != null &&
        fanvueClientId.isNotEmpty &&
        fanvueClientSecret != null &&
        fanvueClientSecret.isNotEmpty) {
      await _client.from('creator_integrations').insert({
        'creator_id': creatorId,
        'integration_type': 'fanvue',
        'fanvue_client_id': fanvueClientId,
        'fanvue_client_secret': fanvueClientSecret,
        'fanvue_webhook_secret': fanvueWebhookSecret,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Updates Fanvue integration credentials for a creator.
  Future<void> updateIntegration({
    required String creatorId,
    required String fanvueClientId,
    required String fanvueClientSecret,
  }) async {
    // Check if integration exists
    final existing = await _client
        .from('creator_integrations')
        .select('id')
        .eq('creator_id', creatorId)
        .eq('integration_type', 'fanvue')
        .maybeSingle();

    if (existing != null) {
      // Update existing
      await _client
          .from('creator_integrations')
          .update({
            'fanvue_client_id': fanvueClientId,
            'fanvue_client_secret': fanvueClientSecret,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id']);
    } else {
      // Insert new
      await _client.from('creator_integrations').insert({
        'creator_id': creatorId,
        'integration_type': 'fanvue',
        'fanvue_client_id': fanvueClientId,
        'fanvue_client_secret': fanvueClientSecret,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Returns true if creator has Fanvue integration credentials set up.
  Future<bool> hasIntegration(String creatorId) async {
    final row = await _client
        .from('creator_integrations')
        .select('id')
        .eq('creator_id', creatorId)
        .eq('integration_type', 'fanvue')
        .maybeSingle();
    return row != null;
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
          .update({...payload, 'settings': settings})
          .eq('id', creatorId);
    } catch (_) {
      await _client
          .from('creators')
          .update({...payload, 'settings_json': settings})
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

  Future<void> deleteCreator(String creatorId) async {
    await _client.from('creators').delete().eq('id', creatorId);
  }
}

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return CreatorRepository(ref.watch(supabaseClientProvider));
});
