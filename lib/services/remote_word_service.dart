import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/turkish_text.dart';

/// GitHub manifest sisteminden kelime JSON'larını çeker ve birleştirir.
///
/// **Manifest formatı:**
/// ```json
/// {
///   "version": 1,
///   "sources": ["https://.../words.json", "https://.../words_ext.json"]
/// }
/// ```
///
/// **Akış:**
///  1. Manifest çekilir (version + URL listesi)
///  2. Listedeki tüm JSON'lar paralel çekilir
///  3. Kategoriler birleştirilir, kelimeler deduplicate edilir
///  4. Tek JSON olarak cache'e yazılır
class RemoteWordService {
  RemoteWordService._();

  // ============================================================
  // ⚠️ BURAYA MANIFEST.JSON RAW URL'İNİ KOY
  // ============================================================
  static const String _manifestUrl =
      'https://raw.githubusercontent.com/kakashi-deep/wordmaster/main/manifest.json';

  static const String _cacheMergedKey = 'remote_words_merged';
  static const String _cacheVersionKey = 'remote_words_version';

  static const Duration _timeout = Duration(seconds: 6);

  // ============================================================
  // ANA METOD
  // ============================================================

  /// Manifest'i çeker, tüm kaynakları indirir, birleştirir ve cache'e yazar.
  /// Başarısızsa `null` döner (çağıran cache/assets'e düşer).
  static Future<String?> fetchAndMerge() async {
    if (kIsWeb) return null;

    try {
      if (kDebugMode) debugPrint('📜 Manifest çekiliyor...');

      // 1) Manifest
      final manifest = await _fetchJson(_manifestUrl);
      if (manifest == null) {
        if (kDebugMode) debugPrint('❌ Manifest alınamadı');
        return null;
      }

      final version = (manifest['version'] as num?)?.toInt() ?? 1;
      final sources = manifest['sources'] as List?;

      if (sources == null || sources.isEmpty) {
        if (kDebugMode) debugPrint('❌ Manifest\'te sources yok');
        return null;
      }

      if (kDebugMode) {
        debugPrint('📜 Manifest v$version — ${sources.length} kaynak');
      }

      // 2) Tüm kaynakları paralel çek
      final futures = sources.whereType<String>().map(_fetchJson).toList();
      final results = await Future.wait(futures);

      // 3) Birleştir: { kategori: Set<kelime> }
      final merged = <String, Set<String>>{};
      int okCount = 0;

      for (final data in results) {
        if (data == null || data.isEmpty) continue;
        okCount++;

        for (final entry in data.entries) {
          if (entry.key.startsWith('_')) continue;
          if (entry.value is! List) continue;

          final set = merged.putIfAbsent(entry.key, () => <String>{});
          for (final w in entry.value) {
            if (w is String && w.trim().isNotEmpty) {
              set.add(turkishUpper(w.trim()));
            }
          }
        }
      }

      if (merged.isEmpty) {
        if (kDebugMode) debugPrint('❌ Hiç kelime alınamadı');
        return null;
      }

      // 4) Tek JSON blob
      final out = <String, dynamic>{
        '_meta': {
          'version': version,
          'sourceCount': okCount,
        },
      };

      final sortedCats = merged.keys.toList()..sort();
      for (final cat in sortedCats) {
        out[cat] = merged[cat]!.toList()..sort();
      }

      final mergedStr = jsonEncode(out);

      // 5) Cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheMergedKey, mergedStr);
      await prefs.setInt(_cacheVersionKey, version);

      if (kDebugMode) {
        final total = merged.values.fold<int>(0, (a, b) => a + b.length);
        debugPrint(
          '✅ Manifest v$version: $okCount/${sources.length} kaynak, '
          '${sortedCats.length} kategori, $total kelime',
        );
      }

      return mergedStr;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Manifest error: $e');
      return null;
    }
  }

  // ============================================================
  // YARDIMCI
  // ============================================================

  static Future<Map<String, dynamic>?> _fetchJson(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode != 200) {
        if (kDebugMode) debugPrint('❌ HTTP ${resp.statusCode}: $url');
        return null;
      }
      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) return null;
      return data;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Fetch error ($url): $e');
      return null;
    }
  }

  static Future<String?> getCachedJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheMergedKey);
  }

  static Future<int> getCachedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cacheVersionKey) ?? 0;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheMergedKey);
    await prefs.remove(_cacheVersionKey);
  }
}
