import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/job.dart';
import '../logic/jobs_controller.dart';
import '../logic/jobs_worker_controller.dart';
import '../l10n/app_localizations.dart';

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

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobsControllerProvider);
    final worker = ref.watch(jobsWorkerControllerProvider);
    final strings = AppLocalizations.of(context);

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

    if (state.loading && state.jobs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      );
    }

    if (state.error != null && state.jobs.isEmpty) {
      return Center(
        child: Text(state.error!, style: const TextStyle(color: kDangerColor)),
      );
    }

    return Scaffold(
      backgroundColor: kBgColorDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- Header & Controls ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cardDecoration,
              child: Row(
                children: [
                  const Icon(
                    Icons.work_history,
                    color: kPrimaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    strings.jobsQueue,
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),

                  // Filter
                  Container(
                    decoration: BoxDecoration(
                      color: kBgColorDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _CreatorFilterDropdown(
                      creators: state.creators,
                      selectedIds: state.selectedCreatorIds,
                      onToggle: (id) => ref
                          .read(jobsControllerProvider.notifier)
                          .toggleCreator(id),
                      onSelectAll: () => ref
                          .read(jobsControllerProvider.notifier)
                          .selectAllCreators(),
                      onDeselectAll: () => ref
                          .read(jobsControllerProvider.notifier)
                          .deselectAllCreators(),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Refresh Button
                  IconButton(
                    onPressed: () =>
                        ref.read(jobsControllerProvider.notifier).load(),
                    icon: const Icon(Icons.refresh, color: kTextSecondary),
                    tooltip: strings.refreshJobs /* TODO: Localize tooltip? */,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Process Button (JobsWorkerController) ---
            worker.running
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kWarningColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kWarningColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kWarningColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              worker.running
                                  ? "Loop Running..."
                                  : "Stopping...",
                              style: const TextStyle(
                                color: kWarningColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(jobsWorkerControllerProvider.notifier)
                                  .stop(),
                              icon: const Icon(
                                Icons.pause,
                                color: kWarningColor,
                              ),
                              label: Text(
                                strings.pause,
                                style: const TextStyle(color: kWarningColor),
                              ),
                            ),
                          ],
                        ),
                        if (worker.lastError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "Error: ${worker.lastError}",
                              style: const TextStyle(
                                color: kDangerColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatBadge(
                              label: "Completed",
                              count: worker.totalCompleted,
                              color: kSuccessColor,
                            ),
                            _StatBadge(
                              label: "Failed",
                              count: worker.totalFailed,
                              color: kDangerColor,
                            ),
                            _StatBadge(
                              label: "Skipped",
                              count: worker.totalSkipped,
                              color: kWarningColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kSuccessColor, kSuccessColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: kSuccessColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => ref
                            .read(jobsWorkerControllerProvider.notifier)
                            .start(),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 24,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.startProcessingQueue,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Runs background worker every 2s",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
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

            const SizedBox(height: 24),

            // --- Jobs List ---
            Expanded(
              child: Container(
                decoration: cardDecoration,
                child: state.jobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 64,
                              color: Colors.white10,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              strings.noJobsFound,
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: state.jobs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final job = state.jobs[index];
                            return _JobTile(
                              job: job,
                              onRetry: () => ref
                                  .read(jobsControllerProvider.notifier)
                                  .retry(job),
                              onCancel: () => ref
                                  .read(jobsControllerProvider.notifier)
                                  .cancel(job),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown widget to filter creators for job processing
class _CreatorFilterDropdown extends StatelessWidget {
  const _CreatorFilterDropdown({
    required this.creators,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  final List creators;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedIds.isNotEmpty;
    final strings = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      color: kCardColorDark,
      tooltip: strings.filterByCreator, // Localized tooltip
      icon: Badge(
        isLabelVisible: hasSelection,
        label: Text('${selectedIds.length}'),
        child: Icon(
          Icons.filter_list,
          color: hasSelection ? kPrimaryColor : kTextSecondary,
        ),
      ),
      itemBuilder: (context) => [
        // Header with select all / deselect all
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.filterByCreator, // Localized header
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      onSelectAll();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'All',
                      style: TextStyle(color: kPrimaryColor),
                    ) /* TODO: Localize 'All' */,
                  ),
                  TextButton(
                    onPressed: () {
                      onDeselectAll();
                      Navigator.pop(context);
                    },
                    child: Text(
                      strings.none,
                      style: const TextStyle(color: kTextSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        // Creator list
        ...creators.map((creator) {
          final isSelected = selectedIds.contains(creator.id);
          return PopupMenuItem<String>(
            value: creator.id,
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) {},
                  activeColor: kPrimaryColor,
                  checkColor: Colors.white,
                  side: const BorderSide(color: kTextSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    creator.displayName,
                    style: const TextStyle(color: kTextPrimary),
                  ),
                ),
              ],
            ),
          );
        }),
        // Info text at bottom
        if (creators.isEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              strings.noCreatorsFound,
              style: const TextStyle(color: kTextSecondary),
            ),
          ),
      ],
      onSelected: (creatorId) {
        onToggle(creatorId);
      },
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({
    required this.job,
    required this.onRetry,
    required this.onCancel,
  });

  final Job job;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final runAt = _formatDate(job.runAt);
    final creatorLabel = job.creatorName ?? strings.unknown;

    // Color based on status
    Color statusColor;
    IconData statusIcon;

    switch (job.status) {
      case 'queued':
        statusColor = kPrimaryColor; // Blue/Cyan
        statusIcon = Icons.schedule;
        break;
      case 'processing':
        statusColor = kWarningColor; // Orange
        statusIcon = Icons.hourglass_top;
        break;
      case 'completed':
        statusColor = kSuccessColor; // Green
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = kDangerColor; // Red
        statusIcon = Icons.error;
        break;
      default:
        statusColor = kTextSecondary;
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kBgColorDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Text(
              job.type.toUpperCase(),
              style: const TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                job.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: kTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    creatorLabel,
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: kTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    runAt,
                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
              if (job.lastError != null && job.lastError!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${strings.errorLabel}${job.lastError}',
                  style: TextStyle(
                    color: kDangerColor.withOpacity(0.8),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (job.status == 'failed' || job.status == 'queued')
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: kPrimaryColor),
                tooltip: strings.retry,
              ),
            if (job.status == 'queued' || job.status == 'processing')
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, color: kDangerColor),
                tooltip: strings.cancel,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: kTextSecondary.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Unknown';
  try {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  } catch (_) {
    return value.toIso8601String();
  }
}
