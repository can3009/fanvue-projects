import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_client_provider.dart';
import 'login_screen.dart';
import 'shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.onReconfigure});

  final VoidCallback onReconfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(supabaseClientProvider).auth;
    return StreamBuilder(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = auth.currentSession;
        if (session == null) {
          return LoginScreen(onReconfigure: onReconfigure);
        }
        return AppShell(onReconfigure: onReconfigure);
      },
    );
  }
}
