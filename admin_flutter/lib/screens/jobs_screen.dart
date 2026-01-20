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
    final jobsState = ref.watch(jobsControllerProvider);
    return jobsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (jobs) {
        return SectionCard(
          title: 'Jobs queue',
          actions: [
            IconButton(
              onPressed: () =>
                  ref.read(jobsControllerProvider.notifier).load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: jobs.isEmpty
              ? const Text('No jobs found.')
              : SizedBox(
                  height: MediaQuery.of(context).size.height - 220,
                  child: ListView.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
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
        );
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
    return ListTile(
      title: Text('${job.type} • ${job.status}'),
      subtitle: Text('Run at: $runAt'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: onCancel,
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
