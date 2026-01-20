import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/job.dart';
import '../data/repositories/jobs_repository.dart';

class JobsController extends StateNotifier<AsyncValue<List<Job>>> {
  JobsController(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final JobsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.listJobs());
  }

  Future<void> retry(Job job) async {
    await _repository.retryJob(job.id);
    await load();
  }

  Future<void> cancel(Job job) async {
    await _repository.cancelJob(job.id);
    await load();
  }
}

final jobsControllerProvider =
    StateNotifierProvider<JobsController, AsyncValue<List<Job>>>((ref) {
  return JobsController(ref.watch(jobsRepositoryProvider));
});
