import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/word.dart';
import '../services/remote_word_service.dart';
import '../utils/turkish_text.dart';

/// Kelimeleri yükler.
///
/// **Yükleme sırası (internet öncelikli):**
///  1. **GitHub manifest** (canlı çekim + merge)
///  2. **Yerel cache** (son başarılı manifest sonucu)
///  3. **Assets** (`assets/words.json`, son yedek)
///
/// JSON formatı: { "_meta": {...}, "KategoriAdı": ["KELİME1", ...] }
/// `_meta` gibi alt çizgi ile başlayan anahtarlar kategori sayılmaz.
class WordRepository {
  WordRepository._();

  static const String _assetPath = 'assets/words.json';
  static bool _loaded = false;
  static String _source = 'none'; // 'manifest', 'cache', 'assets'
  static Object? _loadError;

  static final Map<String, List<Word>> _byCategory = {};

  // ==================== GETTER'LAR ====================

  static bool get isLoaded => _loaded;
  static bool get isEmpty => _byCategory.isEmpty;
  static bool get isNotEmpty => _byCategory.isNotEmpty;
  static Object? get loadError => _loadError;

  /// Kaynak: 'manifest', 'cache', 'assets', 'none'
  static String get source => _source;

  static bool get fromManifest => _source == 'manifest';
  static bool get fromCache => _source == 'cache';
  static bool get fromAssets => _source == 'assets';

  static int get categoryCount => _byCategory.length;

  /// Türkçe kaynak etiketi
  static String get sourceLabel {
    switch (_source) {
      case 'manifest':
        return 'GitHub (manifest)';
      case 'cache':
        return 'Yerel cache';
      case 'assets':
        return 'Assets (yedek)';
      default:
        return 'Yüklenmedi';
    }
  }

  // ==================== ANA YÜKLEME ====================

  static Future<void> load() async {
    if (_loaded) return;

    // ============ 1) MANIFEST'TEN CANLI ÇEK ============
    try {
      final merged = await RemoteWordService.fetchAndMerge();
      if (merged != null && merged.isNotEmpty) {
        _parse(merged);
        if (_byCategory.isNotEmpty) {
          _loaded = true;
          _source = 'manifest';
          _loadError = null;
          return;
        }
      }
    } catch (_) {
      // Manifest hatası → cache'e düş
    }

    // ============ 2) CACHE'E DÜŞ ============
    try {
      final cached = await RemoteWordService.getCachedJson();
      if (cached != null && cached.isNotEmpty) {
        _parse(cached);
        if (_byCategory.isNotEmpty) {
          _loaded = true;
          _source = 'cache';
          _loadError = null;
          return;
        }
      }
    } catch (_) {
      // Cache hatası → assets'e düş
    }

    // ============ 3) ASSETS'E DÜŞ ============
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _parse(raw);
      if (_byCategory.isNotEmpty) {
        _loaded = true;
        _source = 'assets';
        _loadError = null;
        return;
      }
    } catch (e, st) {
      _loadError = e;
      _source = 'none';
      debugPrint('WordRepository assets error: $e\n$st');
    }
  }

  /// Yeniden yükle (debug için).
  static Future<void> reload() async {
    _loaded = false;
    _source = 'none';
    _byCategory.clear();
    await load();
  }

  // ==================== PARSE ====================

  static void _parse(String raw) {
    final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;

    _byCategory.clear();

    data.forEach((key, value) {
      if (key.startsWith('_')) return;
      if (value is! List) return;

      final words = value
          .map((item) => Word(
                text: turkishUpper(item.toString().trim()),
                category: key,
              ))
          .toList();

      if (words.isNotEmpty) {
        _byCategory[key] = words;
      }
    });
  }

  // ==================== SORGULAR ====================

  static List<Word> forCategory(String category) =>
      _byCategory[category] ?? const [];

  static List<String> get categories => _byCategory.keys.toList();

  static List<Word> get all =>
      _byCategory.values.expand((list) => list).toList();

  /// Chapter ismine göre uzunluk filtresi uygular
  static List<Word> forChapter(String chapter) {
    late int minLen, maxLen;
    switch (chapter) {
      case 'Çok Kolay':
        minLen = 3;
        maxLen = 5;
        break;
      case 'Kolay':
        minLen = 3;
        maxLen = 6;
        break;
      case 'Orta':
        minLen = 4;
        maxLen = 7;
        break;
      case 'Zor':
        minLen = 5;
        maxLen = 8;
        break;
      case 'Çok Zor':
        minLen = 5;
        maxLen = 11;
        break;
      case 'Uzman':
        minLen = 9;
        maxLen = 99;
        break;
      default:
        minLen = 3;
        maxLen = 99;
    }
    return all
        .where((w) => w.text.length >= minLen && w.text.length <= maxLen)
        .toList();
  }

  static List<Word> byCategory(String category) => forCategory(category);

  static int get count => all.length;

  static int countInCategory(String category) =>
      _byCategory[category]?.length ?? 0;

  /// Seviye numarasına göre hangi kategori geleceğini belirler.
  static String categoryForLevel(int levelId) {
    final cats = categories;
    if (cats.isEmpty) return '';
    return cats[(levelId - 1) % cats.length];
  }
}
