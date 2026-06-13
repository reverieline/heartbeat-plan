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

class SelectedPlanNotifier extends Notifier<String> {
  @override
  String build() {
    _initFromConfig();
    return 'default';
  }

  Future<void> _initFromConfig() async {
    final config = await ref.read(configProvider.future);
    state = config.selectedPlan;
  }

  Future<void> select(String name) async {
    state = name;
    final config = await ref.read(configProvider.future);
    await config.saveSelectedPlan(name);
  }
}

final selectedPlanNameProvider = NotifierProvider<SelectedPlanNotifier, String>(
  SelectedPlanNotifier.new,
);

final planProvider = FutureProvider.family<List<TrainingStage>, String>((ref, name) async {
  return PlanService.loadPlan(name);
});
