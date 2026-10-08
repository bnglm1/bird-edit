import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_service.dart';

/// Client tarafında sahte liderlik tablosu.
///
/// **Yükleme sırası (internet öncelikli):**
///  1. **GitHub'dan canlı çek** (`fake_users.json`)
///  2. **Yerel cache** (son başarılı GitHub sonucu)
///  3. **Yerleşik liste** (uygulamaya gömülü 40 kişi)
///
/// **Kullanım:**
///  - `FakeLeaderboard.load()` → uygulama açılışında 1 kez çağır
///  - `FakeLeaderboard.getEntries()` → senkron, RAM'den okur
///  - `FakeLeaderboard.countAbove(score)` → senkron, RAM'den okur
///
/// **GitHub JSON formatı:**
/// ```json
/// {
///   "version": 1,
///   "updatedAt": "2026-10-03",
///   "users": [
///     { "nickname": "Gül", "score": 48750 },
///     { "nickname": "Erdal", "score": 44200 }
///   ]
/// }
/// ```
class FakeLeaderboard {
  FakeLeaderboard._();

  /// 200 puan = 1 seviye (görsel eşleme)
  static const int _pointsPerLevel = 200;

  /// Ağ zaman aşımı
  static const Duration _timeout = Duration(seconds: 8);

  // ============================================================
  // ⚠️ BURAYA KENDİ GITHUB RAW URL'İNİ KOY
  // ============================================================
  /// Manifest URL — buradan `fakeUsers` alanı okunur
  static const String _manifestUrl =
      'https://raw.githubusercontent.com/kakashi-deep/wordmaster/main/manifest.json';

  // SharedPreferences anahtarları
  static const String _cacheKey = 'fake_users_json';
  static const String _cacheVersionKey = 'fake_users_version';

  // ============================================================
  // YERLEŞİK YEDEK LİSTE (GitHub + cache başarısız olursa)
  // ============================================================
  static const List<MapEntry<String, int>> _fallbackEntries = [
    // ============ ZİRVE: 35.000 - 50.000 ============
    MapEntry('Gül', 48750),
    MapEntry('Erdal', 44200),
    MapEntry('Nurten', 41500),
    MapEntry('Şaban', 38600),
    MapEntry('Songül', 35800),

    // ============ YÜKSEK: 20.000 - 33.000 ============
    MapEntry('Bekir', 32400),
    MapEntry('Filiz', 30150),
    MapEntry('Mahmut', 28600),
    MapEntry('Esra', 26900),
    MapEntry('Salih', 25300),
    MapEntry('Merve', 23800),
    MapEntry('Kemal', 22500),
    MapEntry('Dilek', 21400),
    MapEntry('Kadir', 20600),
    MapEntry('Sevgi', 19800),

    // ============ ORTA: 5.000 - 18.000 ============
    MapEntry('Recep', 18200),
    MapEntry('Havva', 16800),
    MapEntry('İsmail', 15400),
    MapEntry('Yasemin', 14200),
    MapEntry('Süleyman', 13100),
    MapEntry('Halil', 12000),
    MapEntry('Zehra', 11000),
    MapEntry('Ramazan', 10100),
    MapEntry('Şerife', 9200),
    MapEntry('Osman', 8400),
    MapEntry('Meryem', 7600),
    MapEntry('Murat', 6900),
    MapEntry('Hatice', 6200),
    MapEntry('Yusuf', 5600),
    MapEntry('Emine', 5100),

    // ============ DÜŞÜK: 500 - 4.500 ============
    MapEntry('İbrahim', 4500),
    MapEntry('Elif', 3900),
    MapEntry('Hüseyin', 3300),
    MapEntry('Zeynep', 2700),
    MapEntry('Ali', 2200),
    MapEntry('Fatma', 1700),
    MapEntry('Mustafa', 1300),
    MapEntry('Ayşe', 900),
    MapEntry('Mehmet', 650),
    MapEntry('Ahmet', 500),
  ];

  // ============================================================
  // RAM'DEKİ AKTİF LİSTE
  // ============================================================
  static List<MapEntry<String, int>> _users = const [];
  static bool _loaded = false;
  static String _source = 'none'; // 'github' | 'cache' | 'fallback'

  static bool get isLoaded => _loaded;
  static String get source => _source;
  static int get userCount =>
      _users.isEmpty ? _fallbackEntries.length : _users.length;

  static String get sourceLabel {
    switch (_source) {
      case 'github':
        return 'GitHub (canlı)';
      case 'cache':
        return 'Yerel cache';
      case 'fallback':
        return 'Yerleşik liste';
      default:
        return 'Yüklenmedi';
    }
  }

  // ============================================================
  // ANA YÜKLEME
  // ============================================================

  /// Uygulama açılışında 1 kez çağır.
  /// GitHub → cache → fallback sırasıyla dener.
  static Future<void> load() async {
    if (_loaded) return;

    // 1) GitHub'dan canlı çek
    try {
      final json = await _fetchFromGitHub();
      if (json != null) {
        _parseAndSet(json);
        if (_users.isNotEmpty) {
          _loaded = true;
          _source = 'github';
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ FakeLeaderboard github error: $e');
    }

    // 2) Yerel cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _parseAndSet(cached);
        if (_users.isNotEmpty) {
          _loaded = true;
          _source = 'cache';
          if (kDebugMode) {
            debugPrint('📦 FakeLeaderboard cache: ${_users.length} kişi');
          }
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ FakeLeaderboard cache: $e');
    }

    // 3) Yerleşik liste
    _users = const [];
    _loaded = true;
    _source = 'fallback';
    if (kDebugMode) {
      debugPrint(
          '📦 FakeLeaderboard fallback: ${_fallbackEntries.length} kişi');
    }
  }

  /// Debug için RAM'i sıfırla + cache temizle.
  static Future<void> reset() async {
    _loaded = false;
    _users = const [];
    _source = 'none';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheVersionKey);
  }

  // ============================================================
  // GITHUB FETCH
  // ============================================================

  static Future<String?> _fetchFromGitHub() async {
    try {
      // ============ 1) Manifest'ten fakeUsers URL'ini al ============
      if (kDebugMode) debugPrint('📜 FakeLeaderboard manifest çekiliyor...');

      final manifestResp =
          await http.get(Uri.parse(_manifestUrl)).timeout(_timeout);

      if (manifestResp.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '❌ FakeLeaderboard manifest HTTP ${manifestResp.statusCode}');
        }
        return null;
      }

      final manifest = jsonDecode(manifestResp.body);
      if (manifest is! Map<String, dynamic>) return null;

      final fakeUsersUrl = manifest['fakeUsers'] as String?;
      if (fakeUsersUrl == null || fakeUsersUrl.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ FakeLeaderboard: manifest\'te fakeUsers yok');
        }
        return null;
      }

      // ============ 2) fake_users.json'u çek ============
      if (kDebugMode) debugPrint('🌐 FakeLeaderboard users çekiliyor...');

      final resp = await http.get(Uri.parse(fakeUsersUrl)).timeout(_timeout);

      if (resp.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('❌ FakeLeaderboard users HTTP ${resp.statusCode}');
        }
        return null;
      }

      // Validasyon
      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) return null;

      final users = data['users'];
      if (users is! List || users.isEmpty) {
        if (kDebugMode) debugPrint('❌ FakeLeaderboard: users boş');
        return null;
      }

      // Cache'e kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, resp.body);

      final version = (data['version'] as num?)?.toInt() ?? 1;
      await prefs.setInt(_cacheVersionKey, version);

      if (kDebugMode) {
        debugPrint(
          '✅ FakeLeaderboard github: v$version, ${users.length} kişi',
        );
      }

      return resp.body;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ FakeLeaderboard fetch: $e');
      return null;
    }
  }

  // ============================================================
  // PARSE
  // ============================================================

  static void _parseAndSet(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) {
        _users = const [];
        return;
      }

      final users = data['users'];
      if (users is! List) {
        _users = const [];
        return;
      }

      final parsed = <MapEntry<String, int>>[];
      for (final u in users) {
        if (u is! Map) continue;
        final nick = (u['nickname'] as String?)?.trim();
        final score = (u['score'] as num?)?.toInt();
        if (nick != null && nick.isNotEmpty && score != null && score > 0) {
          parsed.add(MapEntry(nick, score));
        }
      }

      // Skora göre büyükten küçüğe sırala (görsel doğru sıralama için)
      parsed.sort((a, b) => b.value.compareTo(a.value));
      _users = parsed;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ FakeLeaderboard parse: $e');
      _users = const [];
    }
  }

  // ============================================================
  // SORGULAR (SENKRON — RAM'den okur)
  // ============================================================

  /// Aktif listeyi `LeaderboardEntry` listesi olarak döner.
  static List<LeaderboardEntry> getEntries() {
    final source = _users.isEmpty ? _fallbackEntries : _users;

    return source.map((e) {
      final score = e.value;
      final level = (score / _pointsPerLevel).clamp(1, 999).toInt();

      return LeaderboardEntry(
        uid: 'fake_${e.key}',
        email: '${e.key.toLowerCase()}@fake',
        nickname: e.key,
        totalScore: score,
        highestLevel: level,
      );
    }).toList();
  }

  /// Verilen skordan yüksek puanlı fake kullanıcı sayısı.
  static int countAbove(int score) {
    final source = _users.isEmpty ? _fallbackEntries : _users;
    return source.where((e) => e.value > score).length;
  }
}
