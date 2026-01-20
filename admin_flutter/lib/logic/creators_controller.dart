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
    required this.error,
  });

  final List<Creator> creators;
  final Creator? selected;
  final bool loading;
  final bool oauthConnected;
  final String? error;

  CreatorsState copyWith({
    List<Creator>? creators,
    Creator? selected,
    bool? loading,
    bool? oauthConnected,
    String? error,
  }) {
    return CreatorsState(
      creators: creators ?? this.creators,
      selected: selected ?? this.selected,
      loading: loading ?? this.loading,
      oauthConnected: oauthConnected ?? this.oauthConnected,
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
      final selected = state.selected ??
          (creators.isNotEmpty ? creators.first : null);
      final oauthConnected = selected == null
          ? false
          : await _repository.hasOAuthToken(selected.id);
      state = state.copyWith(
        creators: creators,
        selected: selected,
        loading: false,
        oauthConnected: oauthConnected,
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
    state = state.copyWith(selected: creator, oauthConnected: oauthConnected);
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
    required int arrogance,
    required int dominance,
    required int lewdness,
    required String replyLength,
    required bool isActive,
  }) async {
    final selected = state.selected;
    if (selected == null) return;
    final settings = Map<String, dynamic>.from(selected.settings);
    settings.addAll({
      'arrogance': arrogance,
      'dominance': dominance,
      'lewdness': lewdness,
      'reply_length': replyLength,
    });
    await _repository.updateCreatorSettings(
      creatorId: selected.id,
      settings: settings,
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
}

final creatorsControllerProvider =
    StateNotifierProvider<CreatorsController, CreatorsState>((ref) {
  final repo = ref.watch(creatorRepositoryProvider);
  final supabaseUrl = AppConfigStore.current?.url ?? '';
  return CreatorsController(repo, supabaseUrl);
});
