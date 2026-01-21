class Job {
  Job({
    required this.id,
    required this.type,
    required this.status,
    required this.runAt,
    required this.lastError,
    this.creatorName,
  });

  final String id;
  final String type;
  final String status;
  final DateTime? runAt;
  final String? lastError;
  final String? creatorName;

  factory Job.fromMap(Map<String, dynamic> map) {
    // Handle nested creator data from join
    String? creatorName;
    if (map['creators'] != null && map['creators'] is Map) {
      creatorName = map['creators']['display_name']?.toString();
    }

    return Job(
      id: map['id']?.toString() ?? '',
      type: map['job_type']?.toString() ?? map['type']?.toString() ?? 'unknown',
      status: map['status']?.toString() ?? 'unknown',
      runAt: DateTime.tryParse(
        map['run_at']?.toString() ?? map['created_at']?.toString() ?? '',
      ),
      lastError: map['last_error']?.toString(),
      creatorName: creatorName,
    );
  }
}
