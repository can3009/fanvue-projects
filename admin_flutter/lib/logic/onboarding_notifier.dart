import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/onboarding_state.dart';
import '../../data/repositories/fanvue_connection_repo.dart';
import '../../data/supabase_client_provider.dart';

/// Provider for FanvueConnectionRepo
final fanvueConnectionRepoProvider = Provider<FanvueConnectionRepo>((ref) {
  return FanvueConnectionRepo(ref.watch(supabaseClientProvider));
});

/// Provider for OnboardingNotifier
final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier(ref.watch(fanvueConnectionRepoProvider));
    });

/// Notifier for managing onboarding wizard state
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final FanvueConnectionRepo _connectionRepo;

  OnboardingNotifier(this._connectionRepo) : super(const OnboardingState());

  /// Initialize onboarding with current user's ID
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final creatorId = _connectionRepo.currentCreatorId;
      if (creatorId == null) {
        throw Exception('User not authenticated');
      }

      // Check if already connected
      ConnectionHealthData? health;
      try {
        health = await _connectionRepo.checkConnectionHealth(creatorId);
      } catch (_) {
        // Integration might not exist yet
      }

      state = state.copyWith(
        isLoading: false,
        creatorId: creatorId,
        connectionHealth: health,
        // If already connected, skip to test step
        currentStep: health?.isHealthy == true
            ? OnboardingStep.testConnection
            : OnboardingStep.welcome,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Move to next step
  void nextStep() {
    final currentIndex = state.stepIndex;
    if (currentIndex < OnboardingStep.values.length - 1) {
      state = state.copyWith(
        currentStep: OnboardingStep.values[currentIndex + 1],
        clearError: true,
      );
    }
  }

  /// Move to previous step
  void previousStep() {
    final currentIndex = state.stepIndex;
    if (currentIndex > 0) {
      state = state.copyWith(
        currentStep: OnboardingStep.values[currentIndex - 1],
        clearError: true,
      );
    }
  }

  /// Go to specific step
  void goToStep(OnboardingStep step) {
    state = state.copyWith(currentStep: step, clearError: true);
  }

  /// Save creator profile and move to next step
  Future<void> saveCreatorProfile(CreatorProfileData profile) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      state = state.copyWith(isLoading: false, creatorProfile: profile);
      nextStep();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save Fanvue credentials and start OAuth flow
  /// Credentials are sent to server, NOT stored locally
  Future<void> saveCredentialsAndStartOAuth(
    FanvueCredentialsData credentials,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final creatorId = state.creatorId;
      if (creatorId == null) {
        throw Exception('Creator ID not set');
      }

      // Save credentials locally (not persisted, only for retry)
      state = state.copyWith(credentials: credentials);

      // Start OAuth flow via Edge Function
      // This stores credentials server-side and returns authorize URL
      final oauthResponse = await _connectionRepo.startOAuth(
        creatorId,
        credentials,
      );

      // Setup webhook data for next step
      final webhookUrl = _connectionRepo.getWebhookUrl(creatorId);

      state = state.copyWith(
        isLoading: false,
        oauthStartResponse: oauthResponse,
        webhookSetup: WebhookSetupData(
          webhookUrl: webhookUrl,
          isConfigured: false,
        ),
      );
      nextStep();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Get the OAuth authorize URL
  String? get authorizeUrl => state.oauthStartResponse?.authorizeUrl;

  /// Poll for OAuth completion after user authorizes
  Future<void> pollForConnection() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final creatorId = state.creatorId;
      if (creatorId == null) {
        throw Exception('Creator ID not set');
      }

      // Poll until connected
      final health = await _connectionRepo.pollUntilConnected(creatorId);

      state = state.copyWith(isLoading: false, connectionHealth: health);
      nextStep(); // Move to webhook setup
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Manual check for connection (user clicks "I've authorized")
  Future<void> checkConnection() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final creatorId = state.creatorId;
      if (creatorId == null) {
        throw Exception('Creator ID not set');
      }

      final health = await _connectionRepo.checkConnectionHealth(creatorId);

      state = state.copyWith(isLoading: false, connectionHealth: health);

      if (health.connected && health.tokenPresent) {
        nextStep();
      } else {
        state = state.copyWith(
          error: 'Not yet connected. Please complete authorization in Fanvue.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Confirm webhook setup and proceed
  void confirmWebhookSetup() {
    if (state.webhookSetup != null) {
      state = state.copyWith(
        webhookSetup: WebhookSetupData(
          webhookUrl: state.webhookSetup!.webhookUrl,
          isConfigured: true,
        ),
      );
    }
    nextStep();
  }

  /// Check connection health
  Future<void> checkHealth() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final creatorId = state.creatorId;
      if (creatorId == null) {
        throw Exception('Creator ID not set');
      }

      final health = await _connectionRepo.checkConnectionHealth(creatorId);
      state = state.copyWith(isLoading: false, connectionHealth: health);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Test webhook
  Future<WebhookTestResult> testWebhook() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final creatorId = state.creatorId;
      if (creatorId == null) {
        throw Exception('Creator ID not set');
      }

      final result = await _connectionRepo.testWebhook(creatorId);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Complete onboarding
  void completeOnboarding() {
    state = state.copyWith(currentStep: OnboardingStep.done);
  }

  /// Reset onboarding state
  void reset() {
    state = const OnboardingState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get webhook URL for current creator
  String get webhookUrl {
    final creatorId = state.creatorId;
    if (creatorId == null) return '';
    return state.webhookSetup?.webhookUrl ??
        _connectionRepo.getWebhookUrl(creatorId);
  }

  /// Get callback URL for display
  String get callbackUrl => _connectionRepo.getCallbackUrl();
}
