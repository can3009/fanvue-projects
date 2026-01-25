import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/creator.dart';
import '../data/repositories/creator_repository.dart';
import '../config/app_config.dart';

class CreatorsState {
  const CreatorsState({
    required this.creators,
    required this.selected,
    required this.loading,
    required this.hasIntegration,
    required this.oauthConnectedServer,
    required this.hasAccessToken,
    required this.hasRefreshToken,
    required this.oauthExpired,
    this.oauthExpiresAt,
    required this.error,
  });

  final List<Creator> creators;
  final Creator? selected;
  final bool loading;

  final bool hasIntegration;

  /// creator_integrations.is_connected (server truth)
  final bool oauthConnectedServer;

  final bool hasAccessToken;
  final bool hasRefreshToken;

  final bool oauthExpired;
  final DateTime? oauthExpiresAt;

  final String? error;

  bool get needsReconnect =>
      !hasIntegration ||
      !oauthConnectedServer ||
      !hasRefreshToken ||
      oauthExpired;

  CreatorsState copyWith({
    List<Creator>? creators,
    Creator? selected,
    bool? loading,
    bool? hasIntegration,
    bool? oauthConnectedServer,
    bool? hasAccessToken,
    bool? hasRefreshToken,
    bool? oauthExpired,
    DateTime? oauthExpiresAt,
    bool clearOauthExpiresAt = false,
    String? error,
  }) {
    return CreatorsState(
      creators: creators ?? this.creators,
      selected: selected ?? this.selected,
      loading: loading ?? this.loading,
      hasIntegration: hasIntegration ?? this.hasIntegration,
      oauthConnectedServer: oauthConnectedServer ?? this.oauthConnectedServer,
      hasAccessToken: hasAccessToken ?? this.hasAccessToken,
      hasRefreshToken: hasRefreshToken ?? this.hasRefreshToken,
      oauthExpired: oauthExpired ?? this.oauthExpired,
      oauthExpiresAt: clearOauthExpiresAt
          ? null
          : (oauthExpiresAt ?? this.oauthExpiresAt),
      error: error,
    );
  }
}

class CreatorsController extends StateNotifier<CreatorsState> {
  CreatorsController(this._repository, this._supabaseUrl)
    : super(
        const CreatorsState(
          creators: [],
          selected: null,
          loading: true,
          hasIntegration: false,
          oauthConnectedServer: false,
          hasAccessToken: false,
          hasRefreshToken: false,
          oauthExpired: false,
          oauthExpiresAt: null,
          error: null,
        ),
      ) {
    load();
  }

  final CreatorRepository _repository;
  final String _supabaseUrl;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final creators = await _repository.listCreators();
      final selected =
          state.selected ?? (creators.isNotEmpty ? creators.first : null);

      if (selected == null) {
        state = state.copyWith(
          creators: creators,
          selected: null,
          loading: false,
          hasIntegration: false,
          oauthConnectedServer: false,
          hasAccessToken: false,
          hasRefreshToken: false,
          oauthExpired: false,
          clearOauthExpiresAt: true,
        );
        return;
      }

      final hasIntegration = await _repository.hasIntegration(selected.id);
      final oauthStatus = await _repository.getOAuthStatus(selected.id);

      state = state.copyWith(
        creators: creators,
        selected: selected,
        loading: false,
        hasIntegration: hasIntegration,
        oauthConnectedServer: oauthStatus?.isConnected ?? false,
        hasAccessToken: oauthStatus?.hasAccessToken ?? false,
        hasRefreshToken: oauthStatus?.hasRefreshToken ?? false,
        oauthExpired: oauthStatus?.isExpired ?? false,
        oauthExpiresAt: oauthStatus?.expiresAt,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> selectCreator(Creator? creator) async {
    if (creator == null) {
      state = state.copyWith(
        selected: null,
        hasIntegration: false,
        oauthConnectedServer: false,
        hasAccessToken: false,
        hasRefreshToken: false,
        oauthExpired: false,
        clearOauthExpiresAt: true,
      );
      return;
    }

    final hasIntegration = await _repository.hasIntegration(creator.id);
    final oauthStatus = await _repository.getOAuthStatus(creator.id);

    state = state.copyWith(
      selected: creator,
      hasIntegration: hasIntegration,
      oauthConnectedServer: oauthStatus?.isConnected ?? false,
      hasAccessToken: oauthStatus?.hasAccessToken ?? false,
      hasRefreshToken: oauthStatus?.hasRefreshToken ?? false,
      oauthExpired: oauthStatus?.isExpired ?? false,
      oauthExpiresAt: oauthStatus?.expiresAt,
    );
  }

  Future<void> addCreator({
    required String displayName,
    required String fanvueCreatorId,
    required bool isActive,
  }) async {
    await _repository.addCreator(
      displayName: displayName,
      fanvueCreatorId: fanvueCreatorId,
      isActive: isActive,
    );
    await load();
  }

  Future<void> saveSettings({
    required CreatorSettings settings,
    required bool isActive,
  }) async {
    final selected = state.selected;
    if (selected == null) return;

    await _repository.updateCreatorSettings(
      creatorId: selected.id,
      settings: settings.toMap(),
      isActive: isActive,
    );
    await load();
  }

  /// UI calls this. It MUST exist.
  /// It starts OAuth for the currently selected creator and returns the authorize URL.
  Future<Uri?> startOAuth({
    required String fanvueClientId,
    required String fanvueClientSecret,
    required String fanvueWebhookSecret,
    List<String>? scopes,
  }) async {
    final selected = state.selected;
    if (selected == null) return null;

    try {
      state = state.copyWith(loading: true, error: null);

      final url = await _repository.startFanvueOAuth(
        creatorId: selected.id,
        fanvueClientId: fanvueClientId,
        fanvueClientSecret: fanvueClientSecret,
        fanvueWebhookSecret: fanvueWebhookSecret,
        scopes: scopes,
      );

      // IMPORTANT: After initiating OAuth, refresh status after callback completes
      // (UI will typically return later; still keep state clean)
      state = state.copyWith(loading: false);
      return url;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  String get supabaseUrl => _supabaseUrl;

  Future<void> deleteCreator(Creator creator) async {
    await _repository.deleteCreator(creator.id);
    state = state.copyWith(selected: null);
    await load();
  }

  Future<void> uploadAvatar(File file) async {
    final selected = state.selected;
    if (selected == null) return;
    try {
      state = state.copyWith(loading: true, error: null);
      await _repository.uploadAvatar(selected.id, file);
      await load();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final creatorsControllerProvider =
    StateNotifierProvider<CreatorsController, CreatorsState>((ref) {
      final repo = ref.watch(creatorRepositoryProvider);
      final supabaseUrl = AppConfigStore.current?.url ?? '';
      return CreatorsController(repo, supabaseUrl);
    });
