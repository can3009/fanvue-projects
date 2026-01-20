import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_metrics.dart';
import '../supabase_client_provider.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardMetrics> loadMetrics() async {
    final creatorsCountResponse = await _client
        .from('creators')
        .select()
        .count(CountOption.exact);
    final queuedJobsCountResponse = await _client
        .from('jobs_queue')
        .select()
        .eq('status', 'queued')
        .count(CountOption.exact);
    final errors = await _client
        .from('jobs_queue')
        .select('last_error, created_at')
        .not('last_error', 'is', null)
        .order('created_at', ascending: false)
        .limit(5);
    final lastMessages = await _client
        .from('messages')
        .select('*')
        .order('created_at', ascending: false)
        .limit(5);

    return DashboardMetrics(
      creators: creatorsCountResponse.count,
      queuedJobs: queuedJobsCountResponse.count,
      recentErrors: List<Map<String, dynamic>>.from(errors as List),
      recentMessages: List<Map<String, dynamic>>.from(lastMessages as List),
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});
