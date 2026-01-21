import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator.dart';
import '../supabase_client_provider.dart';

/// OAuth token status for a creator
class OAuthTokenStatus {
  const OAuthTokenStatus({
    required this.hasToken,
    this.expiresAt,
    required this.isExpired,
  });

  final bool hasToken;
  final DateTime? expiresAt;
  final bool isExpired;

  /// True if token exists and is not expired
  bool get isValid => hasToken && !isExpired;
}

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
    await _client
        .from('creators')
        .update({'is_active': isActive, 'settings_json': settings})
        .eq('id', creatorId);
  }

  /// Returns OAuth token status for a creator.
  /// Returns null if no token exists.
  Future<OAuthTokenStatus?> getOAuthStatus(String creatorId) async {
    final row = await _client
        .from('creator_oauth_tokens')
        .select('access_token, expires_at')
        .eq('creator_id', creatorId)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    final hasToken = row['access_token'] != null;
    DateTime? expiresAt;
    if (row['expires_at'] != null) {
      expiresAt = DateTime.tryParse(row['expires_at'].toString());
    }

    return OAuthTokenStatus(
      hasToken: hasToken,
      expiresAt: expiresAt,
      isExpired: expiresAt != null && expiresAt.isBefore(DateTime.now()),
    );
  }

  /// Legacy method for backwards compatibility
  Future<bool> hasOAuthToken(String creatorId) async {
    final status = await getOAuthStatus(creatorId);
    return status?.hasToken ?? false;
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
