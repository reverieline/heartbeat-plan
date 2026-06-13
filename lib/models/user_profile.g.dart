// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  age: (json['age'] as num).toInt(),
  weightKg: (json['weight_kg'] as num).toDouble(),
  sex: json['sex'] as String,
  restingHr: (json['resting_hr'] as num).toInt(),
  maxHr: (json['max_hr'] as num).toInt(),
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'age': instance.age,
      'weight_kg': instance.weightKg,
      'sex': instance.sex,
      'resting_hr': instance.restingHr,
      'max_hr': instance.maxHr,
    };
