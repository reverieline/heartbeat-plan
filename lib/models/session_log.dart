enum LogEventKind {
  bpm,
  stageStart,
  deviceConnected,
  deviceDisconnected,
  deviceReconnected,
  cueSpeedUp,
  cueSlowDown,
  batteryLevel,
  sessionStart,
  sessionEnd,
}

class LogEvent {
  final DateTime timestamp;
  final LogEventKind kind;
  final int? bpm;
  final String? stageName;
  final int? batteryPercent;

  const LogEvent({
    required this.timestamp,
    required this.kind,
    this.bpm,
    this.stageName,
    this.batteryPercent,
  });
}

class SessionLog {
  final DateTime startTime;
  final String deviceName;
  final String deviceAddress;
  final List<LogEvent> events;

  SessionLog({
    required this.startTime,
    required this.deviceName,
    required this.deviceAddress,
    required this.events,
  });

  Duration get duration {
    if (events.isEmpty) return Duration.zero;
    return events.last.timestamp.difference(startTime);
  }

  String toText() {
    final buf = StringBuffer();
    buf.writeln('session_start=${startTime.toIso8601String()}');
    buf.writeln('device=$deviceName | address=$deviceAddress');
    for (final e in events) {
      final ts = '[${e.timestamp.toIso8601String()}]';
      switch (e.kind) {
        case LogEventKind.bpm:
          buf.writeln('$ts bpm=${e.bpm}');
        case LogEventKind.stageStart:
          buf.writeln('$ts stage_start=${e.stageName}');
        case LogEventKind.deviceConnected:
          buf.writeln('$ts device_connected');
        case LogEventKind.deviceDisconnected:
          buf.writeln('$ts device_disconnected');
        case LogEventKind.deviceReconnected:
          buf.writeln('$ts device_reconnected');
        case LogEventKind.cueSpeedUp:
          buf.writeln('$ts cue=speed_up');
        case LogEventKind.cueSlowDown:
          buf.writeln('$ts cue=slow_down');
        case LogEventKind.batteryLevel:
          buf.writeln('$ts battery_level=${e.batteryPercent}%');
        case LogEventKind.sessionStart:
          buf.writeln('$ts session_start');
        case LogEventKind.sessionEnd:
          buf.writeln('$ts session_end');
      }
    }
    return buf.toString();
  }
}
