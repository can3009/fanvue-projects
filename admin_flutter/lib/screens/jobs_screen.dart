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
              // Process Queue Button
              state.processing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () => ref
                          .read(jobsControllerProvider.notifier)
                          .processQueue(),
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Process all queued jobs',
                    ),
              IconButton(
                onPressed: () =>
                    ref.read(jobsControllerProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
            child: state.jobs.isEmpty
                ? const Text('No jobs found.')
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
    return ListTile(
      title: Text('${job.type} • ${job.status}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Creator: $creatorLabel'),
          Text('Run at: $runAt'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: onRetry, child: const Text('Retry')),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
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
