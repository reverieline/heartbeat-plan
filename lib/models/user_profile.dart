import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
class UserProfile {
  final int age;
  @JsonKey(name: 'weight_kg') final double weightKg;
  final String sex;
  @JsonKey(name: 'resting_hr') final int restingHr;
  @JsonKey(name: 'max_hr') final int maxHr;

  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.sex,
    required this.restingHr,
    required this.maxHr,
  });

  factory UserProfile.defaults() => const UserProfile(
        age: 30,
        weightKg: 70.0,
        sex: 'male',
        restingHr: 60,
        maxHr: 190,
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
