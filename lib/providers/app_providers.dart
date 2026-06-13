import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';
import '../services/plan_service.dart';
import '../models/training_plan.dart';

final configProvider = FutureProvider<ConfigService>((ref) async {
  return ConfigService.create();
});

final planListProvider = FutureProvider<List<String>>((ref) async {
  return PlanService.listPlanNames();
});

final selectedPlanNameProvider = StateProvider<String>((ref) {
  return 'default';
});

final planProvider = FutureProvider.family<List<TrainingStage>, String>((ref, name) async {
  return PlanService.loadPlan(name);
});
