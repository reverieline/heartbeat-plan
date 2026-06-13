import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../providers/ble_provider.dart';
import '../services/ble_service.dart';
import '../services/training_service.dart';
import '../services/audio_service.dart';
import '../services/log_service.dart';
import '../models/session_log.dart';
import '../models/training_plan.dart';
import 'summary_screen.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  // BleService is obtained from the global provider — not owned here.
  BleService? _ble;
  late TrainingService _trainer;
  late AudioService _audio;

  int _bpm = 0;
  bool _connected = false;
  bool _initializing = true;
  String? _error;
  int _elapsed = 0;

  StreamSubscription<HeartRateData>? _hrSub;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<int>? _tickSub;
  StreamSubscription<SessionState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final config = await ref.read(configProvider.future);
      final planName = ref.read(selectedPlanNameProvider);
      final stages = await ref.read(planProvider(planName).future);
      _audio = AudioService(
        ttsEnabled: config.ttsEnabled,
        beepsEnabled: config.beepsEnabled,
        ttsVoice: config.ttsVoiceName != null
            ? {'name': config.ttsVoiceName!, 'locale': config.ttsVoiceLocale ?? ''}
            : null,
        ttsSpeed: config.ttsSpeed,
        ttsPitch: config.ttsPitch,
      );
      _trainer = TrainingService(
        stages: stages,
        audio: _audio,
        beepCooldownSeconds: config.beepCooldownSeconds,
      );

      // Reuse the connection already established (or being established) by
      // the global provider — avoids a second concurrent scan.
      await ref.read(bleConnectionProvider.notifier)
          .waitForConnection(timeout: const Duration(seconds: 40));

      _ble = ref.read(bleConnectionProvider.notifier).service!;
      _trainer.start();

      _hrSub = _ble!.hrStream.listen((data) {
        setState(() => _bpm = data.bpm);
        _trainer.handleBpm(data.bpm);
      });

      _connSub = _ble!.connectionStream.listen((connected) {
        setState(() => _connected = connected);
        if (!connected) _trainer.handleDisconnect();
        if (connected) _trainer.handleReconnect(null);
      });

      _tickSub = _trainer.tickStream.listen((t) => setState(() => _elapsed = t));

      _stateSub = _trainer.stateStream.listen((state) {
        if (state == SessionState.finished) _onFinish();
      });

      setState(() { _connected = true; _initializing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _initializing = false; });
    }
  }

  Future<void> _onFinish() async {
    final config = await ref.read(configProvider.future);
    final log = SessionLog(
      startTime: DateTime.now().subtract(Duration(seconds: _elapsed)),
      deviceName: config.savedDeviceName ?? 'HR Monitor',
      deviceAddress: config.savedDeviceAddress ?? '',
      events: _trainer.logEvents.toList(),
    );
    await LogService.saveLog(log);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SummaryScreen(log: log, profile: config.userProfile)),
      );
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    _connSub?.cancel();
    _tickSub?.cancel();
    _stateSub?.cancel();
    // The BleService is owned by bleConnectionProvider — do not disconnect or
    // dispose it here. The connection persists for the HomeScreen HR indicator.
    if (_initializing == false) {
      _trainer.dispose();
      _audio.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Connecting...')],
      )));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          ],
        )),
      );
    }

    final stage = _trainer.currentStage;
    final stageProgress = _trainer.stageElapsedSeconds / stage.durationSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Text(_connected ? 'Session Active' : 'Session (Disconnected)'),
        backgroundColor: _connected ? null : Colors.red.shade900,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Total: ${_formatTime(_elapsed)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 32),
            _BpmDisplay(bpm: _bpm, target: stage.target),
            const SizedBox(height: 32),
            _StageCard(
              stage: stage,
              elapsed: _trainer.stageElapsedSeconds,
              progress: stageProgress,
            ),
          ],
        ),
      ),
    );
  }
}

class _BpmDisplay extends StatelessWidget {
  final int bpm;
  final StageTarget target;

  const _BpmDisplay({required this.bpm, required this.target});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (target.isAbove(bpm)) color = Colors.orange;
    if (target.isBelow(bpm)) color = Colors.blue;

    return Column(
      children: [
        Text('$bpm', style: TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: color)),
        Text('bpm', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(target.label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  final TrainingStage stage;
  final int elapsed;
  final double progress;

  const _StageCard({required this.stage, required this.elapsed, required this.progress});

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(stage.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 8),
            const SizedBox(height: 8),
            Text('${_fmt(elapsed)} / ${_fmt(stage.durationSeconds)}',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
