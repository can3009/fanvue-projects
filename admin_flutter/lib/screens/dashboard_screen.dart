import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/dashboard_controller.dart';
import 'onboarding_screen.dart';
import 'package:admin_flutter/l10n/app_localizations.dart';
import '../widgets/mass_messages_dialog.dart';
import '../widgets/ppv_requests_dialog.dart';

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
                      child: Container(
                        height: 125,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kCardColorDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              kCardColorDark,
                              kCardColorDark.withLightness(0.12),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.supervised_user_circle_rounded,
                                    color: kPrimaryColor,
                                    size: 20,
                                  ),
                                ),
                                // Mini Add Button
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const OnboardingScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kPrimaryColor.withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              data.creators.toString(),
                              style: const TextStyle(
                                color: kTextPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.creators,
                              style: TextStyle(
                                color: kTextSecondary.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: strings.queuedJobs,
                        value: data.queuedJobs.toString(),
                        icon: Icons.queue_music_rounded,
                        color: kSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const PPVRequestsDialog(),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: const _MetricTile(
                          label: 'PPV Requests',
                          value: '12',
                          icon: Icons.shopping_bag_outlined,
                          color: kWarningColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: strings.dailyRevenue,
                        value: '\$1,029', // Mock value
                        icon: Icons.attach_money_rounded,
                        color: kSuccessColor,
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
                  padding: const EdgeInsets.all(
                    0,
                  ), // Removed padding for full bleed look
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [kSecondaryColor, Color(0xFF818CF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kSecondaryColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const MassMessagesDialog(),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 24,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Mass Messages',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Reach all fans with AI magic',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                            final direction =
                                row['direction']?.toString() ?? 'inbound';
                            final isOutbound =
                                direction ==
                                'outbound'; // Outbound = Creator sent it
                            final content =
                                row['content'] ??
                                row['text'] ??
                                row['message'] ??
                                '';

                            // Parse sender info
                            final fans = row['fans'] as Map<String, dynamic>?;
                            final creators =
                                row['creators'] as Map<String, dynamic>?;

                            String senderName = strings.unknown;
                            String? avatarUrl;

                            if (isOutbound) {
                              senderName =
                                  creators?['display_name'] ?? strings.creator;
                              avatarUrl = creators?['avatar_url'];
                            } else {
                              senderName =
                                  fans?['username'] ??
                                  fans?['display_name'] ??
                                  strings.fan;
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: isOutbound
                                    ? kPrimaryColor.withOpacity(0.2)
                                    : kSecondaryColor.withOpacity(0.2),
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? (isOutbound
                                          ? Text(
                                              senderName.isNotEmpty
                                                  ? senderName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: kPrimaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              color: kSecondaryColor,
                                              size: 20,
                                            ))
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  if (isOutbound) ...[
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kPrimaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        senderName,
                                        style: const TextStyle(
                                          color: kPrimaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        color: kTextSecondary.withOpacity(0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      _formatDate(row['created_at'], strings),
                                      style: TextStyle(
                                        color: kTextSecondary.withOpacity(0.5),
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  content.toString(),
                                  style: const TextStyle(
                                    color: kTextPrimary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
      height: 125, // Increased height to prevent overflow
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColorDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kCardColorDark, kCardColorDark.withLightness(0.12)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: kTextSecondary.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1, // Ensure single line label
            overflow: TextOverflow.ellipsis,
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
