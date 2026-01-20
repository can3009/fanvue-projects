import 'package:shared_preferences/shared_preferences.dart';

class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
  });

  final String url;
  final String anonKey;
}

class AppConfigStore {
  static const _urlKey = 'supabase_url';
  static const _anonKeyKey = 'supabase_anon_key';
  static SupabaseConfig? _current;

  static SupabaseConfig? get current => _current;

  static Future<SupabaseConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final anonKey = prefs.getString(_anonKeyKey);
    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      _current = null;
      return null;
    }
    _current = SupabaseConfig(url: url, anonKey: anonKey);
    return _current;
  }

  static Future<void> save(SupabaseConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, config.url.trim());
    await prefs.setString(_anonKeyKey, config.anonKey.trim());
    _current = config;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_anonKeyKey);
    _current = null;
  }
}
