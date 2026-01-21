import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator.dart';
import '../models/job.dart';
import '../supabase_client_provider.dart';

class JobsRepository {
  JobsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Job>> listJobs() async {
    final data = await _client
        .from('jobs_queue')
        .select('*, creators!jobs_queue_creator_id_fkey(display_name)')
        .order('created_at', ascending: false)
        .limit(200);
    return (data as List).map((row) => Job.fromMap(row)).toList();
  }

  Future<List<Creator>> listCreators() async {
    final data = await _client
        .from('creators')
        .select('*')
        .order('display_name', ascending: true);
    return (data as List).map((row) => Creator.fromMap(row)).toList();
  }

  Future<void> retryJob(String jobId) async {
    await _client
        .from('jobs_queue')
        .update({
          'status': 'queued',
          'last_error': null,
          'run_at': DateTime.now().toIso8601String(),
        })
        .eq('id', jobId);
  }

  Future<void> cancelJob(String jobId) async {
    await _client
        .from('jobs_queue')
        .update({'status': 'failed', 'last_error': 'Cancelled by admin'})
        .eq('id', jobId);
  }

  /// Triggers the jobs-worker Edge Function to process the next queued job.
  /// Returns true if a job was processed, false if no jobs remain.
  /// If creatorId is provided, only processes jobs for that creator.
  Future<bool> triggerWorker({String? creatorId}) async {
    final body = creatorId != null ? {'creatorId': creatorId} : null;
    final response = await _client.functions.invoke(
      'jobs-worker',
      body: body,
    );
    if (response.status != 200) {
      throw Exception('Worker failed: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>?;
    // If the worker returns a jobId, a job was processed
    if (data != null && data['jobId'] != null) {
      return true;
    }
    // If the worker says "No jobs to process", we're done
    return false;
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(supabaseClientProvider));
});
