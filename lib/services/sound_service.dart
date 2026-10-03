import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tek bir nota/tık tanımı
class _Tone {
  final double frequency;
  final int durationMs;
  final double volume;
  final bool noise;
  final double harmonicMix;

  const _Tone({
    required this.frequency,
    required this.durationMs,
    this.volume = 0.6,
    this.noise = false,
    this.harmonicMix = 0.3,
  });
}

/// Tüm ses efektlerini kodla üretip çalar.
/// WAV byte'ları runtime'da oluşturulur, diske yazılmaz.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _prefKey = 'soundEnabled';
  static const int _sampleRate = 22050;

  final Map<String, AudioPlayer> _players = {};
  final Map<String, Uint8List> _cache = {};
  bool _enabled = true;
  bool _ready = false;

  bool get enabled => _enabled;

  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;

    _cache['tap'] = _buildTap();
    _cache['correct'] = _buildCorrect();
    _cache['wrong'] = _buildWrong();
    _cache['level_complete'] = _buildLevelComplete();
    _cache['hint'] = _buildHint();
    _cache['shuffle'] = _buildShuffle();

    for (final name in _cache.keys) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(0.9);
      _players[name] = p;
    }

    _ready = true;
  }

  // ==================== WAV ÜRETİCİ ====================

  Uint8List _buildFromTones(List<_Tone> tones) {
    final samples = <int>[];
    for (final tone in tones) {
      samples.addAll(_generateTone(
        frequency: tone.frequency,
        durationMs: tone.durationMs,
        volume: tone.volume,
        noise: tone.noise,
        harmonicMix: tone.harmonicMix,
      ));
    }
    return _pcmToWav(samples, _sampleRate);
  }

  List<int> _generateTone({
    required double frequency,
    required int durationMs,
    double volume = 0.6,
    bool noise = false,
    double harmonicMix = 0.3,
  }) {
    final count = (_sampleRate * durationMs / 1000).round();
    final out = List<int>.filled(count, 0);
    final rnd = Random();
    final fadeLen = (_sampleRate * 0.006).round();
    const twoPi = 2 * pi;

    for (int i = 0; i < count; i++) {
      final t = i / _sampleRate;
      final progress = i / count;

      double env = 1.0;
      if (i < fadeLen) env *= i / fadeLen;
      final remaining = count - i;
      if (remaining < fadeLen) env *= remaining / fadeLen;
      env *= (1 - progress * 0.5);

      double v;
      if (noise) {
        v = rnd.nextDouble() * 2 - 1;
      } else {
        v = sin(twoPi * frequency * t);
        if (harmonicMix > 0) {
          v = (1 - harmonicMix) * v +
              harmonicMix * sin(twoPi * frequency * 2 * t);
        }
      }

      final s = (v * env * volume * 32767).round().clamp(-32768, 32767);
      out[i] = s;
    }
    return out;
  }

  Uint8List _pcmToWav(List<int> samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;
    final bytes = BytesBuilder();
    final header = ByteData(44);

    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);

    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);

    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);

    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    bytes.add(header.buffer.asUint8List());

    final pcm = ByteData(dataSize);
    for (int i = 0; i < samples.length; i++) {
      pcm.setInt16(i * 2, samples[i], Endian.little);
    }
    bytes.add(pcm.buffer.asUint8List());

    return bytes.toBytes();
  }

  // ==================== SES TANIMLARI ====================

  Uint8List _buildTap() => _buildFromTones([
        const _Tone(
            frequency: 880, durationMs: 45, volume: 0.35, harmonicMix: 0.5),
      ]);

  Uint8List _buildCorrect() => _buildFromTones([
        const _Tone(frequency: 523.25, durationMs: 80, volume: 0.55),
        const _Tone(frequency: 659.25, durationMs: 80, volume: 0.55),
        const _Tone(frequency: 783.99, durationMs: 160, volume: 0.6),
      ]);

  Uint8List _buildWrong() => _buildFromTones([
        const _Tone(
            frequency: 220, durationMs: 130, volume: 0.5, harmonicMix: 0.6),
        const _Tone(
            frequency: 165, durationMs: 200, volume: 0.5, harmonicMix: 0.6),
      ]);

  Uint8List _buildLevelComplete() => _buildFromTones([
        const _Tone(frequency: 523.25, durationMs: 110, volume: 0.55),
        const _Tone(frequency: 659.25, durationMs: 110, volume: 0.55),
        const _Tone(frequency: 783.99, durationMs: 110, volume: 0.6),
        const _Tone(frequency: 1046.50, durationMs: 300, volume: 0.65),
      ]);

  Uint8List _buildHint() => _buildFromTones([
        const _Tone(
            frequency: 1318.51, durationMs: 70, volume: 0.4, harmonicMix: 0.5),
      ]);

  Uint8List _buildShuffle() => _buildFromTones([
        const _Tone(frequency: 0, durationMs: 140, volume: 0.35, noise: true),
      ]);

  // ==================== ÇALMA ====================

  Future<void> _play(String name) async {
    if (!_enabled || !_ready) return;
    try {
      final p = _players[name];
      final data = _cache[name];
      if (p == null || data == null) return;
      await p.stop();
      await p.play(BytesSource(data));
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService ($name): $e');
    }
  }

  Future<void> playTap() => _play('tap');
  Future<void> playCorrect() => _play('correct');
  Future<void> playWrong() => _play('wrong');
  Future<void> playLevelComplete() => _play('level_complete');
  Future<void> playHint() => _play('hint');
  Future<void> playShuffle() => _play('shuffle');

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (!value) await stopAll();
  }

  Future<void> toggle() => setEnabled(!_enabled);

  Future<void> stopAll() async {
    for (final p in _players.values) {
      await p.stop();
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _cache.clear();
    _ready = false;
  }
}
