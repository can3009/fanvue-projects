import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'l10n/app_localizations.dart';
import 'logic/locale_controller.dart';
import 'screens/auth_gate.dart';
import 'screens/config_screen.dart';
import 'theme/app_theme.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  SupabaseConfig? _config;
  bool _loading = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await AppConfigStore.load();
      if (config != null) {
        await Supabase.initialize(url: config.url, anonKey: config.anonKey);
      }
      setState(() {
        _config = config;
        _loading = false;
        _initError = null;
      });
    } catch (error) {
      setState(() {
        _initError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig(SupabaseConfig config) async {
    setState(() {
      _loading = true;
      _initError = null;
    });
    try {
      await AppConfigStore.save(config);
      await Supabase.initialize(url: config.url, anonKey: config.anonKey);
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _initError = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Fanvue Bot Admin',
      theme: buildDarkTheme(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('de', '')],
      debugShowCheckedModeBanner: false,
      home: _loading
          ? const _LoadingSplash()
          : _config == null
          ? ConfigScreen(onSaved: _saveConfig, errorMessage: _initError)
          : AuthGate(
              onReconfigure: () async {
                await AppConfigStore.clear();
                if (Supabase.instance.client.auth.currentSession != null) {
                  await Supabase.instance.client.auth.signOut();
                }
                setState(() {
                  _config = null;
                });
              },
            ),
    );
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
