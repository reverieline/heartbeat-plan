import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

const _kDeviceAddress = 'device_address';
const _kDeviceName = 'device_name';
const _kSelectedPlan = 'selected_plan';
const _kBeepCooldown = 'beep_cooldown_seconds';
const _kTtsEnabled = 'tts_enabled';
const _kUserProfile = 'user_profile';

class ConfigService {
  final SharedPreferences _prefs;

  ConfigService(this._prefs);

  static Future<ConfigService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ConfigService(prefs);
  }

  String? get savedDeviceAddress => _prefs.getString(_kDeviceAddress);
  String? get savedDeviceName => _prefs.getString(_kDeviceName);
  String get selectedPlan => _prefs.getString(_kSelectedPlan) ?? 'default';
  int get beepCooldownSeconds => _prefs.getInt(_kBeepCooldown) ?? 20;
  bool get ttsEnabled => _prefs.getBool(_kTtsEnabled) ?? true;

  Future<void> saveDevice(String address, String name) async {
    await _prefs.setString(_kDeviceAddress, address);
    await _prefs.setString(_kDeviceName, name);
  }

  Future<void> saveSelectedPlan(String planName) async {
    await _prefs.setString(_kSelectedPlan, planName);
  }

  Future<void> setBeepCooldown(int seconds) async {
    await _prefs.setInt(_kBeepCooldown, seconds);
  }

  Future<void> setTtsEnabled(bool enabled) async {
    await _prefs.setBool(_kTtsEnabled, enabled);
  }

  UserProfile get userProfile {
    final raw = _prefs.getString(_kUserProfile);
    if (raw == null) return UserProfile.defaults();
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _prefs.setString(_kUserProfile, jsonEncode(profile.toJson()));
  }

  bool get isConfigured => savedDeviceAddress != null;
}
