import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/job.dart';
import '../data/repositories/jobs_repository.dart';

class JobsState {
  const JobsState({
    required this.jobs,
    required this.loading,
    required this.processing,
    this.error,
  });

  final List<Job> jobs;
  final bool loading;
  final bool processing;
  final String? error;

  JobsState copyWith({
    List<Job>? jobs,
    bool? loading,
    bool? processing,
    String? error,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      loading: loading ?? this.loading,
      processing: processing ?? this.processing,
      error: error,
    );
  }
}

class JobsController extends StateNotifier<JobsState> {
  JobsController(this._repository)
    : super(const JobsState(jobs: [], loading: true, processing: false)) {
    load();
  }

  final JobsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final jobs = await _repository.listJobs();
      state = state.copyWith(jobs: jobs, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> retry(Job job) async {
    await _repository.retryJob(job.id);
    await load();
  }

  Future<void> cancel(Job job) async {
    await _repository.cancelJob(job.id);
    await load();
  }

  /// Processes all queued jobs by repeatedly calling the worker.
  Future<void> processQueue() async {
    if (state.processing) return; // Already processing
    state = state.copyWith(processing: true, error: null);
    try {
      while (true) {
        final didProcess = await _repository.triggerWorker();
        if (!didProcess) break;
        // Refresh list after each job
        await load();
      }
      state = state.copyWith(processing: false);
    } catch (e) {
      state = state.copyWith(processing: false, error: e.toString());
    }
    await load();
  }
}

final jobsControllerProvider = StateNotifierProvider<JobsController, JobsState>(
  (ref) {
    return JobsController(ref.watch(jobsRepositoryProvider));
  },
);
