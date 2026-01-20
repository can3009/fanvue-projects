import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/dashboard_controller.dart';
import '../widgets/section_card.dart';
import 'onboarding_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionCard(
              title: 'Overview',
              actions: [
                IconButton(
                  onPressed: () =>
                      ref.read(dashboardControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricTile(
                    label: 'Creators',
                    value: data.creators.toString(),
                    icon: Icons.supervised_user_circle,
                  ),
                  _MetricTile(
                    label: 'Queued jobs',
                    value: data.queuedJobs.toString(),
                    icon: Icons.queue,
                  ),
                ],
              ),
            ),
            // Quick Actions - Add Creator
            SectionCard(
              title: 'Quick Actions',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Creator'),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Recent job errors',
              child: data.recentErrors.isEmpty
                  ? const Text('No recent errors.')
                  : Column(
                      children: data.recentErrors.map((row) {
                        return ListTile(
                          title: Text(
                            row['last_error']?.toString() ?? 'Unknown error',
                          ),
                          subtitle: Text(_formatDate(row['created_at'])),
                        );
                      }).toList(),
                    ),
            ),
            SectionCard(
              title: 'Latest messages',
              child: data.recentMessages.isEmpty
                  ? const Text('No messages yet.')
                  : Column(
                      children: data.recentMessages.map((row) {
                        final content =
                            row['content'] ??
                            row['text'] ??
                            row['message'] ??
                            '';
                        return ListTile(
                          title: Text(
                            content.toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_formatDate(row['created_at'])),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B222F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null) return 'Unknown time';
  try {
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  } catch (_) {
    return value.toString();
  }
}
