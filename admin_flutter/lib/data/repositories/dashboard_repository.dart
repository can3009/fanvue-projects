import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_metrics.dart';
import '../supabase_client_provider.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardMetrics> loadMetrics() async {
    try {
      dev.log('Loading creators count...');
      final creatorsCountResponse = await _client
          .from('creators')
          .select()
          .count(CountOption.exact);
      dev.log('Creators count: ${creatorsCountResponse.count}');

      dev.log('Loading jobs count...');
      final queuedJobsCountResponse = await _client
          .from('jobs_queue')
          .select()
          .eq('status', 'queued')
          .count(CountOption.exact);
      dev.log('Jobs count: ${queuedJobsCountResponse.count}');

      dev.log('Loading errors...');
      final errors = await _client
          .from('jobs_queue')
          .select('last_error, created_at')
          .not('last_error', 'is', null)
          .order('created_at', ascending: false)
          .limit(5);
      dev.log('Errors loaded: ${errors.length}');

      dev.log('Loading messages...');
      final lastMessages = await _client
          .from('messages')
          .select(
            '*, fans!fk_messages_fan(username, display_name), creators!messages_creator_id_fkey(display_name, avatar_url)',
          )
          .order('created_at', ascending: false)
          .limit(5);
      dev.log('Messages loaded: ${lastMessages.length}');

      return DashboardMetrics(
        creators: creatorsCountResponse.count,
        queuedJobs: queuedJobsCountResponse.count,
        recentErrors: List<Map<String, dynamic>>.from(errors as List),
        recentMessages: List<Map<String, dynamic>>.from(lastMessages as List),
      );
    } catch (e, stack) {
      dev.log('Dashboard error: $e', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});
