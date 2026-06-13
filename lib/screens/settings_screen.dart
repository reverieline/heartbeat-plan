import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/app_providers.dart';
import '../models/user_profile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _restHrCtrl = TextEditingController();
  final _maxHrCtrl = TextEditingController();
  String _sex = 'male';

  bool _ttsEnabled = true;
  bool _beepsEnabled = true;
  double _ttsSpeed = 0.5;
  double _ttsPitch = 1.0;
  String? _ttsVoiceName;
  String? _ttsVoiceLocale;
  List<Map<String, String>> _availableVoices = [];

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await ref.read(configProvider.future);
    final p = config.userProfile;
    _ageCtrl.text = p.age.toString();
    _weightCtrl.text = p.weightKg.toString();
    _restHrCtrl.text = p.restingHr.toString();
    _maxHrCtrl.text = p.maxHr.toString();

    final voices = await _loadVoices();

    setState(() {
      _sex = p.sex;
      _ttsEnabled = config.ttsEnabled;
      _beepsEnabled = config.beepsEnabled;
      _ttsSpeed = config.ttsSpeed;
      _ttsPitch = config.ttsPitch;
      _ttsVoiceName = config.ttsVoiceName;
      _ttsVoiceLocale = config.ttsVoiceLocale;
      _availableVoices = voices;
      _loaded = true;
    });
  }

  Future<List<Map<String, String>>> _loadVoices() async {
    try {
      final tts = FlutterTts();
      final raw = await tts.getVoices;
      if (raw == null) return [];
      final all = (raw as List)
          .whereType<Map>()
          .map((v) => {
                'name': v['name']?.toString() ?? '',
                'locale': v['locale']?.toString() ?? '',
              })
          .where((v) => v['name']!.isNotEmpty)
          .toList();
      final english = all.where((v) => v['locale']!.startsWith('en')).toList();
      return english.isNotEmpty ? english : all;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final config = await ref.read(configProvider.future);
    final profile = UserProfile(
      age: int.tryParse(_ageCtrl.text) ?? 30,
      weightKg: double.tryParse(_weightCtrl.text) ?? 70.0,
      sex: _sex,
      restingHr: int.tryParse(_restHrCtrl.text) ?? 60,
      maxHr: int.tryParse(_maxHrCtrl.text) ?? 190,
    );
    await config.saveUserProfile(profile);
    await config.setTtsEnabled(_ttsEnabled);
    await config.setBeepsEnabled(_beepsEnabled);
    await config.setTtsSpeed(_ttsSpeed);
    await config.setTtsPitch(_ttsPitch);
    await config.setTtsVoice(_ttsVoiceName, _ttsVoiceLocale);
    ref.invalidate(configProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _restHrCtrl.dispose();
    _maxHrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        top: false,
        child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('User Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _field('Age', _ageCtrl, TextInputType.number),
                _field('Weight (kg)', _weightCtrl,
                    const TextInputType.numberWithOptions(decimal: true)),
                _field('Resting HR', _restHrCtrl, TextInputType.number),
                _field('Max HR', _maxHrCtrl, TextInputType.number),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(
                      labelText: 'Sex', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _sex = v ?? 'male'),
                ),
                const SizedBox(height: 16),
                Text('Audio', style: Theme.of(context).textTheme.titleLarge),
                SwitchListTile(
                  title: const Text('Sound Beeps'),
                  subtitle: const Text('Ascending/descending tones for pace cues'),
                  value: _beepsEnabled,
                  onChanged: (v) => setState(() => _beepsEnabled = v),
                ),
                SwitchListTile(
                  title: const Text('Text-to-Speech Coaching'),
                  subtitle: const Text('Voice announcements for stages and cues'),
                  value: _ttsEnabled,
                  onChanged: (v) => setState(() => _ttsEnabled = v),
                ),
                if (_ttsEnabled) ...[
                  const SizedBox(height: 8),
                  _VoiceDropdown(
                    voices: _availableVoices,
                    selectedName: _ttsVoiceName,
                    onChanged: (name, locale) => setState(() {
                      _ttsVoiceName = name;
                      _ttsVoiceLocale = locale;
                    }),
                  ),
                  const SizedBox(height: 8),
                  _SliderRow(
                    label: 'Speech Speed',
                    value: _ttsSpeed,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    displayValue: _ttsSpeed.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _ttsSpeed = v),
                  ),
                  _SliderRow(
                    label: 'Pitch',
                    value: _ttsPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    displayValue: _ttsPitch.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _ttsPitch = v),
                  ),
                ],
              ],
            ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _VoiceDropdown extends StatelessWidget {
  final List<Map<String, String>> voices;
  final String? selectedName;
  final void Function(String? name, String? locale) onChanged;

  const _VoiceDropdown({
    required this.voices,
    required this.selectedName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: null, child: Text('System default')),
      ...voices.map((v) => DropdownMenuItem(
            value: v['name'],
            child: Text(v['name']!, overflow: TextOverflow.ellipsis),
          )),
    ];

    final validValue =
        voices.any((v) => v['name'] == selectedName) ? selectedName : null;

    return DropdownButtonFormField<String>(
      initialValue: validValue,
      decoration:
          const InputDecoration(labelText: 'Voice', border: OutlineInputBorder()),
      isExpanded: true,
      items: items,
      onChanged: (name) {
        final locale = voices
            .firstWhere((v) => v['name'] == name,
                orElse: () => {'name': '', 'locale': ''})['locale'];
        onChanged(name, locale);
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(displayValue,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
