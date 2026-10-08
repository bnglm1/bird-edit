import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tek bir nota/tık tanımı (kod üretilen efektler için)
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

/// Ses efektleri + arka plan müziği yönetimi.
///
/// **Ses kaynakları:**
///  - **Kod üretilen efektler:** tap, correct, wrong, hint, shuffle
///  - **MP3 dosyaları:**
///    - `assets/sounds/tap.mp3` (Kelime Avı'na özel tıklama sesi)
///    - `assets/sounds/background_music.mp3` (Kelime Avı'nda çalar)
///    - `assets/sounds/level_up.mp3` (bölüm tamamlanınca çalar)
///
/// **Arka plan müziği davranışı:**
///  - Sadece `playBackgroundMusic()` çağrıldığında başlar
///  - Müzik bittiğinde `_musicGapMs` kadar bekler, sonra baştan başlar
///  - Aktif ekran müzik istemiyorsa (`_musicRequested = false`) durur
///  - Reklam sırasında `pauseBackgroundMusic()` ile duraklatılır,
///    `resumeBackgroundMusic()` ile kaldığı yerden devam eder
///  - Tüm player'lar `audioFocus: none` ile çalışır (efektler müziği
///    duraklatmaz)
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _prefKey = 'soundEnabled';
  static const int _sampleRate = 22050;
  static const double _musicVolume = 0.35;

  /// Müzik bittikten sonra beklenen süre (ms). 0 = kesintisiz loop.
  static const int _musicGapMs = 15000; // 15 saniye

  /// Kod üretilen efektler (tap, correct, wrong, hint, shuffle)
  final Map<String, AudioPlayer> _players = {};
  final Map<String, Uint8List> _cache = {};

  /// Arka plan müziği player'ı
  AudioPlayer? _musicPlayer;
  bool _musicPlaying = false;

  /// Reklam sırasında müzik duraklatıldı mı?
  bool _musicPaused = false;

  /// Müzik bittiğinde 15 sn beklemek için timer
  Timer? _musicGapTimer;

  /// Level up sesi için ayrı player (mp3 dosyası)
  AudioPlayer? _levelUpPlayer;

  /// Kelime Avı'na özel tap sesi player'ı (mp3 dosyası)
  AudioPlayer? _wordSearchTapPlayer;

  /// Aktif ekran müzik istedi mi? — `setEnabled` bunu kontrol eder.
  bool _musicRequested = false;

  bool _enabled = true;
  bool _ready = false;

  bool get enabled => _enabled;
  bool get isMusicPlaying => _musicPlaying;

  Future<void> init() async {
    if (_ready) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;

    // Tüm player'lar audio focus İSTEMEZ — efektler müziği duraklatmaz
    final noFocusContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    );

    // ==================== KOD ÜRETİLEN EFEKTLER ====================
    _cache['tap'] = _buildTap(); // 👈 home, profile, auth, game_screen
    _cache['correct'] = _buildCorrect();
    _cache['wrong'] = _buildWrong();
    _cache['hint'] = _buildHint();
    _cache['shuffle'] = _buildShuffle();

    for (final name in _cache.keys) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(0.9);
      await p.setAudioContext(noFocusContext);
      _players[name] = p;
    }

    // ==================== ARKA PLAN MÜZİĞİ ====================
    _musicPlayer = AudioPlayer();
    // ⚠️ loop DEĞİL, stop — manuel döngü için (15 sn aralı)
    await _musicPlayer!.setReleaseMode(ReleaseMode.stop);
    await _musicPlayer!.setVolume(_musicVolume);
    await _musicPlayer!.setAudioContext(noFocusContext);

    // Müzik bittiğinde `_onMusicComplete()` çağrılsın
    _musicPlayer!.onPlayerComplete.listen((_) => _onMusicComplete());

    // ==================== LEVEL UP (MP3) ====================
    _levelUpPlayer = AudioPlayer();
    await _levelUpPlayer!.setReleaseMode(ReleaseMode.stop);
    await _levelUpPlayer!.setVolume(0.9);
    await _levelUpPlayer!.setAudioContext(noFocusContext);

    // ==================== KELİME AVI TAP SESİ (MP3) ====================
    _wordSearchTapPlayer = AudioPlayer();
    await _wordSearchTapPlayer!.setReleaseMode(ReleaseMode.stop);
    await _wordSearchTapPlayer!.setVolume(0.9);
    await _wordSearchTapPlayer!.setAudioContext(noFocusContext);

    _ready = true;
    // ⚠️ OTOMATİK MÜZİK BAŞLATMA YOK — müzik sadece Kelime Avı'nda çalar
  }

  // ==================== ARKA PLAN MÜZİĞİ ====================

  /// Aktif ekran müzik istiyor. Zaten çalıyorsa no-op.
  Future<void> playBackgroundMusic() async {
    _musicRequested = true;
    if (!_ready) return;
    if (!_enabled) return;
    if (_musicPlaying) return;

    // Devam eden gap timer'ı iptal et (kullanıcı yeni ekrana girdi)
    _musicGapTimer?.cancel();

    await _playMusicInternal();
  }

  /// Aktif ekran artık müzik istemiyor. Müziği ve bekleyen gap'i durdurur.
  Future<void> stopBackgroundMusic() async {
    _musicRequested = false;
    _musicGapTimer?.cancel();
    try {
      await _musicPlayer?.stop();
    } catch (_) {}
    _musicPlaying = false;
    _musicPaused = false;
    if (kDebugMode) debugPrint('🔇 Background music stopped');
  }

  /// Reklam açılırken çağrılır — müziği duraklatır.
  Future<void> pauseBackgroundMusic() async {
    if (!_musicPlaying || _musicPaused) return;
    try {
      await _musicPlayer?.pause();
      _musicPaused = true;
      if (kDebugMode) debugPrint('⏸️ Müzik duraklatıldı (reklam)');
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService (pause): $e');
    }
  }

  /// Reklam kapandığında çağrılır — müziği kaldığı yerden devam ettirir.
  Future<void> resumeBackgroundMusic() async {
    if (!_musicPaused) return;
    _musicPaused = false;

    if (!_musicRequested || !_enabled) return;

    try {
      await _musicPlayer?.resume();
      if (kDebugMode) debugPrint('▶️ Müzik devam ediyor');
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService (resume): $e');
    }
  }

  /// Müziği başlatan iç metot.
  Future<void> _playMusicInternal() async {
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.play(AssetSource('sounds/background_music.mp3'));
      _musicPlaying = true;
      _musicPaused = false;
      if (kDebugMode) debugPrint('🎵 Background music started');
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService (music play): $e');
      _musicPlaying = false;
    }
  }

  /// Müzik bittiğinde çağrılır.
  void _onMusicComplete() {
    _musicPlaying = false;

    if (!_musicRequested || !_enabled) return;

    if (kDebugMode) {
      debugPrint('⏸️ Müzik bitti — ${_musicGapMs ~/ 1000} sn sessizlik');
    }

    if (_musicGapMs <= 0) {
      _playMusicInternal();
      return;
    }

    _musicGapTimer?.cancel();
    _musicGapTimer = Timer(const Duration(milliseconds: _musicGapMs), () {
      if (!_musicRequested || !_enabled) return;
      if (_musicPlaying) return;
      _playMusicInternal();
    });
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

  // ==================== SES TANIMLARI (KOD) ====================

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

  Uint8List _buildHint() => _buildFromTones([
        const _Tone(
            frequency: 1318.51, durationMs: 70, volume: 0.4, harmonicMix: 0.5),
      ]);

  Uint8List _buildShuffle() => _buildFromTones([
        const _Tone(frequency: 0, durationMs: 140, volume: 0.35, noise: true),
      ]);

  // ==================== ÇALMA (KOD ÜRETİLEN) ====================

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

  /// Genel tıklama sesi — kod üretilen kısa bip.
  /// Home, Profile, Auth, Game Screen, Crossword ekranlarında kullanılır.
  Future<void> playTap() => _play('tap');

  Future<void> playCorrect() => _play('correct');
  Future<void> playWrong() => _play('wrong');
  Future<void> playHint() => _play('hint');
  Future<void> playShuffle() => _play('shuffle');

  // ==================== ÇALMA (MP3 DOSYALARI) ====================

  /// Kelime Avı'na özel tıklama sesi — `assets/sounds/tap.mp3`.
  /// Sadece WordSearchScreen içinde kullanılır.
  Future<void> playWordSearchTap() async {
    if (!_enabled || !_ready) return;
    try {
      await _wordSearchTapPlayer?.stop();
      await _wordSearchTapPlayer?.play(AssetSource('sounds/tap.mp3'));
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService (word_search_tap): $e');
    }
  }

  /// Bölüm tamamlandığında level up sesini çalar.
  Future<void> playLevelComplete() async {
    if (!_enabled || !_ready) return;
    try {
      await _levelUpPlayer?.stop();
      await _levelUpPlayer?.play(AssetSource('sounds/level_up.mp3'));
    } catch (e) {
      if (kDebugMode) debugPrint('SoundService (level_up): $e');
    }
  }

  // ==================== AYARLAR ====================

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    if (!value) {
      await stopAll();
      _musicGapTimer?.cancel();
      try {
        await _musicPlayer?.stop();
      } catch (_) {}
      _musicPlaying = false;
      _musicPaused = false;
    } else {
      if (_musicRequested) {
        await playBackgroundMusic();
      }
    }
  }

  Future<void> toggle() => setEnabled(!_enabled);

  Future<void> stopAll() async {
    for (final p in _players.values) {
      await p.stop();
    }
    try {
      await _levelUpPlayer?.stop();
    } catch (_) {}
    try {
      await _wordSearchTapPlayer?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _musicGapTimer?.cancel();
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _cache.clear();
    await _musicPlayer?.dispose();
    _musicPlayer = null;
    await _levelUpPlayer?.dispose();
    _levelUpPlayer = null;
    await _wordSearchTapPlayer?.dispose();
    _wordSearchTapPlayer = null;
    _ready = false;
    _musicPlaying = false;
    _musicPaused = false;
    _musicRequested = false;
  }
}
