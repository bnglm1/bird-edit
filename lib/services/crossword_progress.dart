import 'package:shared_preferences/shared_preferences.dart';

class CrosswordProgress {
  CrosswordProgress._();

  static const _levelKey = 'crossword_level';
  static const _scoreKey = 'crossword_score';

  static Future<int> getLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 1;
  }

  static Future<int> getScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 0;
  }

  static Future<void> save({
    required int level,
    required int score,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_levelKey, level);
    await prefs.setInt(_scoreKey, score);
  }
}
