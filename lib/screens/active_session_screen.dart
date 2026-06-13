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
  BleService? _ble;
  late TrainingService _trainer;
  late AudioService _audio;

  int _bpm = 0;
  bool _connected = false;
  bool _initializing = true;
  String? _error;
  int _elapsed = 0;
  SessionState _sessionState = SessionState.idle;
  bool _ttsEnabled = true;
  bool _beepsEnabled = true;

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
        setState(() => _sessionState = state);
        if (state == SessionState.finished) _onFinish();
      });

      setState(() {
        _connected = true;
        _initializing = false;
        _sessionState = SessionState.running;
        _ttsEnabled = _audio.ttsEnabled;
        _beepsEnabled = _audio.beepsEnabled;
      });
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

  Future<void> _showStopDialog() async {
    final wasRunning = _trainer.state == SessionState.running;
    if (wasRunning) await _trainer.pause();

    if (!mounted) return;
    final stop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Training?'),
        content: const Text('This will end your current session and return to the home screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Stop Training'),
          ),
        ],
      ),
    ) ?? false;

    if (stop) {
      if (mounted) Navigator.pop(context);
    } else if (wasRunning) {
      _trainer.resume();
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
    if (!_initializing) {
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
    final isPaused = _sessionState == SessionState.paused;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showStopDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_connected ? 'Session Active' : 'Session (Disconnected)'),
          backgroundColor: _connected ? null : Colors.red.shade900,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Stop training',
            onPressed: _showStopDialog,
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_formatTime(_elapsed),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 48)),
              const SizedBox(height: 32),
              _BpmDisplay(bpm: _bpm, target: stage.target, dimmed: isPaused),
              const SizedBox(height: 32),
              _StageCard(
                stage: stage,
                elapsed: _trainer.stageElapsedSeconds,
                progress: stageProgress,
                target: stage.target,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: isPaused
                    ? FilledButton.icon(
                        onPressed: () => setState(() => _trainer.resume()),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _trainer.pause(),
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(_beepsEnabled ? Icons.music_note : Icons.music_off),
                    tooltip: _beepsEnabled ? 'Mute beeps' : 'Unmute beeps',
                    onPressed: () => setState(() {
                      _beepsEnabled = !_beepsEnabled;
                      _audio.beepsEnabled = _beepsEnabled;
                    }),
                  ),
                  IconButton(
                    icon: Icon(_ttsEnabled ? Icons.record_voice_over : Icons.voice_over_off),
                    tooltip: _ttsEnabled ? 'Mute voice' : 'Unmute voice',
                    onPressed: () => setState(() {
                      _ttsEnabled = !_ttsEnabled;
                      _audio.ttsEnabled = _ttsEnabled;
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _BpmDisplay extends StatelessWidget {
  final int bpm;
  final StageTarget target;
  final bool dimmed;

  const _BpmDisplay({required this.bpm, required this.target, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (target.isAbove(bpm)) color = Colors.orange;
    if (target.isBelow(bpm)) color = Colors.blue;
    if (dimmed) color = color.withValues(alpha: 0.4);

    return Text('$bpm', style: TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: color));
  }
}

class _StageCard extends StatelessWidget {
  final TrainingStage stage;
  final int elapsed;
  final double progress;
  final StageTarget target;

  const _StageCard({required this.stage, required this.elapsed, required this.progress, required this.target});

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
            const SizedBox(height: 4),
            Text(target.label, style: Theme.of(context).textTheme.bodyMedium),
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
