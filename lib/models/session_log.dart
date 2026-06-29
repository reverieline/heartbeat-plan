enum LogEventKind {
  bpm,
  stageStart,
  deviceConnected,
  deviceDisconnected,
  deviceReconnected,
  cueSpeedUp,
  cueSlowDown,
  stageEndCue,
  batteryLevel,
  sessionStart,
  sessionEnd,
  sessionPaused,
  sessionResumed,
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
  final String planName;
  final DateTime startTime;
  final String deviceName;
  final String deviceAddress;
  final List<LogEvent> events;

  SessionLog({
    this.planName = '',
    required this.startTime,
    required this.deviceName,
    required this.deviceAddress,
    required this.events,
  });

  Duration get duration {
    if (events.isEmpty) return Duration.zero;
    return events.last.timestamp.difference(startTime);
  }

  bool get completed => events.any((e) => e.kind == LogEventKind.sessionEnd);

  static SessionLog? fromText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return null;

    DateTime? startTime;
    if (lines[0].startsWith('session_start=')) {
      startTime = DateTime.tryParse(lines[0].substring('session_start='.length).trim());
    }
    if (startTime == null) return null;

    String planName = '';
    int nextLine = 1;
    if (lines[nextLine].startsWith('plan_name=')) {
      planName = lines[nextLine].substring('plan_name='.length).trim();
      nextLine++;
    }

    String deviceName = '';
    String deviceAddress = '';
    if (nextLine < lines.length && lines[nextLine].startsWith('device=')) {
      final parts = lines[nextLine].substring('device='.length).split(' | address=');
      deviceName = parts[0].trim();
      deviceAddress = parts.length > 1 ? parts[1].trim() : '';
      nextLine++;
    }

    final events = <LogEvent>[];
    for (int i = nextLine; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('[')) continue;
      final closingBracket = line.indexOf(']');
      if (closingBracket < 0) continue;
      final ts = DateTime.tryParse(line.substring(1, closingBracket));
      if (ts == null) continue;
      final rest = line.substring(closingBracket + 2);

      LogEvent? event;
      if (rest.startsWith('bpm=')) {
        final bpm = int.tryParse(rest.substring(4));
        if (bpm != null) event = LogEvent(timestamp: ts, kind: LogEventKind.bpm, bpm: bpm);
      } else if (rest.startsWith('stage_start=')) {
        event = LogEvent(timestamp: ts, kind: LogEventKind.stageStart, stageName: rest.substring(12));
      } else if (rest == 'device_connected') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.deviceConnected);
      } else if (rest == 'device_disconnected') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.deviceDisconnected);
      } else if (rest == 'device_reconnected') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.deviceReconnected);
      } else if (rest == 'cue=speed_up') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.cueSpeedUp);
      } else if (rest == 'cue=slow_down') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.cueSlowDown);
      } else if (rest == 'cue=stage_end') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.stageEndCue);
      } else if (rest.startsWith('battery_level=')) {
        final pct = int.tryParse(rest.substring(14).replaceAll('%', ''));
        event = LogEvent(timestamp: ts, kind: LogEventKind.batteryLevel, batteryPercent: pct);
      } else if (rest == 'session_start') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.sessionStart);
      } else if (rest == 'session_end') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.sessionEnd);
      } else if (rest == 'session_paused') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.sessionPaused);
      } else if (rest == 'session_resumed') {
        event = LogEvent(timestamp: ts, kind: LogEventKind.sessionResumed);
      }
      if (event != null) events.add(event);
    }

    return SessionLog(
      planName: planName,
      startTime: startTime,
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      events: events,
    );
  }

  String toText() {
    final buf = StringBuffer();
    buf.writeln('session_start=${startTime.toIso8601String()}');
    if (planName.isNotEmpty) buf.writeln('plan_name=$planName');
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
        case LogEventKind.stageEndCue:
          buf.writeln('$ts cue=stage_end');
        case LogEventKind.batteryLevel:
          buf.writeln('$ts battery_level=${e.batteryPercent}%');
        case LogEventKind.sessionStart:
          buf.writeln('$ts session_start');
        case LogEventKind.sessionEnd:
          buf.writeln('$ts session_end');
        case LogEventKind.sessionPaused:
          buf.writeln('$ts session_paused');
        case LogEventKind.sessionResumed:
          buf.writeln('$ts session_resumed');
      }
    }
    return buf.toString();
  }
}
