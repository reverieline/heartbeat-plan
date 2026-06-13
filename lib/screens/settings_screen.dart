import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    setState(() {
      _sex = p.sex;
      _ttsEnabled = config.ttsEnabled;
      _loaded = true;
    });
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
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('User Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _field('Age', _ageCtrl, TextInputType.number),
                _field('Weight (kg)', _weightCtrl, const TextInputType.numberWithOptions(decimal: true)),
                _field('Resting HR', _restHrCtrl, TextInputType.number),
                _field('Max HR', _maxHrCtrl, TextInputType.number),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(labelText: 'Sex', border: OutlineInputBorder()),
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
                  title: const Text('Text-to-Speech Coaching'),
                  value: _ttsEnabled,
                  onChanged: (v) => setState(() => _ttsEnabled = v),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
