import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/dashboard_controller.dart';
import 'onboarding_screen.dart';
import 'package:admin_flutter/l10n/app_localizations.dart';

// --- THEME CONSTANTS (Premium Dark) ---
const kBgColorDark = Color(0xFF0F1115);
const kCardColorDark = Color(0xFF1B222F);
const kPrimaryColor = Color(0xFF06B6D4); // Cyan-500
const kSecondaryColor = Color(0xFF6366F1); // Indigo-500
const kSuccessColor = Color(0xFF10B981);
const kDangerColor = Color(0xFFEF4444);
const kWarningColor = Color(0xFFF59E0B);
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF9CA3AF);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final strings = AppLocalizations.of(context);

    // Using a refined Scaffold background
    return Scaffold(
      backgroundColor: kBgColorDark,
      body: dashboard.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
        error: (error, _) => Center(
          child: Text(
            strings.errorLoadingDashboard(error.toString()),
            style: const TextStyle(color: kDangerColor),
          ),
        ),
        data: (data) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header / Overview Section
                _buildSectionHeader(
                  context,
                  strings.overview,
                  icon: Icons.dashboard_rounded,
                  action: IconButton(
                    onPressed: () => ref
                        .read(dashboardControllerProvider.notifier)
                        .refresh(),
                    icon: const Icon(Icons.refresh, color: kPrimaryColor),
                    tooltip: strings.refreshData,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: strings.creators,
                        value: data.creators.toString(),
                        icon: Icons.supervised_user_circle_rounded,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricTile(
                        label: strings.queuedJobs,
                        value: data.queuedJobs.toString(),
                        icon: Icons.queue_music_rounded,
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Quick Actions
                _buildSectionHeader(
                  context,
                  strings.quickActions,
                  icon: Icons.flash_on_rounded,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OnboardingScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(strings.addCreator),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor.withOpacity(0.15),
                          foregroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          elevation: 0,
                          side: BorderSide(
                            color: kPrimaryColor.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Latest Messages (Now before Errors)
                _buildSectionHeader(
                  context,
                  strings.latestMessages,
                  icon: Icons.mark_chat_read_rounded,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: _cardDecoration,
                  child: data.recentMessages.isEmpty
                      ? _buildEmptyState(strings.noMessagesReceived)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.recentMessages.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withOpacity(0.05),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final row = data.recentMessages[index];
                            final content =
                                row['content'] ??
                                row['text'] ??
                                row['message'] ??
                                '';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: kSecondaryColor.withOpacity(
                                  0.2,
                                ),
                                child: Text(
                                  strings.msg,
                                  style: const TextStyle(
                                    color: kSecondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                content.toString(),
                                style: const TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _formatDate(row['created_at'], strings),
                                  style: TextStyle(
                                    color: kTextSecondary.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 32),

                // Recent Job Errors (Moved to Bottom)
                _buildSectionHeader(
                  context,
                  strings.recentJobErrors,
                  icon: Icons.error_outline_rounded,
                  color: kDangerColor,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: _cardDecoration,
                  child: data.recentErrors.isEmpty
                      ? _buildEmptyState(strings.noRecentErrors)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.recentErrors.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withOpacity(0.05),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final row = data.recentErrors[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kDangerColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: kDangerColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                row['last_error']?.toString() ??
                                    strings.unknownError,
                                style: const TextStyle(
                                  color: kTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                _formatDate(row['created_at'], strings),
                                style: const TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets & Styles ---

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: kCardColorDark,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.05)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    required IconData icon,
    Widget? action,
    Color color = kTextPrimary,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: color == kTextPrimary ? kPrimaryColor : color,
          size: 22,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        if (action != null) ...[const Spacer(), action],
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: kTextSecondary.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160, // Fixed height for consistency
      // Width is controlled by parent Expanded/Row
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardColorDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kCardColorDark,
            kCardColorDark.withLightness(
              0.12,
            ), // Slight lighten extension method or manual tweak needed? Let's stick to simple opacity overlay if needed
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: kTextSecondary.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorExtension on Color {
  Color withLightness(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

String _formatDate(dynamic value, AppLocalizations strings) {
  if (value == null) return 'Unknown time';
  try {
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return DateFormat('MMM d, HH:mm').format(date);
  } catch (_) {
    return value.toString();
  }
}
