import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobsWorkerUiState {
  const JobsWorkerUiState({
    required this.running,
    required this.lastResult,
    required this.lastError,
    required this.totalCompleted,
    required this.totalFailed,
    required this.totalSkipped,
  });

  final bool running;
  final Map<String, dynamic>? lastResult;
  final String? lastError;

  final int totalCompleted;
  final int totalFailed;
  final int totalSkipped;

  JobsWorkerUiState copyWith({
    bool? running,
    Map<String, dynamic>? lastResult,
    String? lastError,
    int? totalCompleted,
    int? totalFailed,
    int? totalSkipped,
    bool clearError = false,
  }) {
    return JobsWorkerUiState(
      running: running ?? this.running,
      lastResult: lastResult ?? this.lastResult,
      lastError: clearError ? null : (lastError ?? this.lastError),
      totalCompleted: totalCompleted ?? this.totalCompleted,
      totalFailed: totalFailed ?? this.totalFailed,
      totalSkipped: totalSkipped ?? this.totalSkipped,
    );
  }
}

class JobsWorkerController extends StateNotifier<JobsWorkerUiState> {
  JobsWorkerController(this._client)
    : super(
        const JobsWorkerUiState(
          running: false,
          lastResult: null,
          lastError: null,
          totalCompleted: 0,
          totalFailed: 0,
          totalSkipped: 0,
        ),
      );

  final SupabaseClient _client;
  Timer? _timer;
  bool _inFlight = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    if (state.running) return;

    state = state.copyWith(running: true, clearError: true);

    // Run first tick in background (fire and forget)
    _tick();

    // Schedule periodic
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _tick();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _inFlight = false;
    state = state.copyWith(running: false);
  }

  Future<void> _tick() async {
    if (!state.running) return;
    if (_inFlight) return;
    _inFlight = true;

    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        throw Exception("Not logged in (missing Supabase session).");
      }

      // invoke jobs-worker
      final res = await _client.functions
          .invoke('jobs-worker', body: {"batchSize": 20, "maxMillis": 25000})
          .timeout(const Duration(seconds: 30));

      if (res.status != 200) {
        throw Exception("jobs-worker failed: ${res.status} ${res.data}");
      }

      final data = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{"raw": res.data};

      int completed = 0;
      int failed = 0;
      int skipped = 0;

      // Check for single job response (processed: true)
      if (data["processed"] == true) {
        if (data["skipped"] == true) {
          skipped = 1;
        } else {
          completed = 1;
        }
      }
      // Check for batch response or explicit counters
      else if (data.containsKey("completed")) {
        completed = (data["completed"] as num?)?.toInt() ?? 0;
        failed = (data["failed"] as num?)?.toInt() ?? 0;
        skipped = (data["skipped"] as num?)?.toInt() ?? 0;
      }

      state = state.copyWith(
        lastResult: data,
        totalCompleted: state.totalCompleted + completed,
        totalFailed: state.totalFailed + failed,
        totalSkipped: state.totalSkipped + skipped,
        clearError: true,
      );
    } catch (e) {
      // Fehler anzeigen, aber Loop weiterlaufen lassen (oder stop() wenn du willst)
      state = state.copyWith(lastError: e.toString());
    } finally {
      _inFlight = false;
    }
  }
}

final jobsWorkerControllerProvider =
    StateNotifierProvider<JobsWorkerController, JobsWorkerUiState>((ref) {
      return JobsWorkerController(Supabase.instance.client);
    });
