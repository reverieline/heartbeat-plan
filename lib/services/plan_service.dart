import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/training_plan.dart';

class PlanService {
  static Future<Directory> _plansDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/plans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<String>> listPlanNames() async {
    final dir = await _plansDir();
    final files = await dir.list().where((e) => e.path.endsWith('.json')).toList();
    final names = files.map((e) => e.path.split('/').last.replaceAll('.json', '')).toList();
    names.sort();
    if (!names.contains('default')) {
      await savePlan('default', _defaultPlan());
      names.insert(0, 'default');
    }
    return names;
  }

  static Future<List<TrainingStage>> loadPlan(String name) async {
    final dir = await _plansDir();
    final file = File('${dir.path}/$name.json');
    if (!await file.exists()) {
      if (name == 'default') {
        final plan = _defaultPlan();
        await savePlan('default', plan);
        return plan;
      }
      throw Exception('Plan not found: $name');
    }
    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => TrainingStage.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> savePlan(String name, List<TrainingStage> stages) async {
    final dir = await _plansDir();
    final file = File('${dir.path}/$name.json');
    await file.writeAsString(jsonEncode(stages.map((s) => s.toJson()).toList()));
  }

  static Future<void> deletePlan(String name) async {
    if (name == 'default') return;
    final dir = await _plansDir();
    final file = File('${dir.path}/$name.json');
    if (await file.exists()) await file.delete();
  }

  static Future<bool> planExists(String name) async {
    final dir = await _plansDir();
    return File('${dir.path}/$name.json').exists();
  }

  static List<TrainingStage> _defaultPlan() => [
        const TrainingStage(
          name: 'Warmup',
          durationMinutes: 10,
          target: StageTarget(mode: TargetMode.range, minBpm: 100, maxBpm: 130),
        ),
        const TrainingStage(
          name: 'Fat Burning',
          durationMinutes: 20,
          target: StageTarget(mode: TargetMode.range, minBpm: 132, maxBpm: 144),
        ),
        const TrainingStage(
          name: 'Cooldown',
          durationMinutes: 10,
          target: StageTarget(mode: TargetMode.max, maxBpm: 120),
        ),
      ];
}
