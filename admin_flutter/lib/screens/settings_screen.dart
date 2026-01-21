import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/supabase_client_provider.dart';
import '../l10n/app_localizations.dart';
import '../logic/locale_controller.dart';

// --- THEME CONSTANTS (Premium Dark) ---
const kBgColorDark = Color(0xFF0F1115);
const kCardColorDark = Color(0xFF1B222F);
const kPrimaryColor = Color(0xFF06B6D4); // Cyan-500
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF9CA3AF);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final url = AppConfigStore.current?.url ?? 'Unknown';
    final user = client.auth.currentUser;
    final strings = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    // Helper decoration for cards
    final cardDecoration = BoxDecoration(
      color: kCardColorDark,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: kBgColorDark,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Screen Title
          Row(
            children: [
              const Icon(Icons.settings, color: kPrimaryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                strings.settingsTitle,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // General Settings / Language
          Container(
            decoration: cardDecoration,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'General',
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, color: kTextSecondary),
                        const SizedBox(width: 12),
                        Text(
                          strings.language,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kBgColorDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButton<Locale>(
                        value: currentLocale,
                        dropdownColor: kCardColorDark,
                        underline: const SizedBox(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: kPrimaryColor,
                        ),
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: Locale('en'),
                            child: Row(children: [Text('🇺🇸 English')]),
                          ),
                          DropdownMenuItem(
                            value: Locale('de'),
                            child: Row(children: [Text('🇩🇪 Deutsch')]),
                          ),
                        ],
                        onChanged: (Locale? newLocale) {
                          if (newLocale != null) {
                            ref
                                .read(localeProvider.notifier)
                                .setLocale(newLocale);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Session Info
          Container(
            decoration: cardDecoration,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.session,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.link, strings.supabaseUrl, url),
                const Divider(color: Colors.white10, height: 24),
                _buildInfoRow(
                  Icons.person,
                  strings.user,
                  user?.email ?? 'Unknown',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notes
          Container(
            decoration: cardDecoration,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.notes,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _buildNoteItem(strings.notesContent1),
                const SizedBox(height: 12),
                _buildNoteItem(strings.notesContent2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kTextSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: kTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(color: kTextPrimary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: kPrimaryColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: kTextSecondary.withOpacity(0.8),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
