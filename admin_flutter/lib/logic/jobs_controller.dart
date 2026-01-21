import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/creator.dart';
import '../data/models/job.dart';
import '../data/repositories/jobs_repository.dart';

class JobsState {
  const JobsState({
    required this.jobs,
    required this.creators,
    required this.selectedCreatorIds,
    required this.loading,
    required this.processing,
    this.error,
  });

  final List<Job> jobs;
  final List<Creator> creators;
  final Set<String> selectedCreatorIds;
  final bool loading;
  final bool processing;
  final String? error;

  JobsState copyWith({
    List<Job>? jobs,
    List<Creator>? creators,
    Set<String>? selectedCreatorIds,
    bool? loading,
    bool? processing,
    String? error,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      creators: creators ?? this.creators,
      selectedCreatorIds: selectedCreatorIds ?? this.selectedCreatorIds,
      loading: loading ?? this.loading,
      processing: processing ?? this.processing,
      error: error,
    );
  }
}

class JobsController extends StateNotifier<JobsState> {
  JobsController(this._repository)
      : super(const JobsState(
          jobs: [],
          creators: [],
          selectedCreatorIds: {},
          loading: true,
          processing: false,
        )) {
    load();
  }

  final JobsRepository _repository;
  bool _stopRequested = false;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final jobs = await _repository.listJobs();
      final creators = await _repository.listCreators();
      state = state.copyWith(jobs: jobs, creators: creators, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void toggleCreator(String creatorId) {
    final newSet = Set<String>.from(state.selectedCreatorIds);
    if (newSet.contains(creatorId)) {
      newSet.remove(creatorId);
    } else {
      newSet.add(creatorId);
    }
    state = state.copyWith(selectedCreatorIds: newSet);
  }

  void selectAllCreators() {
    final allIds = state.creators.map((c) => c.id).toSet();
    state = state.copyWith(selectedCreatorIds: allIds);
  }

  void deselectAllCreators() {
    state = state.copyWith(selectedCreatorIds: {});
  }

  Future<void> retry(Job job) async {
    await _repository.retryJob(job.id);
    await load();
  }

  Future<void> cancel(Job job) async {
    await _repository.cancelJob(job.id);
    await load();
  }

  /// Stops the queue processing.
  void stopProcessing() {
    _stopRequested = true;
  }

  /// Processes queued jobs continuously until manually stopped.
  /// Polls every 5 seconds for new jobs when idle.
  Future<void> processQueue() async {
    if (state.processing) return;

    _stopRequested = false;
    state = state.copyWith(processing: true, error: null);

    try {
      final selectedIds = state.selectedCreatorIds;

      // Continuous processing loop - runs until manually stopped
      while (!_stopRequested) {
        bool didProcess = false;

        // If no creators selected, process all
        if (selectedIds.isEmpty) {
          didProcess = await _repository.triggerWorker();
        } else {
          // Process only selected creators (round-robin)
          for (final creatorId in selectedIds) {
            if (_stopRequested) break;
            final processed =
                await _repository.triggerWorker(creatorId: creatorId);
            if (processed) didProcess = true;
          }
        }

        // Refresh job list
        await load();

        // If no jobs were processed, wait 5 seconds before checking again
        // This prevents hammering the server when there are no jobs
        if (!didProcess && !_stopRequested) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      state = state.copyWith(processing: false);
    } catch (e) {
      state = state.copyWith(processing: false, error: e.toString());
    }
    await load();
  }
}

final jobsControllerProvider =
    StateNotifierProvider<JobsController, JobsState>(
  (ref) {
    return JobsController(ref.watch(jobsRepositoryProvider));
  },
);
