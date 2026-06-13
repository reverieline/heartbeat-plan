import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

const _kDeviceAddress = 'device_address';
const _kDeviceName = 'device_name';
const _kSelectedPlan = 'selected_plan';
const _kBeepCooldown = 'beep_cooldown_seconds';
const _kTtsEnabled = 'tts_enabled';
const _kBeepsEnabled = 'beeps_enabled';
const _kTtsVoiceName = 'tts_voice_name';
const _kTtsVoiceLocale = 'tts_voice_locale';
const _kTtsSpeed = 'tts_speed';
const _kTtsPitch = 'tts_pitch';
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
  bool get beepsEnabled => _prefs.getBool(_kBeepsEnabled) ?? true;
  String? get ttsVoiceName => _prefs.getString(_kTtsVoiceName);
  String? get ttsVoiceLocale => _prefs.getString(_kTtsVoiceLocale);
  double get ttsSpeed => _prefs.getDouble(_kTtsSpeed) ?? 0.5;
  double get ttsPitch => _prefs.getDouble(_kTtsPitch) ?? 1.0;

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

  Future<void> setBeepsEnabled(bool enabled) async {
    await _prefs.setBool(_kBeepsEnabled, enabled);
  }

  Future<void> setTtsVoice(String? name, String? locale) async {
    if (name == null) {
      await _prefs.remove(_kTtsVoiceName);
      await _prefs.remove(_kTtsVoiceLocale);
    } else {
      await _prefs.setString(_kTtsVoiceName, name);
      await _prefs.setString(_kTtsVoiceLocale, locale ?? '');
    }
  }

  Future<void> setTtsSpeed(double speed) async {
    await _prefs.setDouble(_kTtsSpeed, speed);
  }

  Future<void> setTtsPitch(double pitch) async {
    await _prefs.setDouble(_kTtsPitch, pitch);
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
