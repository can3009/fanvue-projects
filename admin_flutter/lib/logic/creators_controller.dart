import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/creator.dart';
import '../data/repositories/creator_repository.dart';
import '../config/app_config.dart';

class CreatorsState {
  const CreatorsState({
    required this.creators,
    required this.selected,
    required this.loading,
    required this.oauthConnected,
    required this.hasIntegration,
    required this.error,
  });

  final List<Creator> creators;
  final Creator? selected;
  final bool loading;
  final bool oauthConnected;
  final bool hasIntegration;
  final String? error;

  CreatorsState copyWith({
    List<Creator>? creators,
    Creator? selected,
    bool? loading,
    bool? oauthConnected,
    bool? hasIntegration,
    String? error,
  }) {
    return CreatorsState(
      creators: creators ?? this.creators,
      selected: selected ?? this.selected,
      loading: loading ?? this.loading,
      oauthConnected: oauthConnected ?? this.oauthConnected,
      hasIntegration: hasIntegration ?? this.hasIntegration,
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
          oauthConnected: false,
          hasIntegration: false,
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
      final oauthConnected = selected == null
          ? false
          : await _repository.hasOAuthToken(selected.id);
      final hasIntegration = selected == null
          ? false
          : await _repository.hasIntegration(selected.id);
      state = state.copyWith(
        creators: creators,
        selected: selected,
        loading: false,
        oauthConnected: oauthConnected,
        hasIntegration: hasIntegration,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> selectCreator(Creator? creator) async {
    if (creator == null) {
      state = state.copyWith(selected: null, oauthConnected: false);
      return;
    }
    final oauthConnected = await _repository.hasOAuthToken(creator.id);
    final hasIntegration = await _repository.hasIntegration(creator.id);
    state = state.copyWith(
      selected: creator,
      oauthConnected: oauthConnected,
      hasIntegration: hasIntegration,
    );
  }

  Future<void> addCreator({
    required String displayName,
    required String fanvueCreatorId,
    required bool isActive,
    String? fanvueClientId,
    String? fanvueClientSecret,
    String? fanvueWebhookSecret,
  }) async {
    await _repository.addCreator(
      displayName: displayName,
      fanvueCreatorId: fanvueCreatorId,
      isActive: isActive,
      fanvueClientId: fanvueClientId,
      fanvueClientSecret: fanvueClientSecret,
      fanvueWebhookSecret: fanvueWebhookSecret,
    );
    await load();
  }

  Future<void> updateIntegration({
    required String fanvueClientId,
    required String fanvueClientSecret,
  }) async {
    final selected = state.selected;
    if (selected == null) return;
    await _repository.updateIntegration(
      creatorId: selected.id,
      fanvueClientId: fanvueClientId,
      fanvueClientSecret: fanvueClientSecret,
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

  Uri buildOAuthUrl() {
    final selected = state.selected;
    if (selected == null) {
      return Uri();
    }
    return _repository.buildOAuthUrl(selected.id, _supabaseUrl);
  }

  Future<void> deleteCreator(Creator creator) async {
    await _repository.deleteCreator(creator.id);
    state = state.copyWith(selected: null);
    await load();
  }
}

final creatorsControllerProvider =
    StateNotifierProvider<CreatorsController, CreatorsState>((ref) {
      final repo = ref.watch(creatorRepositoryProvider);
      final supabaseUrl = AppConfigStore.current?.url ?? '';
      return CreatorsController(repo, supabaseUrl);
    });
