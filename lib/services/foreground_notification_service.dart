import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// Top-level — must not be a closure or method; runs in a separate isolate.
@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_TrainingTaskHandler());
}

class _TrainingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  // Forward button presses to the main isolate.
  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
  }
}

class ForegroundNotificationService {
  ForegroundNotificationService._();

  static const int _serviceId = 1001;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rhr_training_session',
        channelName: 'Heartbeat Plan Training Session',
        channelDescription: 'Live BPM and stage info during a training session',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> requestPermission() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  static Future<void> start({
    required String stageName,
    required int bpm,
    required int elapsedSeconds,
  }) async {
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: stageName,
      notificationText: _buildText(bpm, elapsedSeconds),
      callback: startForegroundCallback,
      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Stop'),
        NotificationButton(id: 'pause_resume', text: 'Pause'),
      ],
    );
    if (result is ServiceRequestFailure) {
      throw Exception('Foreground service failed to start: ${result.error}');
    }
  }

  static Future<void> update({
    required String stageName,
    required int bpm,
    required int elapsedSeconds,
    required bool isPaused,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: isPaused ? '⏸ $stageName' : stageName,
      notificationText: _buildText(bpm, elapsedSeconds),
      notificationButtons: [
        const NotificationButton(id: 'stop', text: 'Stop'),
        NotificationButton(id: 'pause_resume', text: isPaused ? 'Resume' : 'Pause'),
      ],
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static String _buildText(int bpm, int elapsedSeconds) {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    final t = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final bpmStr = bpm > 0 ? '$bpm bpm' : '-- bpm';
    return '♥ $bpmStr  |  $t';
  }
}
