import '../models/user_profile.dart';

class HrZone {
  final String name;
  final double? lowerBpm;
  final double? upperBpm;

  const HrZone({required this.name, this.lowerBpm, this.upperBpm});

  bool contains(int bpm) {
    final lo = lowerBpm == null || bpm >= lowerBpm!;
    final hi = upperBpm == null || bpm < upperBpm!;
    return lo && hi;
  }

  String get description {
    if (lowerBpm == null && upperBpm != null) return '< ${upperBpm!.ceil()} bpm';
    if (lowerBpm != null && upperBpm != null) {
      return '${lowerBpm!.ceil()}–${upperBpm!.ceil() - 1} bpm';
    }
    if (lowerBpm != null) return '≥ ${lowerBpm!.ceil()} bpm';
    return 'all bpm';
  }
}

class ZoneSummary {
  final HrZone zone;
  final Duration duration;

  const ZoneSummary({required this.zone, required this.duration});
}

class TrainingSummary {
  final Duration totalDuration;
  final Duration trackedDuration;
  final List<ZoneSummary> zoneSummaries;
  final double caloriesBurned;
  final String zoneMethod;
  final String calorieMethod;

  const TrainingSummary({
    required this.totalDuration,
    required this.trackedDuration,
    required this.zoneSummaries,
    required this.caloriesBurned,
    required this.zoneMethod,
    required this.calorieMethod,
  });
}

List<HrZone> buildZones(UserProfile profile) {
  final restHr = profile.restingHr;
  final maxHr = profile.maxHr;
  final hrReserve = maxHr - restHr;

  double karvonen(double pct) => restHr + hrReserve * pct;

  return [
    HrZone(name: 'Zone 1 (Rest)',    upperBpm: karvonen(0.50)),
    HrZone(name: 'Zone 2 (Fat burn)', lowerBpm: karvonen(0.50), upperBpm: karvonen(0.60)),
    HrZone(name: 'Zone 3 (Aerobic)', lowerBpm: karvonen(0.60), upperBpm: karvonen(0.70)),
    HrZone(name: 'Zone 4 (Anaerobic)', lowerBpm: karvonen(0.70), upperBpm: karvonen(0.85)),
    HrZone(name: 'Zone 5 (Max)',     lowerBpm: karvonen(0.85)),
  ];
}

double estimateCalories({
  required List<(DateTime, int)> bpmSamples,
  required UserProfile profile,
}) {
  if (bpmSamples.length < 2) return 0.0;
  double totalKcal = 0.0;
  for (int i = 1; i < bpmSamples.length; i++) {
    final dt = bpmSamples[i].$1.difference(bpmSamples[i - 1].$1).inSeconds;
    if (dt <= 0 || dt > 300) continue;
    final avgBpm = (bpmSamples[i].$2 + bpmSamples[i - 1].$2) / 2.0;
    final durationMin = dt / 60.0;
    final kcalPerMin = profile.sex == 'male'
        ? (-55.0969 + (0.6309 * avgBpm) + (0.1988 * profile.weightKg) + (0.2017 * profile.age)) / 4.184
        : (-20.4022 + (0.4472 * avgBpm) - (0.1263 * profile.weightKg) + (0.074 * profile.age)) / 4.184;
    totalKcal += kcalPerMin * durationMin;
  }
  return totalKcal.clamp(0.0, double.infinity);
}
