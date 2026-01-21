import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/job.dart';
import '../logic/jobs_controller.dart';
import '../widgets/section_card.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobsControllerProvider);

    if (state.loading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.jobs.isEmpty) {
      return Center(child: Text(state.error!));
    }

    return Row(
      children: [
        Expanded(
          child: SectionCard(
            title: 'Jobs queue',
            expand: true,
            actions: [
              // Creator Filter Dropdown
              _CreatorFilterDropdown(
                creators: state.creators,
                selectedIds: state.selectedCreatorIds,
                onToggle: (id) =>
                    ref.read(jobsControllerProvider.notifier).toggleCreator(id),
                onSelectAll: () => ref
                    .read(jobsControllerProvider.notifier)
                    .selectAllCreators(),
                onDeselectAll: () => ref
                    .read(jobsControllerProvider.notifier)
                    .deselectAllCreators(),
              ),
              const SizedBox(width: 8),
              // Play/Pause Button
              state.processing
                  ? IconButton(
                      onPressed: () => ref
                          .read(jobsControllerProvider.notifier)
                          .stopProcessing(),
                      icon: const Icon(Icons.pause, color: Colors.orange),
                      tooltip: 'Pause processing',
                    )
                  : IconButton(
                      onPressed: () => ref
                          .read(jobsControllerProvider.notifier)
                          .processQueue(),
                      icon: const Icon(Icons.play_arrow, color: Colors.green),
                      tooltip: state.selectedCreatorIds.isEmpty
                          ? 'Process all jobs'
                          : 'Process jobs for ${state.selectedCreatorIds.length} creator(s)',
                    ),
              IconButton(
                onPressed: () =>
                    ref.read(jobsControllerProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh jobs',
              ),
            ],
            child: state.jobs.isEmpty
                ? const Center(child: Text('No jobs found.'))
                : ListView.separated(
                    itemCount: state.jobs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
      ],
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

    return PopupMenuButton<String>(
      tooltip: 'Select creators to process',
      icon: Badge(
        isLabelVisible: hasSelection,
        label: Text('${selectedIds.length}'),
        child: Icon(
          Icons.filter_list,
          color: hasSelection ? Theme.of(context).colorScheme.primary : null,
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
                'Filter by Creator',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      onSelectAll();
                      Navigator.pop(context);
                    },
                    child: const Text('All'),
                  ),
                  TextButton(
                    onPressed: () {
                      onDeselectAll();
                      Navigator.pop(context);
                    },
                    child: const Text('None'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // Creator list
        ...creators.map((creator) {
          final isSelected = selectedIds.contains(creator.id);
          return PopupMenuItem<String>(
            value: creator.id,
            child: Row(
              children: [
                Checkbox(value: isSelected, onChanged: (_) {}),
                const SizedBox(width: 8),
                Expanded(child: Text(creator.displayName)),
              ],
            ),
          );
        }),
        // Info text at bottom
        if (creators.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('No creators found'),
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
    final runAt = _formatDate(job.runAt);
    final creatorLabel = job.creatorName ?? 'Unknown';

    // Color based on status
    Color? statusColor;
    switch (job.status) {
      case 'queued':
        statusColor = Colors.blue;
        break;
      case 'processing':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'failed':
        statusColor = Colors.red;
        break;
    }

    return ListTile(
      leading: Icon(
        job.status == 'completed'
            ? Icons.check_circle
            : job.status == 'failed'
            ? Icons.error
            : job.status == 'processing'
            ? Icons.hourglass_top
            : Icons.schedule,
        color: statusColor,
      ),
      title: Text('${job.type} • ${job.status}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('Creator: $creatorLabel'), Text('Run at: $runAt')],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (job.status == 'failed' || job.status == 'queued')
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (job.status == 'queued' || job.status == 'processing')
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel'),
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
