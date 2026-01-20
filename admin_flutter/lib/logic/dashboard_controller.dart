import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/dashboard_metrics.dart';
import '../data/repositories/dashboard_repository.dart';

class DashboardController extends AsyncNotifier<DashboardMetrics> {
  @override
  Future<DashboardMetrics> build() {
    return ref.watch(dashboardRepositoryProvider).loadMetrics();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.watch(dashboardRepositoryProvider).loadMetrics(),
    );
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardMetrics>(
  DashboardController.new,
);
