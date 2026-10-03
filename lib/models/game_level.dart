class GameLevel {
  final int id;
  final String chapter;
  final int timeLimit;
  final int basePoints;
  final bool hasHint;
  final bool hasBonus;
  final int minLength;
  final int maxLength;
  final int gridSize;
  final int wordCount;
  final List<List<int>> directions;
  final bool isBonus;

  /// Her `scoreDecayInterval` saniyede kelime puanından düşülecek miktar.
  final int scoreDecayStep;

  /// Kaç saniyede bir puan kademesinin düşeceği
  final int scoreDecayInterval;

  /// Minimum puan (basePoints'in %25'i — sıfırlanmasın diye)
  final int minPoints;

  GameLevel({
    required this.id,
    required this.chapter,
    required this.timeLimit,
    required this.basePoints,
    required this.hasHint,
    required this.hasBonus,
    required this.minLength,
    required this.maxLength,
    required this.gridSize,
    required this.wordCount,
    required this.directions,
    this.isBonus = false,
    this.scoreDecayStep = 0,
    this.scoreDecayInterval = 30,
    int? minPoints,
  }) : minPoints = minPoints ?? (basePoints * 0.25).round();

  /// Verilen sürede kelime başına alınacak puan.
  int pointsForWord(int elapsedSeconds) {
    if (scoreDecayStep <= 0 || scoreDecayInterval <= 0) {
      return basePoints;
    }
    final steps = elapsedSeconds ~/ scoreDecayInterval;
    final decay = steps * scoreDecayStep;
    return (basePoints - decay).clamp(minPoints, basePoints);
  }
}

class ChapterConfig {
  static const List<int> _right = [0, 1];
  static const List<int> _down = [1, 0];
  static const List<int> _left = [0, -1];
  static const List<int> _up = [-1, 0];
  static const List<int> _downRight = [1, 1];
  static const List<int> _downLeft = [1, -1];
  static const List<int> _upRight = [-1, 1];
  static const List<int> _upLeft = [-1, -1];

  static const List<List<int>> _dirsVeryEasy = [_right, _down];
  static const List<List<int>> _dirsEasy = [_right, _down, _up];
  static const List<List<int>> _dirsMedium = [
    _right,
    _down,
    _up,
    _left,
  ];
  static const List<List<int>> _dirsHard = [
    _right,
    _down,
    _up,
    _left,
    _downRight,
    _downLeft,
    _upRight,
    _upLeft,
  ];

  /// Kaç bölümde bir bonus bölüm geleceği
  static const int bonusInterval = 5;

  static bool isBonusLevel(int levelId) => levelId % bonusInterval == 0;

  static GameLevel configFor(int levelId) {
    if (isBonusLevel(levelId)) {
      return _bonusConfig(levelId);
    }

    // === Çok Kolay: 1-20 ===
    // Kronometre: 00:00'dan başlar (timeLimit=0 → artan)
    if (levelId <= 20) {
      return GameLevel(
        id: levelId,
        chapter: 'Çok Kolay',
        timeLimit: 0,
        basePoints: 10,
        hasHint: false,
        hasBonus: false,
        minLength: 3,
        maxLength: 5,
        gridSize: 7,
        wordCount: 3,
        directions: _dirsVeryEasy,
        scoreDecayStep: 1,
        scoreDecayInterval: 30,
      );
    }
    // === Kolay: 21-60 ===
    else if (levelId <= 60) {
      return GameLevel(
        id: levelId,
        chapter: 'Kolay',
        timeLimit: 0,
        basePoints: 15,
        hasHint: true,
        hasBonus: false,
        minLength: 3,
        maxLength: 6,
        gridSize: 8,
        wordCount: 4,
        directions: _dirsEasy,
        scoreDecayStep: 2,
        scoreDecayInterval: 30,
      );
    }
    // === Orta: 61-120 ===
    else if (levelId <= 120) {
      return GameLevel(
        id: levelId,
        chapter: 'Orta',
        timeLimit: 0,
        basePoints: 25,
        hasHint: true,
        hasBonus: false,
        minLength: 4,
        maxLength: 7,
        gridSize: 9,
        wordCount: 5,
        directions: _dirsMedium,
        scoreDecayStep: 3,
        scoreDecayInterval: 30,
      );
    }
    // === Zor: 121-200 ===
    else if (levelId <= 200) {
      return GameLevel(
        id: levelId,
        chapter: 'Zor',
        timeLimit: 0,
        basePoints: 40,
        hasHint: true,
        hasBonus: true,
        minLength: 5,
        maxLength: 8,
        gridSize: 10,
        wordCount: 6,
        directions: _dirsHard,
        scoreDecayStep: 4,
        scoreDecayInterval: 30,
      );
    }
    // === Çok Zor: 201+ ===
    else {
      return GameLevel(
        id: levelId,
        chapter: 'Çok Zor',
        timeLimit: 0,
        basePoints: 60,
        hasHint: true,
        hasBonus: true,
        minLength: 5,
        maxLength: 11,
        gridSize: 12,
        wordCount: 7,
        directions: _dirsHard,
        scoreDecayStep: 6,
        scoreDecayInterval: 30,
      );
    }
  }

  /// Bonus bölüm — geri sayan timer, decay YOK
  static GameLevel _bonusConfig(int levelId) {
    if (levelId > 60) {
      return GameLevel(
        id: levelId,
        chapter: 'Bonus',
        timeLimit: 300,
        basePoints: 100,
        hasHint: true,
        hasBonus: true,
        minLength: 5,
        maxLength: 11,
        gridSize: 12,
        wordCount: 7,
        directions: _dirsHard,
        isBonus: true,
        scoreDecayStep: 0, // decay yok
      );
    } else {
      return GameLevel(
        id: levelId,
        chapter: 'Bonus',
        timeLimit: 150,
        basePoints: 80,
        hasHint: true,
        hasBonus: true,
        minLength: 5,
        maxLength: 8,
        gridSize: 10,
        wordCount: 6,
        directions: _dirsHard,
        isBonus: true,
        scoreDecayStep: 0,
      );
    }
  }
}
