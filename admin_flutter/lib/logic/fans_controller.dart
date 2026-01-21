import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/creator.dart';
import '../data/models/fan.dart';
import '../data/models/message.dart';
import '../data/repositories/fans_repository.dart';

class FansState {
  const FansState({
    required this.creators,
    required this.selectedCreator,
    required this.fans,
    required this.selectedFan,
    required this.messages,
    required this.loading,
    required this.error,
  });

  final List<Creator> creators;
  final Creator? selectedCreator;
  final List<Fan> fans;
  final Fan? selectedFan;
  final List<ChatMessage> messages;
  final bool loading;
  final String? error;

  FansState copyWith({
    List<Creator>? creators,
    Creator? selectedCreator,
    List<Fan>? fans,
    Fan? selectedFan,
    List<ChatMessage>? messages,
    bool? loading,
    String? error,
  }) {
    return FansState(
      creators: creators ?? this.creators,
      selectedCreator: selectedCreator ?? this.selectedCreator,
      fans: fans ?? this.fans,
      selectedFan: selectedFan ?? this.selectedFan,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class FansController extends StateNotifier<FansState> {
  FansController(this._repository)
      : super(
          const FansState(
            creators: [],
            selectedCreator: null,
            fans: [],
            selectedFan: null,
            messages: [],
            loading: true,
            error: null,
          ),
        ) {
    loadCreators();
  }

  final FansRepository _repository;

  Future<void> loadCreators() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final creators = await _repository.listCreators();
      final selectedCreator = state.selectedCreator ??
          (creators.isNotEmpty ? creators.first : null);
      state = state.copyWith(
        creators: creators,
        selectedCreator: selectedCreator,
        loading: false,
      );
      if (selectedCreator != null) {
        await loadFans(selectedCreator);
      }
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> loadFans(Creator creator) async {
    final fans = await _repository.listFans(creator.id);
    // Reset selectedFan when switching creators - the old fan doesn't belong to the new creator
    final selectedFan = fans.isNotEmpty ? fans.first : null;
    state = state.copyWith(
      selectedCreator: creator,
      fans: fans,
      selectedFan: selectedFan,
      messages: [],
    );
    if (selectedFan != null) {
      await loadMessages(selectedFan);
    }
  }

  Future<void> loadMessages(Fan fan) async {
    final creator = state.selectedCreator;
    if (creator == null) return;
    final messages = await _repository.listMessages(
      creatorId: creator.id,
      fanId: fan.id,
    );
    state = state.copyWith(selectedFan: fan, messages: messages);
  }

  Future<void> enqueueReply(String message) async {
    final creator = state.selectedCreator;
    final fan = state.selectedFan;
    if (creator == null || fan == null) return;
    await _repository.enqueueManualReply(
      creatorId: creator.id,
      fanId: fan.id,
      message: message,
    );
    await loadMessages(fan);
  }

  Future<void> deleteFan(Fan fan) async {
    final creator = state.selectedCreator;
    if (creator == null) return;
    await _repository.deleteFan(fan.id);
    // Reload fans list after deletion
    await loadFans(creator);
  }
}

final fansControllerProvider =
    StateNotifierProvider<FansController, FansState>((ref) {
  return FansController(ref.watch(fansRepositoryProvider));
});
