import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool ttsEnabled;
  bool beepsEnabled;

  // Serial queue: each task is chained after the previous one completes.
  Future<void> _queue = Future.value();
  // Completer held while a speak() utterance is in progress.
  Completer<void>? _ttsCompleter;

  AudioService({
    this.ttsEnabled = true,
    this.beepsEnabled = true,
    Map<String, String>? ttsVoice,
    double ttsSpeed = 0.5,
    double ttsPitch = 1.0,
  }) {
    _tts.setSpeechRate(ttsSpeed);
    _tts.setVolume(1.0);
    _tts.setPitch(ttsPitch);
    if (ttsVoice != null) _tts.setVoice(ttsVoice);

    // All three callbacks complete the completer so _doSpeak unblocks
    // regardless of whether TTS finished, was cancelled, or errored.
    void completeTts() {
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    }
    _tts.setCompletionHandler(completeTts);
    _tts.setCancelHandler(completeTts);
    _tts.setErrorHandler((_) => completeTts());
  }

  Future<void> speak(String text) {
    if (!ttsEnabled) return Future.value();
    return _enqueue(() => _doSpeak(text));
  }

  Future<void> playSpeedUpCue() {
    if (!beepsEnabled) return Future.value();
    return _enqueue(() => _playToneSequence([620, 720, 920]));
  }

  Future<void> playSlowDownCue() {
    if (!beepsEnabled) return Future.value();
    return _enqueue(() => _playToneSequence([920, 720, 620]));
  }

  Future<void> stop() async {
    _queue = Future.value();
    // Unblock any in-progress _doSpeak before calling _tts.stop(),
    // so the completion handler (which fires after stop) finds a null completer.
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    await _tts.stop();
    await _player.stop();
  }

  // Chains [task] onto the serial queue, swallowing any errors so the queue
  // never gets stuck in a rejected state.
  Future<void> _enqueue(Future<void> Function() task) {
    _queue = _queue.then<void>(
      (_) => task(),
      onError: (_) => task(), // run even if previous task errored
    ).catchError((Object _) {}); // swallow this task's errors
    return _queue;
  }

  // Speaks [text] and waits until TTS actually finishes (via completion handler).
  Future<void> _doSpeak(String text) async {
    final completer = Completer<void>();
    _ttsCompleter = completer;
    await _tts.speak(text);
    await completer.future;
    _ttsCompleter = null;
  }

  Future<void> _playToneSequence(List<int> freqsHz) async {
    for (final freq in freqsHz) {
      await _player.play(BytesSource(_generateTone(freq, 160)));
      await Future<void>.delayed(const Duration(milliseconds: 240));
    }
  }

  static Uint8List _generateTone(int hz, int durationMs) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    const amplitude = 16000;

    final dataSize = numSamples * 2;
    final buffer = ByteData(44 + dataSize);
    int off = 0;

    // RIFF header
    buffer.setUint8(off++, 0x52); buffer.setUint8(off++, 0x49);
    buffer.setUint8(off++, 0x46); buffer.setUint8(off++, 0x46);
    buffer.setUint32(off, 36 + dataSize, Endian.little); off += 4;
    buffer.setUint8(off++, 0x57); buffer.setUint8(off++, 0x41);
    buffer.setUint8(off++, 0x56); buffer.setUint8(off++, 0x45);
    // fmt chunk
    buffer.setUint8(off++, 0x66); buffer.setUint8(off++, 0x6d);
    buffer.setUint8(off++, 0x74); buffer.setUint8(off++, 0x20);
    buffer.setUint32(off, 16, Endian.little); off += 4;
    buffer.setUint16(off, 1, Endian.little); off += 2;    // PCM
    buffer.setUint16(off, 1, Endian.little); off += 2;    // mono
    buffer.setUint32(off, sampleRate, Endian.little); off += 4;
    buffer.setUint32(off, sampleRate * 2, Endian.little); off += 4;
    buffer.setUint16(off, 2, Endian.little); off += 2;    // block align
    buffer.setUint16(off, 16, Endian.little); off += 2;   // bits per sample
    // data chunk
    buffer.setUint8(off++, 0x64); buffer.setUint8(off++, 0x61);
    buffer.setUint8(off++, 0x74); buffer.setUint8(off++, 0x61);
    buffer.setUint32(off, dataSize, Endian.little); off += 4;

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final sample = (amplitude * math.sin(2 * math.pi * hz * t)).round().clamp(-32768, 32767);
      buffer.setInt16(off, sample, Endian.little);
      off += 2;
    }

    return buffer.buffer.asUint8List();
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}
