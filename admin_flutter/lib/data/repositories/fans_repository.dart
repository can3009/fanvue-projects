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

    final fans = <Fan>[];
    for (final row in (data as List)) {
      final fanId = row['id']?.toString() ?? '';

      // Get the last message time for this fan
      DateTime? lastMessageAt;
      try {
        final lastMsgData = await _client
            .from('messages')
            .select('created_at')
            .eq('creator_id', creatorId)
            .eq('fan_id', fanId)
            .order('created_at', ascending: false)
            .limit(1);
        if ((lastMsgData as List).isNotEmpty) {
          lastMessageAt = DateTime.tryParse(
            lastMsgData[0]['created_at']?.toString() ?? '',
          );
        }
      } catch (_) {
        // Ignore errors fetching last message
      }

      fans.add(
        Fan(
          id: fanId,
          fanvueId:
              row['fanvue_fan_id']?.toString() ??
              row['fanvue_id']?.toString() ??
              '',
          username: row['username']?.toString() ?? '',
          displayName:
              row['display_name']?.toString() ??
              row['displayName']?.toString() ??
              row['username']?.toString() ??
              'Unknown',
          lastMessageAt: lastMessageAt,
        ),
      );
    }

    // Sort by lastMessageAt descending (most recent first)
    // Fans without messages go to the end
    fans.sort((a, b) {
      if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });

    return fans;
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

  Future<void> deleteFan(String fanId) async {
    // Delete related data first (messages, jobs, conversation_state)
    await _client.from('messages').delete().eq('fan_id', fanId);
    await _client.from('jobs_queue').delete().eq('fan_id', fanId);
    await _client.from('conversation_state').delete().eq('fan_id', fanId);
    await _client.from('fan_profiles').delete().eq('fan_id', fanId);
    // Finally delete the fan
    await _client.from('fans').delete().eq('id', fanId);
  }
}

final fansRepositoryProvider = Provider<FansRepository>((ref) {
  return FansRepository(ref.watch(supabaseClientProvider));
});
