import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/supabase_client_provider.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final url = AppConfigStore.current?.url ?? 'Unknown';
    final user = client.auth.currentUser;

    return ListView(
      children: [
        SectionCard(
          title: 'Session',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supabase URL: $url'),
              const SizedBox(height: 8),
              Text('User: ${user?.email ?? 'Unknown'}'),
            ],
          ),
        ),
        SectionCard(
          title: 'Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Use Supabase RLS policies to protect admin data.'),
              SizedBox(height: 8),
              Text('Jobs are queued; the worker handles delivery to Fanvue.'),
            ],
          ),
        ),
      ],
    );
  }
}
