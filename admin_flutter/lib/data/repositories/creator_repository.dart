import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator.dart';
import '../supabase_client_provider.dart';

class OAuthTokenStatus {
  const OAuthTokenStatus({
    required this.hasAccessToken,
    required this.hasRefreshToken,
    required this.isExpired,
    this.expiresAt,
    required this.isConnected,
  });

  final bool hasAccessToken;
  final bool hasRefreshToken;
  final bool isExpired;
  final DateTime? expiresAt;

  /// server truth: creator_integrations.is_connected
  final bool isConnected;

  bool get isValid =>
      isConnected && hasAccessToken && hasRefreshToken && !isExpired;
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
    await _client
        .from('creators')
        .update({
          'is_active': isActive,
          'settings_json': settings,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', creatorId);
  }

  /// Start OAuth via Edge Function (stores secrets server-side)
  Future<Uri> startFanvueOAuth({
    required String creatorId,
    required String fanvueClientId,
    required String fanvueClientSecret,
    required String fanvueWebhookSecret,
    List<String>? scopes,
  }) async {
    final res = await _client.functions.invoke(
      'fanvue-oauth-start',
      body: {
        'creatorId': creatorId,
        'fanvueClientId': fanvueClientId,
        'fanvueClientSecret': fanvueClientSecret,
        'fanvueWebhookSecret': fanvueWebhookSecret,
        if (scopes != null && scopes.isNotEmpty) 'scopes': scopes,
      },
    );

    final data = res.data as Map?;
    final authorizeUrl = data?['authorizeUrl']?.toString();
    if (authorizeUrl == null || authorizeUrl.isEmpty) {
      throw Exception(
        'fanvue-oauth-start returned no authorizeUrl. Response: ${res.data}',
      );
    }
    return Uri.parse(authorizeUrl);
  }

  Future<bool> hasIntegration(String creatorId) async {
    final row = await _client
        .from('creator_integrations')
        .select('id')
        .eq('creator_id', creatorId)
        .eq('integration_type', 'fanvue')
        .maybeSingle();
    return row != null;
  }

  Future<OAuthTokenStatus?> getOAuthStatus(String creatorId) async {
    final integration = await _client
        .from('creator_integrations')
        .select('is_connected')
        .eq('creator_id', creatorId)
        .eq('integration_type', 'fanvue')
        .maybeSingle();

    final isConnected = (integration?['is_connected'] == true);

    final row = await _client
        .from('creator_oauth_tokens')
        .select('access_token, refresh_token, expires_at')
        .eq('creator_id', creatorId)
        .limit(1)
        .maybeSingle();

    if (row == null && integration == null) return null;

    final hasAccess = row?['access_token'] != null;
    final hasRefresh = row?['refresh_token'] != null;

    DateTime? expiresAt;
    if (row?['expires_at'] != null) {
      expiresAt = DateTime.tryParse(row!['expires_at'].toString());
    }

    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return OAuthTokenStatus(
      hasAccessToken: hasAccess,
      hasRefreshToken: hasRefresh,
      isExpired: isExpired,
      expiresAt: expiresAt,
      isConnected: isConnected,
    );
  }

  Future<void> deleteCreator(String creatorId) async {
    await _client.from('creators').delete().eq('id', creatorId);
  }

  Future<void> uploadAvatar(String creatorId, File file) async {
    final bytes = await file.readAsBytes();
    final fileExt = file.path.split('.').last;
    final fileName =
        '$creatorId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _client.storage
        .from('creator-avatars')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage
        .from('creator-avatars')
        .getPublicUrl(fileName);

    await _client
        .from('creators')
        .update({
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', creatorId);
  }
}

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return CreatorRepository(ref.watch(supabaseClientProvider));
});
