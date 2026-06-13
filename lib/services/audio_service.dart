import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool ttsEnabled;

  AudioService({this.ttsEnabled = true}) {
    _tts.setSpeechRate(0.5);
    _tts.setVolume(1.0);
  }

  Future<void> speak(String text) async {
    if (!ttsEnabled) return;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }

  Future<void> playSpeedUpCue() async => _playToneSequence([620, 720, 920]);
  Future<void> playSlowDownCue() async => _playToneSequence([920, 720, 620]);

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
    _tts.stop();
    _player.dispose();
  }
}
