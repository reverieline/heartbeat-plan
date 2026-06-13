import 'dart:async';
import '../models/training_plan.dart';
import '../models/session_log.dart';
import 'audio_service.dart';

enum SessionState { idle, running, paused, finished }

class TrainingService {
  final List<TrainingStage> stages;
  final AudioService audio;
  final int beepCooldownSeconds;

  int _stageIndex = 0;
  int _stageElapsedSeconds = 0;
  int _totalElapsedSeconds = 0;
  DateTime? _lastCueTime;
  SessionState _state = SessionState.idle;
  Timer? _ticker;
  final _log = <LogEvent>[];
  DateTime? _startTime;

  final _stateController = StreamController<SessionState>.broadcast();
  final _stageController = StreamController<int>.broadcast();
  final _tickController = StreamController<int>.broadcast();

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<int> get stageIndexStream => _stageController.stream;
  Stream<int> get tickStream => _tickController.stream;

  SessionState get state => _state;
  int get currentStageIndex => _stageIndex;
  TrainingStage get currentStage => stages[_stageIndex];
  int get stageElapsedSeconds => _stageElapsedSeconds;
  int get totalElapsedSeconds => _totalElapsedSeconds;
  List<LogEvent> get logEvents => List.unmodifiable(_log);

  TrainingService({
    required this.stages,
    required this.audio,
    this.beepCooldownSeconds = 20,
  });

  void start() {
    _startTime = DateTime.now();
    _state = SessionState.running;
    _stateController.add(_state);
    _log.add(LogEvent(timestamp: _startTime!, kind: LogEventKind.deviceConnected));
    _announceStage();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void handleBpm(int bpm) {
    if (_state != SessionState.running) return;
    _log.add(LogEvent(timestamp: DateTime.now(), kind: LogEventKind.bpm, bpm: bpm));
    _checkCue(bpm);
  }

  void handleDisconnect() {
    _log.add(LogEvent(timestamp: DateTime.now(), kind: LogEventKind.deviceDisconnected));
    audio.speak('Heart rate monitor disconnected');
  }

  void handleReconnect(int? battery) {
    _log.add(LogEvent(timestamp: DateTime.now(), kind: LogEventKind.deviceReconnected));
    if (battery != null) {
      _log.add(LogEvent(timestamp: DateTime.now(), kind: LogEventKind.batteryLevel, batteryPercent: battery));
    }
    audio.speak('Heart rate monitor reconnected');
  }

  void _onTick(Timer _) {
    _stageElapsedSeconds++;
    _totalElapsedSeconds++;
    _tickController.add(_totalElapsedSeconds);

    if (_stageElapsedSeconds >= currentStage.durationSeconds) {
      if (_stageIndex + 1 < stages.length) {
        _stageIndex++;
        _stageElapsedSeconds = 0;
        _stageController.add(_stageIndex);
        _announceStage();
      } else {
        _finish();
      }
    }
  }

  void _checkCue(int bpm) {
    final stage = currentStage;
    final now = DateTime.now();
    final cooldownPassed = _lastCueTime == null ||
        now.difference(_lastCueTime!).inSeconds >= beepCooldownSeconds;
    if (!cooldownPassed) return;

    if (stage.target.isAbove(bpm)) {
      _lastCueTime = now;
      _log.add(LogEvent(timestamp: now, kind: LogEventKind.cueSlowDown));
      audio.speak('Slow down');
      audio.playSlowDownCue();
    } else if (stage.target.isBelow(bpm)) {
      _lastCueTime = now;
      _log.add(LogEvent(timestamp: now, kind: LogEventKind.cueSpeedUp));
      audio.speak('Speed up');
      audio.playSpeedUpCue();
    }
  }

  void _announceStage() {
    final stage = currentStage;
    _log.add(LogEvent(
      timestamp: DateTime.now(),
      kind: LogEventKind.stageStart,
      stageName: stage.name,
    ));
    audio.speak('${stage.name}. Target: ${stage.target.label}');
  }

  void _finish() {
    _ticker?.cancel();
    _state = SessionState.finished;
    _log.add(LogEvent(timestamp: DateTime.now(), kind: LogEventKind.sessionEnd));
    _stateController.add(_state);
    audio.speak('Workout complete. Great job!');
  }

  void dispose() {
    _ticker?.cancel();
    _stateController.close();
    _stageController.close();
    _tickController.close();
  }
}
