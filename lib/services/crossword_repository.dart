import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/crossword_puzzle.dart';
import 'crossword_generator.dart';

/// GitHub'dan kelime listelerini çekip bulmacayı otomatik üretir.
///
/// **JSON formatı (GitHub'da):**
/// ```json
/// {
///   "version": 1,
///   "levels": [
///     { "title": "BAŞLANGIÇ", "words": ["UZAK", "AKIL", "KAZ"] }
///   ]
/// }
/// ```
class CrosswordRepository {
  CrosswordRepository._();

  static const String _manifestUrl =
      'https://raw.githubusercontent.com/kakashi-deep/wordmaster/main/manifest.json';

  static const String _cacheKey = 'crossword_levels_json';
  static const Duration _timeout = Duration(seconds: 8);

  static List<_LevelSpec> _levels = [];
  static bool _loaded = false;
  static String _source = 'none';

  static bool get isLoaded => _loaded;
  static String get source => _source;
  static int get puzzleCount => _levels.length;

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

  static CrosswordPuzzle? puzzleForLevel(int levelId) {
    if (_levels.isEmpty) return null;
    final idx = (levelId - 1) % _levels.length;
    final spec = _levels[idx];
    return CrosswordGenerator.generate(
      id: levelId,
      title: spec.title,
      words: spec.words,
    );
  }

  static Future<void> load() async {
    if (_loaded) return;

    // 1) GitHub
    try {
      final json = await _fetchFromGitHub();
      if (json != null && json.isNotEmpty) {
        _parseAndSet(json);
        if (_levels.isNotEmpty) {
          _loaded = true;
          _source = 'github';
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Crossword github: $e');
    }

    // 2) Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _parseAndSet(cached);
        if (_levels.isNotEmpty) {
          _loaded = true;
          _source = 'cache';
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Crossword cache: $e');
    }

    // 3) Fallback
    _levels = _fallback();
    _loaded = true;
    _source = 'fallback';
  }

  static Future<String?> _fetchFromGitHub() async {
    final manifestResp =
        await http.get(Uri.parse(_manifestUrl)).timeout(_timeout);
    if (manifestResp.statusCode != 200) return null;

    final manifest = jsonDecode(manifestResp.body);
    if (manifest is! Map<String, dynamic>) return null;

    final url = manifest['crosswordPuzzles'] as String?;
    if (url == null || url.isEmpty) return null;

    final resp = await http.get(Uri.parse(url)).timeout(_timeout);
    if (resp.statusCode != 200) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, resp.body);
    return resp.body;
  }

  static void _parseAndSet(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      final list = data['levels'] as List?;
      if (list == null) return;

      final parsed = <_LevelSpec>[];
      for (final item in list) {
        if (item is! Map) continue;
        final title = (item['title'] as String?)?.trim() ?? 'Bulmaca';
        final words = (item['words'] as List?)
                ?.whereType<String>()
                .map((w) => w.trim().toUpperCase())
                .where((w) => w.length >= 2)
                .toList() ??
            [];
        if (words.isEmpty) continue;
        parsed.add(_LevelSpec(title: title, words: words));
      }

      _levels = parsed;
      if (kDebugMode) {
        debugPrint('✅ Crossword: ${parsed.length} seviye');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Crossword parse: $e');
      _levels = [];
    }
  }

  static List<_LevelSpec> _fallback() {
    return [
      _LevelSpec(
        title: 'BAŞLANGIÇ',
        words: ['UZAK', 'AKIL', 'KAZ', 'KAL', 'ZIL'],
      ),
      _LevelSpec(
        title: 'KELİMELER',
        words: ['KALEM', 'ELMA', 'MAL', 'KALE', 'LEM'],
      ),
    ];
  }
}

class _LevelSpec {
  final String title;
  final List<String> words;
  const _LevelSpec({required this.title, required this.words});
}
