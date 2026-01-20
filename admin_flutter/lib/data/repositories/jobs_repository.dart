import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/job.dart';
import '../supabase_client_provider.dart';

class JobsRepository {
  JobsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Job>> listJobs() async {
    final data = await _client
        .from('jobs_queue')
        .select('*')
        .order('created_at', ascending: false)
        .limit(200);
    return (data as List).map((row) => Job.fromMap(row)).toList();
  }

  Future<void> retryJob(String jobId) async {
    await _client.from('jobs_queue').update({
      'status': 'queued',
      'last_error': null,
      'run_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> cancelJob(String jobId) async {
    await _client.from('jobs_queue').update({
      'status': 'failed',
      'last_error': 'Cancelled by admin',
    }).eq('id', jobId);
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(supabaseClientProvider));
});
