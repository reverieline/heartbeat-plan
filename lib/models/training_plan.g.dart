// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StageTarget _$StageTargetFromJson(Map<String, dynamic> json) => StageTarget(
  mode: $enumDecode(_$TargetModeEnumMap, json['mode']),
  minBpm: (json['min_bpm'] as num?)?.toInt(),
  maxBpm: (json['max_bpm'] as num?)?.toInt(),
);

Map<String, dynamic> _$StageTargetToJson(StageTarget instance) =>
    <String, dynamic>{
      'mode': _$TargetModeEnumMap[instance.mode]!,
      'min_bpm': instance.minBpm,
      'max_bpm': instance.maxBpm,
    };

const _$TargetModeEnumMap = {
  TargetMode.none: 'none',
  TargetMode.min: 'min',
  TargetMode.max: 'max',
  TargetMode.range: 'range',
};

TrainingStage _$TrainingStageFromJson(Map<String, dynamic> json) =>
    TrainingStage(
      name: json['name'] as String,
      durationMinutes: (json['duration_minutes'] as num).toDouble(),
      target: StageTarget.fromJson(json['target'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TrainingStageToJson(TrainingStage instance) =>
    <String, dynamic>{
      'name': instance.name,
      'duration_minutes': instance.durationMinutes,
      'target': instance.target,
    };
