import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/app_providers.dart';
import '../providers/ble_provider.dart';
import '../services/ble_service.dart';
import '../services/training_service.dart';
import '../services/audio_service.dart';
import '../services/log_service.dart';
import '../services/foreground_notification_service.dart';
import '../services/media_session_service.dart';
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
  bool _keepDisplayOn = false;

  StreamSubscription<HeartRateData>? _hrSub;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<int>? _tickSub;
  StreamSubscription<SessionState>? _stateSub;
  void Function(Object)? _notifCallback;

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
      final totalDuration = stages.fold<int>(0, (sum, s) => sum + s.durationSeconds);
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

      _tickSub = _trainer.tickStream.listen((t) {
        setState(() => _elapsed = t);
        final stage = _trainer.currentStage.name;
        final paused = _sessionState == SessionState.paused;
        ForegroundNotificationService.update(
          stageName: stage,
          bpm: _bpm,
          elapsedSeconds: t,
          isPaused: paused,
        );
        MediaSessionService.update(stageName: stage, bpm: _bpm, elapsedSeconds: t, isPaused: paused);
      });

      _stateSub = _trainer.stateStream.listen((state) {
        setState(() => _sessionState = state);
        if (state == SessionState.finished) {
          _onFinish();
          return;
        }
        if (state == SessionState.paused || state == SessionState.running) {
          final stage = _trainer.currentStage.name;
          final paused = state == SessionState.paused;
          ForegroundNotificationService.update(
            stageName: stage,
            bpm: _bpm,
            elapsedSeconds: _elapsed,
            isPaused: paused,
          );
          MediaSessionService.update(stageName: stage, bpm: _bpm, elapsedSeconds: _elapsed, isPaused: paused);
        }
      });

      // Start foreground service notification.
      await ForegroundNotificationService.requestPermission();
      await ForegroundNotificationService.start(
        stageName: _trainer.currentStage.name,
        bpm: 0,
        elapsedSeconds: 0,
      );

      // Listen for Pause/Resume and Stop button presses from the notification.
      _notifCallback = (data) {
        if (!mounted) return;
        if (data == 'pause_resume') {
          if (_trainer.state == SessionState.paused) {
            setState(() => _trainer.resume());
          } else {
            _trainer.pause();
          }
        } else if (data == 'stop') {
          // Immediate stop from notification — no confirmation dialog.
          Navigator.pop(context);
        }
      };
      FlutterForegroundTask.addTaskDataCallback(_notifCallback!);

      // Start Android MediaSession so controls appear in the lock screen media area.
      MediaSessionService.init(
        onPlay: () {
          if (mounted && _trainer.state == SessionState.paused) {
            setState(() => _trainer.resume());
          }
        },
        onPause: () {
          if (mounted) _trainer.pause();
        },
        onStop: () {
          if (mounted) Navigator.pop(context);
        },
      );
      await MediaSessionService.start(
        stageName: _trainer.currentStage.name,
        bpm: 0,
        totalDurationSeconds: totalDuration,
      );

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
    await ForegroundNotificationService.stop();
    await MediaSessionService.stop();
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

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    _connSub?.cancel();
    _tickSub?.cancel();
    _stateSub?.cancel();
    if (_notifCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_notifCallback!);
    }
    ForegroundNotificationService.stop();
    MediaSessionService.stop();
    WakelockPlus.disable();
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
    final totalDuration =
        _trainer.stages.fold<int>(0, (sum, s) => sum + s.durationSeconds);

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
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _TrainingProgressRing(
                    stages: _trainer.stages,
                    totalElapsedSeconds: _trainer.totalElapsedSeconds,
                    totalDurationSeconds: totalDuration,
                    currentStageIndex: _trainer.currentStageIndex,
                    dimmed: isPaused,
                    child: _BpmDisplay(
                        bpm: _bpm, target: stage.target, dimmed: isPaused),
                  ),
                ),
              ),
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
                    onPressed: () {
                      setState(() {
                        _beepsEnabled = !_beepsEnabled;
                        _audio.beepsEnabled = _beepsEnabled;
                      });
                      _showToast(_beepsEnabled ? 'Beeps on' : 'Beeps off');
                    },
                  ),
                  IconButton(
                    icon: Icon(_ttsEnabled ? Icons.record_voice_over : Icons.voice_over_off),
                    tooltip: _ttsEnabled ? 'Mute voice' : 'Unmute voice',
                    onPressed: () {
                      setState(() {
                        _ttsEnabled = !_ttsEnabled;
                        _audio.ttsEnabled = _ttsEnabled;
                      });
                      _showToast(_ttsEnabled ? 'Voice on' : 'Voice off');
                    },
                  ),
                  IconButton(
                    icon: Icon(_keepDisplayOn ? Icons.visibility : Icons.visibility_off),
                    tooltip: _keepDisplayOn ? 'Allow screen lock' : 'Keep screen on',
                    onPressed: () async {
                      setState(() => _keepDisplayOn = !_keepDisplayOn);
                      if (_keepDisplayOn) {
                        await WakelockPlus.enable();
                        _showToast('Screen will stay on');
                      } else {
                        await WakelockPlus.disable();
                        _showToast('Screen lock enabled');
                      }
                    },
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$bpm',
            style: TextStyle(
                fontSize: 72, fontWeight: FontWeight.bold, color: color, height: 1.0)),
        Text('BPM',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: color.withValues(alpha: dimmed ? 0.4 : 0.7))),
      ],
    );
  }
}

/// A circular progress ring drawn around the heart-rate display. The ring
/// represents the whole training session: the filled arc is overall progress,
/// segment gaps mark the boundaries between stages, and each stage is labeled
/// just outside the ring at its arc midpoint (anchored radially so labels
/// never overlap the indicator).
class _TrainingProgressRing extends StatelessWidget {
  final List<TrainingStage> stages;
  final int totalElapsedSeconds;
  final int totalDurationSeconds;
  final int currentStageIndex;
  final bool dimmed;
  final Widget child;

  const _TrainingProgressRing({
    required this.stages,
    required this.totalElapsedSeconds,
    required this.totalDurationSeconds,
    required this.currentStageIndex,
    required this.dimmed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alpha = dimmed ? 0.4 : 1.0;
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          stages: stages,
          totalElapsedSeconds: totalElapsedSeconds,
          totalDurationSeconds: totalDurationSeconds,
          currentStageIndex: currentStageIndex,
          trackColor: scheme.surfaceContainerHighest.withValues(alpha: alpha),
          progressColor: scheme.primary.withValues(alpha: alpha),
          gapColor: Theme.of(context).scaffoldBackgroundColor,
          labelColor: scheme.onSurfaceVariant.withValues(alpha: 0.7 * alpha),
          activeLabelColor: scheme.primary.withValues(alpha: alpha),
          textDirection: Directionality.of(context),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final List<TrainingStage> stages;
  final int totalElapsedSeconds;
  final int totalDurationSeconds;
  final int currentStageIndex;
  final Color trackColor;
  final Color progressColor;
  final Color gapColor;
  final Color labelColor;
  final Color activeLabelColor;
  final TextDirection textDirection;

  static const double _stroke = 16;
  static const double _tickOut = 6;
  static const double _labelGap = 8;
  static const double _startAngle = -math.pi / 2; // 12 o'clock

  _ProgressRingPainter({
    required this.stages,
    required this.totalElapsedSeconds,
    required this.totalDurationSeconds,
    required this.currentStageIndex,
    required this.trackColor,
    required this.progressColor,
    required this.gapColor,
    required this.labelColor,
    required this.activeLabelColor,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDurationSeconds <= 0 || stages.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Reserve an outer band of the radius for stage labels so they sit fully
    // outside the ring without clipping the widget edges.
    final maxRadius = size.shortestSide / 2;
    final labelBand = size.shortestSide * 0.20;
    final radius = maxRadius - labelBand;
    if (radius <= _stroke) return;

    Offset polar(double r, double angle) =>
        center + Offset(math.cos(angle) * r, math.sin(angle) * r);

    // Track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc.
    final fraction =
        (totalElapsedSeconds / totalDurationSeconds).clamp(0.0, 1.0);
    if (fraction > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = progressColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle,
        2 * math.pi * fraction,
        false,
        progressPaint,
      );
    }

    // Cumulative stage boundaries (as fractions of the whole session).
    final boundaries = <double>[];
    int acc = 0;
    for (final s in stages) {
      acc += s.durationSeconds;
      boundaries.add(acc / totalDurationSeconds);
    }

    // Segment separators: a short gap cut across the ring at each internal
    // boundary, marking where one stage ends and the next begins.
    final gapPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = gapColor;
    for (var i = 0; i < boundaries.length - 1; i++) {
      final angle = _startAngle + 2 * math.pi * boundaries[i];
      canvas.drawLine(
        polar(radius - _stroke / 2 - 0.5, angle),
        polar(radius + _stroke / 2 + 0.5, angle),
        gapPaint,
      );
    }

    // Stage labels at each stage's arc midpoint, anchored radially.
    final labelRadius = radius + _stroke / 2 + _tickOut + _labelGap;
    double prevFraction = 0;
    for (var i = 0; i < stages.length; i++) {
      final midFraction = (prevFraction + boundaries[i]) / 2;
      prevFraction = boundaries[i];
      final angle = _startAngle + 2 * math.pi * midFraction;
      final anchor = polar(labelRadius, angle);
      final isActive = i == currentStageIndex;

      final tp = TextPainter(
        text: TextSpan(
          text: stages[i].name,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.1,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? activeLabelColor : labelColor,
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: labelBand * 1.7);

      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      double dx;
      if (cosA > 0.3) {
        dx = 0; // right side: grow rightward from anchor
      } else if (cosA < -0.3) {
        dx = -tp.width; // left side: grow leftward
      } else {
        dx = -tp.width / 2; // top/bottom: centered
      }
      double dy;
      if (sinA < -0.3) {
        dy = -tp.height; // top: sit above the anchor
      } else if (sinA > 0.3) {
        dy = 0; // bottom: sit below the anchor
      } else {
        dy = -tp.height / 2; // sides: vertically centered
      }
      tp.paint(canvas, anchor + Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) {
    return old.totalElapsedSeconds != totalElapsedSeconds ||
        old.currentStageIndex != currentStageIndex ||
        old.totalDurationSeconds != totalDurationSeconds ||
        old.stages != stages ||
        old.trackColor != trackColor ||
        old.progressColor != progressColor;
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
