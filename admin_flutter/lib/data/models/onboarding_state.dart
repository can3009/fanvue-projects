import 'package:flutter/foundation.dart';

/// Represents the current step in the onboarding wizard
enum OnboardingStep {
  welcome,
  creatorProfile,
  fanvueCredentials,
  oauthConnect,
  webhookSetup,
  testConnection,
  done,
}

/// State for the onboarding wizard
@immutable
class OnboardingState {
  final OnboardingStep currentStep;
  final bool isLoading;
  final String? error;
  final String? creatorId;
  final CreatorProfileData? creatorProfile;
  final FanvueCredentialsData? credentials;
  final OAuthStartResponse? oauthStartResponse;
  final WebhookSetupData? webhookSetup;
  final ConnectionHealthData? connectionHealth;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.isLoading = false,
    this.error,
    this.creatorId,
    this.creatorProfile,
    this.credentials,
    this.oauthStartResponse,
    this.webhookSetup,
    this.connectionHealth,
  });

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    bool? isLoading,
    String? error,
    String? creatorId,
    CreatorProfileData? creatorProfile,
    FanvueCredentialsData? credentials,
    OAuthStartResponse? oauthStartResponse,
    WebhookSetupData? webhookSetup,
    ConnectionHealthData? connectionHealth,
    bool clearError = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      creatorId: creatorId ?? this.creatorId,
      creatorProfile: creatorProfile ?? this.creatorProfile,
      credentials: credentials ?? this.credentials,
      oauthStartResponse: oauthStartResponse ?? this.oauthStartResponse,
      webhookSetup: webhookSetup ?? this.webhookSetup,
      connectionHealth: connectionHealth ?? this.connectionHealth,
    );
  }

  int get stepIndex => OnboardingStep.values.indexOf(currentStep);
  int get totalSteps => OnboardingStep.values.length;
  double get progress => (stepIndex + 1) / totalSteps;
  bool get canGoBack => stepIndex > 0 && currentStep != OnboardingStep.done;
}

/// Creator profile data
@immutable
class CreatorProfileData {
  final String displayName;
  final String? fanvueCreatorId;
  final bool isActive;
  final Map<String, dynamic> settings;

  const CreatorProfileData({
    required this.displayName,
    this.fanvueCreatorId,
    this.isActive = true,
    this.settings = const {},
  });

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'fanvue_creator_id': fanvueCreatorId,
    'is_active': isActive,
    'settings': settings,
  };
}

/// Fanvue OAuth credentials - sent to server, NOT stored locally
@immutable
class FanvueCredentialsData {
  final String fanvueClientId;
  final String fanvueClientSecret;
  final String fanvueWebhookSecret;
  final List<String> scopes;

  const FanvueCredentialsData({
    required this.fanvueClientId,
    required this.fanvueClientSecret,
    required this.fanvueWebhookSecret,
    this.scopes = const [
      'read:chat',
      'write:chat',
      'read:fan',
      'read:creator',
      'read:self',
      'read:media',
      'write:media',
      'read:post',
      'write:post',
      'read:insights',
      'write:creator',
    ],
  });

  /// Convert to JSON for sending to fanvue-oauth-start
  Map<String, dynamic> toJson(String creatorId) => {
    'creatorId': creatorId,
    'fanvueClientId': fanvueClientId,
    'fanvueClientSecret': fanvueClientSecret,
    'fanvueWebhookSecret': fanvueWebhookSecret,
    'scopes': scopes,
  };
}

/// Response from fanvue-oauth-start
@immutable
class OAuthStartResponse {
  final String authorizeUrl;
  final String redirectUri;
  final String state;

  const OAuthStartResponse({
    required this.authorizeUrl,
    required this.redirectUri,
    required this.state,
  });

  factory OAuthStartResponse.fromJson(Map<String, dynamic> json) {
    return OAuthStartResponse(
      authorizeUrl: json['authorizeUrl'] as String,
      redirectUri: json['redirectUri'] as String,
      state: json['state'] as String,
    );
  }
}

/// Webhook setup data for display
@immutable
class WebhookSetupData {
  final String webhookUrl;
  final bool isConfigured;

  const WebhookSetupData({required this.webhookUrl, this.isConfigured = false});
}

/// Connection health data from fanvue-connection-health
@immutable
class ConnectionHealthData {
  final String creatorId;
  final bool connected;
  final bool tokenPresent;
  final bool tokenExpired;
  final DateTime? expiresAt;
  final DateTime? lastWebhookAt;
  final String? lastWebhookError;
  final bool integrationExists;
  final List<String> scopes;

  const ConnectionHealthData({
    required this.creatorId,
    required this.connected,
    required this.tokenPresent,
    required this.tokenExpired,
    this.expiresAt,
    this.lastWebhookAt,
    this.lastWebhookError,
    this.integrationExists = false,
    this.scopes = const [],
  });

  factory ConnectionHealthData.fromJson(Map<String, dynamic> json) {
    return ConnectionHealthData(
      creatorId: json['creatorId'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      tokenPresent: json['tokenPresent'] as bool? ?? false,
      tokenExpired: json['tokenExpired'] as bool? ?? true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      lastWebhookAt: json['lastWebhookAt'] != null
          ? DateTime.tryParse(json['lastWebhookAt'] as String)
          : null,
      lastWebhookError: json['lastWebhookError'] as String?,
      integrationExists: json['integrationExists'] as bool? ?? false,
      scopes: (json['scopes'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  bool get isHealthy => connected && tokenPresent && !tokenExpired;
}

/// Webhook test result from fanvue-webhook-test
@immutable
class WebhookTestResult {
  final bool success;
  final int status;
  final bool signatureValid;
  final String webhookUrl;
  final DateTime testedAt;
  final String? error;

  const WebhookTestResult({
    required this.success,
    required this.status,
    required this.signatureValid,
    required this.webhookUrl,
    required this.testedAt,
    this.error,
  });

  factory WebhookTestResult.fromJson(Map<String, dynamic> json) {
    return WebhookTestResult(
      success: json['success'] as bool? ?? false,
      status: json['status'] as int? ?? 0,
      signatureValid: json['signatureValid'] as bool? ?? false,
      webhookUrl: json['webhookUrl'] as String? ?? '',
      testedAt:
          DateTime.tryParse(json['testedAt'] as String? ?? '') ??
          DateTime.now(),
      error: json['error'] as String?,
    );
  }
}
