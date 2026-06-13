import 'package:json_annotation/json_annotation.dart';

part 'training_plan.g.dart';

enum TargetMode { none, min, max, range }

@JsonSerializable()
class StageTarget {
  final TargetMode mode;
  @JsonKey(name: 'min_bpm') final int? minBpm;
  @JsonKey(name: 'max_bpm') final int? maxBpm;

  const StageTarget({required this.mode, this.minBpm, this.maxBpm});

  factory StageTarget.fromJson(Map<String, dynamic> json) => _$StageTargetFromJson(json);
  Map<String, dynamic> toJson() => _$StageTargetToJson(this);

  bool isAbove(int bpm) {
    if (mode == TargetMode.max && maxBpm != null) return bpm > maxBpm!;
    if (mode == TargetMode.range && maxBpm != null) return bpm > maxBpm!;
    return false;
  }

  bool isBelow(int bpm) {
    if (mode == TargetMode.min && minBpm != null) return bpm < minBpm!;
    if (mode == TargetMode.range && minBpm != null) return bpm < minBpm!;
    return false;
  }

  String get label {
    return switch (mode) {
      TargetMode.none => 'Free',
      TargetMode.min => '≥ $minBpm bpm',
      TargetMode.max => '≤ $maxBpm bpm',
      TargetMode.range => '$minBpm–$maxBpm bpm',
    };
  }
}

@JsonSerializable()
class TrainingStage {
  final String name;
  @JsonKey(name: 'duration_minutes') final double durationMinutes;
  final StageTarget target;

  const TrainingStage({
    required this.name,
    required this.durationMinutes,
    required this.target,
  });

  int get durationSeconds => (durationMinutes * 60).round().clamp(1, 999999);

  factory TrainingStage.fromJson(Map<String, dynamic> json) => _$TrainingStageFromJson(json);
  Map<String, dynamic> toJson() => _$TrainingStageToJson(this);
}
