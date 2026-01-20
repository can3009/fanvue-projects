import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator.dart';
import '../models/fan.dart';
import '../models/message.dart';
import '../supabase_client_provider.dart';

class FansRepository {
  FansRepository(this._client);

  final SupabaseClient _client;

  Future<List<Creator>> listCreators() async {
    final data = await _client
        .from('creators')
        .select('*')
        .order('created_at', ascending: false);
    return (data as List).map((row) => Creator.fromMap(row)).toList();
  }

  Future<List<Fan>> listFans(String creatorId) async {
    final data = await _client
        .from('fans')
        .select('*')
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false);
    return (data as List).map((row) => Fan.fromMap(row)).toList();
  }

  Future<List<ChatMessage>> listMessages({
    required String creatorId,
    required String fanId,
  }) async {
    final data = await _client
        .from('messages')
        .select('*')
        .eq('creator_id', creatorId)
        .eq('fan_id', fanId)
        .order('created_at', ascending: true)
        .limit(100);
    return (data as List).map((row) => ChatMessage.fromMap(row)).toList();
  }

  Future<void> enqueueManualReply({
    required String creatorId,
    required String fanId,
    required String message,
  }) async {
    await _client.from('jobs_queue').insert({
      'creator_id': creatorId,
      'fan_id': fanId,
      'job_type': 'reply',
      'status': 'queued',
      'run_at': DateTime.now().toIso8601String(),
      'payload': {'fan_message': message, 'manual': true},
    });
  }
}

final fansRepositoryProvider = Provider<FansRepository>((ref) {
  return FansRepository(ref.watch(supabaseClientProvider));
});
