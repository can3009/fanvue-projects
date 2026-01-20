class DashboardMetrics {
  DashboardMetrics({
    required this.creators,
    required this.queuedJobs,
    required this.recentErrors,
    required this.recentMessages,
  });

  final int creators;
  final int queuedJobs;
  final List<Map<String, dynamic>> recentErrors;
  final List<Map<String, dynamic>> recentMessages;
}
