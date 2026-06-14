import 'package:flutter/services.dart';

class MediaSessionService {
  MediaSessionService._();

  static const _channel = MethodChannel('org.heritageua.rhr_android/media_session');

  static void Function()? _onPlay;
  static void Function()? _onPause;
  static void Function()? _onStop;

  static void init({
    void Function()? onPlay,
    void Function()? onPause,
    void Function()? onStop,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onStop = onStop;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlay':
          _onPlay?.call();
        case 'onPause':
          _onPause?.call();
        case 'onStop':
          _onStop?.call();
      }
    });
  }

  static Future<void> start({
    required String stageName,
    required int bpm,
  }) async {
    await _channel.invokeMethod<void>('start', {'stageName': stageName, 'bpm': bpm});
  }

  static Future<void> update({
    required String stageName,
    required int bpm,
    required bool isPaused,
  }) async {
    await _channel.invokeMethod<void>('update', {
      'stageName': stageName,
      'bpm': bpm,
      'isPaused': isPaused,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}
