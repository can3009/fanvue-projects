import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_state.dart';

/// Repository for Fanvue connection operations
/// All sensitive operations go through Edge Functions
/// NEVER reads secrets back from DB (they are not accessible via RLS)
class FanvueConnectionRepo {
  final SupabaseClient _client;

  FanvueConnectionRepo(this._client);

  /// Get the current user's creator ID (auth.uid)
  String? get currentCreatorId => _client.auth.currentUser?.id;

  /// Get the base Supabase URL
  String get _supabaseUrl {
    final restUrl = _client.rest.url.toString();
    final uri = Uri.parse(restUrl);
    return '${uri.scheme}://${uri.host}';
  }

  /// Start OAuth flow - sends credentials to server, returns authorize URL
  /// Credentials are stored server-side, NOT locally
  Future<OAuthStartResponse> startOAuth(
    String creatorId,
    FanvueCredentialsData credentials,
  ) async {
    final response = await _client.functions.invoke(
      'fanvue-oauth-start',
      body: credentials.toJson(creatorId),
    );

    if (response.status != 200) {
      final error = response.data is Map
          ? response.data['error']
          : 'OAuth start failed';
      throw Exception(error);
    }

    return OAuthStartResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Check connection health for a creator
  Future<ConnectionHealthData> checkConnectionHealth(String creatorId) async {
    final response = await _client.functions.invoke(
      'fanvue-connection-health',
      method: HttpMethod.get,
      queryParameters: {'creatorId': creatorId},
    );

    if (response.status != 200) {
      throw Exception('Failed to check connection health');
    }

    return ConnectionHealthData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Poll health until connected (with timeout)
  Future<ConnectionHealthData> pollUntilConnected(
    String creatorId, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final health = await checkConnectionHealth(creatorId);
        if (health.connected && health.tokenPresent) {
          return health;
        }
      } catch (e) {
        // Ignore errors during polling, keep trying
      }

      await Future.delayed(pollInterval);
    }

    throw Exception('Timeout waiting for OAuth connection');
  }

  /// Test webhook for a creator
  Future<WebhookTestResult> testWebhook(String creatorId) async {
    final response = await _client.functions.invoke(
      'fanvue-webhook-test',
      body: {'creatorId': creatorId},
    );

    return WebhookTestResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get the webhook URL for a creator
  String getWebhookUrl(String creatorId) {
    return '$_supabaseUrl/functions/v1/fanvue-webhook?creatorId=$creatorId';
  }

  /// Get the OAuth callback URL (for reference/display)
  String getCallbackUrl() {
    return '$_supabaseUrl/functions/v1/oauth-callback';
  }
}
