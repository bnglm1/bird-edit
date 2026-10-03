import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/game_level.dart';
import '../models/word.dart';
import '../services/account_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../services/word_search_generator.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/success_dialog.dart';

class WordSearchScreen extends StatefulWidget {
  final int levelId;
  const WordSearchScreen({super.key, required this.levelId});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen>
    with TickerProviderStateMixin {
  late int _levelId;
  late GameLevel _level;
  late String _category;
  late WordSearchPuzzle _puzzle;

  Timer? _timer;

  int _elapsedSeconds = 0;
  int _remainingTime = 0;

  int _score = 0;
  int _sessionEarned = 0;

  WordPosition? _dragStart;
  WordPosition? _dragCurrent;
  List<WordPosition> _currentPath = [];
  final Set<WordPosition> _foundPositions = {};
  final Map<PlacedWord, Color> _wordColors = {};

  bool _completeHandling = false;
  int _lastSavedSession = 0;
  late final AnimationController _pulse;

  static const List<Color> _foundPalette = [
    Color(0xFF7BE495),
    Color(0xFF64B5F6),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
    Color(0xFFFF8A80),
    Color(0xFFAED581),
    Color(0xFFF06292),
  ];
  int _paletteIndex = 0;

  static const Color _goldDark = Color(0xFF3D2817);
  static const Color _goldMid = Color(0xFF5C3A1F);
  static const Color _goldDeepest = Color(0xFF2A1810);
  static const Color _goldAccent = Color(0xFFFFD700);
  static const Color _goldLight = Color(0xFFFFF8B0);

  bool get _isBonus => _level.isBonus;

  int get _elapsedForScoring => _elapsedSeconds;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _levelId = widget.levelId;
    _setupLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _setupLevel() {
    _level = ChapterConfig.configFor(_levelId);
    _category = WordRepository.categoryForLevel(_levelId);

    final picked = _pickWords();

    _puzzle = WordSearchGenerator.generate(
      words: picked,
      gridSize: _level.gridSize,
      directions: _level.directions,
      random: Random(),
    );

    if (_puzzle.words.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Bu bölüm için kelime bulunamadı.');
        Navigator.pop(context);
      });
      return;
    }

    _score = 0;
    _elapsedSeconds = 0;
    _remainingTime = _level.timeLimit;
    _completeHandling = false;
    _dragStart = null;
    _dragCurrent = null;
    _currentPath = [];
    _foundPositions.clear();
    _wordColors.clear();
    _paletteIndex = 0;

    _startTimer();
  }

  List<Word> _pickWords() {
    final target = _level.wordCount;
    final rnd = Random();

    final pool = WordRepository.forCategory(_category);
    final inRange = pool
        .where((w) =>
            w.text.length >= _level.minLength &&
            w.text.length <= _level.maxLength &&
            w.text.length <= _level.gridSize)
        .toList()
      ..shuffle(rnd);

    final picked = <Word>[];
    final seen = <String>{};

    for (final w in inRange) {
      if (seen.add(w.text)) {
        picked.add(w);
        if (picked.length >= target) return picked;
      }
    }

    final fallback = pool
        .where((w) => w.text.length <= _level.gridSize)
        .toList()
      ..shuffle(rnd);

    for (final w in fallback) {
      if (seen.add(w.text)) {
        picked.add(w);
        if (picked.length >= target) break;
      }
    }

    if (picked.length < target) {
      final others = WordRepository.categories
          .where((c) => c != _category)
          .toList()
        ..shuffle(rnd);

      for (final cat in others) {
        final extra = WordRepository.forCategory(cat)
            .where((w) =>
                w.text.length >= _level.minLength &&
                w.text.length <= _level.maxLength &&
                w.text.length <= _level.gridSize)
            .toList()
          ..shuffle(rnd);

        for (final w in extra) {
          if (seen.add(w.text)) {
            picked.add(w);
            if (picked.length >= target) return picked;
          }
        }
      }
    }

    return picked;
  }

  void _startTimer() {
    _timer?.cancel();

    if (_isBonus) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remainingTime--;
          if (_remainingTime <= 0) {
            t.cancel();
            _onTimeOut();
          }
        });
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _elapsedSeconds++;
        });
      });
    }
  }

  void _onTimeOut() {
    if (_completeHandling) return;
    _completeHandling = true;
    _timer?.cancel();

    if (_isBonus) {
      _handleBonusTimeout();
      return;
    }
  }

  Future<void> _handleBonusTimeout() async {
    SoundService.instance.playWrong();

    final found = _puzzle.foundWords;
    final total = _puzzle.totalWords;
    final partialScore = _score;
    _sessionEarned += partialScore;
    await _saveProgress();
    if (!mounted) return;

    final shouldShowAd = AdService.instance.registerLevelComplete();
    if (shouldShowAd) {
      final shown = await AdService.instance.showInterstitialIfAvailable();
      if (shown) {
        AdService.instance.markInterstitialShown();
      }
      if (!mounted) return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _BonusTimeoutDialog(
        found: found,
        total: total,
        earned: partialScore,
        onContinue: () {
          Navigator.pop(context);
          if (!mounted) return;
          setState(() {
            _levelId++;
            _setupLevel();
          });
          unawaited(_saveProgress());
        },
      ),
    );
  }

  Future<void> _confirmSkipBonus() async {
    if (_completeHandling) return;

    _timer?.cancel();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1810),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFFFFD700),
            width: 1.5,
          ),
        ),
        title: const Text(
          '👑 Bonus Bölümü Atla',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
        content: const Text(
          'Bu bonus bölümü oynamadan geçebilirsin.\n\n'
          'Bonus bölümü tamamlarsan ekstra yüksek puan alırsın — '
          'ama istemiyorsan direkt sonraki bölüme geçebilirsin.',
          style: TextStyle(
            color: Colors.white70,
            height: 1.4,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Kal, Oynayacağım',
              style: TextStyle(
                color: Colors.white60,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Atla ve Geç',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      _skipBonus();
    } else {
      if (!_completeHandling) {
        _startTimer();
      }
    }
  }

  void _skipBonus() {
    _timer?.cancel();
    SoundService.instance.playTap();

    if (!mounted) return;
    setState(() {
      _levelId++;
      _setupLevel();
    });
    unawaited(_saveProgress());
  }

  void _onPanStart(Offset localPos, double cellSize) {
    if (_completeHandling) return;
    final pos = _posFromLocal(localPos, cellSize);
    if (pos == null) return;
    SoundService.instance.playTap();
    setState(() {
      _dragStart = pos;
      _dragCurrent = pos;
      _currentPath = [pos];
    });
  }

  void _onPanUpdate(Offset localPos, double cellSize) {
    if (_dragStart == null || _completeHandling) return;
    final pos = _posFromLocal(localPos, cellSize);
    if (pos == null || pos == _dragCurrent) return;
    setState(() {
      _dragCurrent = pos;
      _currentPath = _computePath(_dragStart!, pos);
    });
  }

  void _onPanEnd() {
    if (_dragStart == null) return;
    final path = List<WordPosition>.from(_currentPath);
    _checkSelection(path);
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      _currentPath = [];
    });
  }

  void _onPanCancel() {
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      _currentPath = [];
    });
  }

  WordPosition? _posFromLocal(Offset local, double cellSize) {
    final col = (local.dx / cellSize).floor();
    final row = (local.dy / cellSize).floor();
    if (row < 0 ||
        row >= _level.gridSize ||
        col < 0 ||
        col >= _level.gridSize) {
      return null;
    }
    return WordPosition(row, col);
  }

  List<WordPosition> _computePath(WordPosition start, WordPosition end) {
    final dr = end.row - start.row;
    final dc = end.col - start.col;

    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) {
      return [start];
    }

    final steps = max(dr.abs(), dc.abs());
    if (steps == 0) return [start];

    final sr = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
    final sc = dc == 0 ? 0 : (dc > 0 ? 1 : -1);

    final path = <WordPosition>[];
    for (int i = 0; i <= steps; i++) {
      path.add(WordPosition(start.row + sr * i, start.col + sc * i));
    }
    return path;
  }

  void _checkSelection(List<WordPosition> path) {
    if (path.length < 2) return;

    final selected = path.map((p) => _puzzle.grid[p.row][p.col]).join();
    final reversed = selected.split('').reversed.join();

    for (final w in _puzzle.words) {
      if (w.found) continue;
      if (w.text == selected || w.text == reversed) {
        // Aynı kelime gridde tesadüfen başka bir yerde de oluşmuş olabilir;
        // oyuncunun seçtiği yolu geçerli sayıp renklendirmeyi ona göre yap.
        w.positions = w.text == selected ? path : path.reversed.toList();
        _onWordFound(w);
        return;
      }
    }

    SoundService.instance.playWrong();
  }

  void _onWordFound(PlacedWord word) {
    SoundService.instance.playCorrect();
    final color = _foundPalette[_paletteIndex % _foundPalette.length];
    _paletteIndex++;

    final points = _level.pointsForWord(_elapsedForScoring);

    setState(() {
      word.found = true;
      _wordColors[word] = color;
      for (final p in word.positions) {
        _foundPositions.add(p);
      }
      _score += points;
    });

    if (_puzzle.isComplete) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _onLevelComplete();
      });
    }
  }

  void _onLevelComplete() async {
    if (_completeHandling) return;
    _completeHandling = true;
    _timer?.cancel();
    SoundService.instance.playLevelComplete();

    final timeBonus = _isBonus ? _remainingTime * 3 : 0;
    final total = _score + timeBonus;
    _sessionEarned += total;
    await _saveProgress();
    if (!mounted) return;

    final shouldShowAd = AdService.instance.registerLevelComplete();
    if (shouldShowAd) {
      final shown = await AdService.instance.showInterstitialIfAvailable();
      if (shown) {
        AdService.instance.markInterstitialShown();
      }
      if (!mounted) return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => SuccessDialog(
        words: _puzzle.words.map((w) => w.text).toList(),
        basePoints: _score,
        bonusPoints: timeBonus,
        hintPenalty: 0,
        totalPoints: total,
        levelId: _levelId,
        chapter: _level.chapter,
        onNext: () async {
          Navigator.pop(context);
          if (!mounted) return;
          setState(() {
            _levelId++;
            _setupLevel();
          });
          await _saveProgress();
        },
      ),
    );
  }

  Future<void> _saveProgress() async {
    final p = AccountService.current;

    // Bu ekranda kazanılan ve henüz kaydedilmemiş fark.
    // (Eskiden SharedPreferences'ta tutuluyordu; uygulama kapanınca
    // bayat kalıp negatif delta üretebiliyordu.)
    final delta = _sessionEarned - _lastSavedSession;
    _lastSavedSession = _sessionEarned;

    final newTotal = p.totalScore + delta;
    final newHighest = _levelId > p.highestLevel ? _levelId : p.highestLevel;

    await AccountService.save(
      totalScore: newTotal,
      highestLevel: newHighest,
      currentLevel: _levelId,
    );
  }

  Future<void> _exitToMenu() async {
    _timer?.cancel();
    await _saveProgress();
    if (!mounted) return;
    Navigator.pop(context, _sessionEarned);
  }

  @override
  Widget build(BuildContext context) {
    if (_puzzle.grid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exitToMenu();
      },
      child: Scaffold(
        body: AppBackground(
          bonus: _isBonus,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _buildStatsBar(),
                      ),
                      const SizedBox(height: 8),
                      _buildCategoryLabel(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _buildGrid(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildWordList(),
                      const SizedBox(height: 10),
                      _buildHintBar(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
                const BannerAdWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _isBonus
            ? _goldAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isBonus
              ? _goldAccent.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: _isBonus ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isBonus
                ? Icons.workspace_premium_rounded
                : Icons.folder_special_rounded,
            color: _isBonus ? _goldAccent : const Color(0xFF4DD0E1),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              decoration: TextDecoration.none,
            ),
          ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withOpacity(0.2),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _chapterColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _chapterColor().withOpacity(0.5),
              ),
            ),
            child: Text(
              _level.chapter.toUpperCase(),
              style: TextStyle(
                color: _chapterColor(),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _chapterColor() {
    if (_isBonus) return _goldAccent;
    switch (_level.chapter) {
      case 'Çok Kolay':
        return const Color(0xFF7BE495);
      case 'Kolay':
        return const Color(0xFF64B5F6);
      case 'Orta':
        return const Color(0xFFFFB74D);
      case 'Zor':
        return const Color(0xFFFF8A80);
      case 'Çok Zor':
        return const Color(0xFFBA68C8);
      default:
        return const Color(0xFF4DD0E1);
    }
  }

  Color _timerColor() {
    if (_isBonus) {
      return _remainingTime <= 15 ? Colors.redAccent : _goldAccent;
    }
    final steps = _elapsedSeconds ~/ 30;
    switch (steps) {
      case 0:
        return const Color(0xFF7BE495);
      case 1:
        return const Color(0xFFFFD54F);
      case 2:
        return const Color(0xFFFFB74D);
      case 3:
        return const Color(0xFFFF8A80);
      default:
        return Colors.redAccent;
    }
  }

  Widget _buildStatsBar() {
    final found = _puzzle.foundWords;
    final total = _puzzle.totalWords;
    final progress = total == 0 ? 0.0 : found / total;

    final mm = (_isBonus ? _remainingTime ~/ 60 : _elapsedSeconds ~/ 60)
        .toString()
        .padLeft(2, '0');
    final ss = (_isBonus ? _remainingTime % 60 : _elapsedSeconds % 60)
        .toString()
        .padLeft(2, '0');

    final urgent = _isBonus && _remainingTime <= 15;
    final timerColor = _timerColor();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isBonus
              ? const [_goldDark, _goldMid, _goldDeepest]
              : const [
                  Color(0xFF0B1E3F),
                  Color(0xFF1E3A5F),
                  Color(0xFF0A1929),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isBonus
              ? _goldAccent.withOpacity(0.7)
              : const Color(0xFF4DD0E1).withOpacity(0.25),
          width: _isBonus ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isBonus
                ? _goldAccent.withOpacity(0.4)
                : const Color(0xFF0B1E3F).withOpacity(0.7),
            blurRadius: _isBonus ? 28 : 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.06),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isBonus) ...[
            _buildBonusHeader(),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                onPressed: _exitToMenu,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _isBonus ? _goldAccent : Colors.white,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
              _statItem(
                label: 'SKOR',
                value: '$_score',
                icon: Icons.stars_rounded,
                iconColor: _isBonus ? _goldLight : const Color(0xFFFFD54F),
              ),
              _statDivider(),
              _statItem(
                label: 'BULUNAN',
                value: '$found/$total',
                icon: Icons.check_circle_outline_rounded,
                iconColor: _isBonus ? _goldAccent : const Color(0xFF7BE495),
              ),
              _statDivider(),
              _statItem(
                label: _isBonus ? 'SÜRE' : 'KRONOMETRE',
                value: '$mm:$ss',
                icon: _isBonus ? Icons.timer_rounded : Icons.timer_outlined,
                iconColor: timerColor,
                valueColor: timerColor,
                urgent: urgent,
                pulse: _pulse,
              ),
              _statDivider(),
              _statItem(
                label: 'BÖLÜM',
                value: '$_levelId',
                icon: Icons.military_tech_rounded,
                iconColor: _isBonus ? _goldLight : const Color(0xFFBA68C8),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Colors.white.withOpacity(0.08),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isBonus
                            ? const [
                                _goldAccent,
                                _goldLight,
                                _goldAccent,
                              ]
                            : const [
                                Color(0xFF4DD0E1),
                                Color(0xFF7BE495),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isBonus
                              ? _goldAccent.withOpacity(0.8)
                              : const Color(0xFF4DD0E1),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusHeader() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final scale = 1 + _pulse.value * 0.04;
        return Transform.scale(scale: scale, child: child);
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '👑',
            style: TextStyle(
              fontSize: 18,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'BONUS BÖLÜM',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              decoration: TextDecoration.none,
              shadows: [
                Shadow(
                  color: Color(0x80FFD700),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '👑',
            style: TextStyle(
              fontSize: 18,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ DÜZELTİLDİ: `pulse` parametresi eklendi, animasyon `Expanded`'ın
  /// İÇİNE taşındı (dışına değil). Böylece `Expanded`'ın parent'ı her zaman
  /// `Row` kalır ve ParentDataWidget hatası oluşmaz.
  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
    Color iconColor = Colors.white70,
    Color? valueColor,
    bool urgent = false,
    Animation<double>? pulse,
  }) {
    Widget content = Column(
      children: [
        Icon(
          icon,
          color: urgent ? Colors.redAccent : iconColor,
          size: 14,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: urgent ? Colors.redAccent : (valueColor ?? Colors.white),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
            shadows: urgent
                ? [
                    const Shadow(
                      color: Colors.redAccent,
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );

    // Pulse varsa animasyonu Column'un İÇİNE koy (Expanded'ın dışına değil!)
    if (pulse != null) {
      content = AnimatedBuilder(
        animation: pulse,
        builder: (_, child) {
          final scale = urgent ? 1 + pulse.value * 0.08 : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: content,
      );
    }

    return Expanded(child: content);
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 30,
      color: _isBonus
          ? _goldAccent.withOpacity(0.3)
          : Colors.white.withOpacity(0.12),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        const innerPadding = 6.0;
        final usable = size - innerPadding * 2;
        final cellSize = usable / _level.gridSize;

        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isBonus
                    ? [
                        _goldAccent.withOpacity(0.1),
                        _goldAccent.withOpacity(0.03),
                      ]
                    : [
                        Colors.white.withOpacity(0.06),
                        Colors.white.withOpacity(0.02),
                      ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isBonus
                    ? _goldAccent.withOpacity(0.55)
                    : Colors.white.withOpacity(0.1),
                width: _isBonus ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isBonus
                      ? _goldAccent.withOpacity(0.25)
                      : Colors.black.withOpacity(0.4),
                  blurRadius: _isBonus ? 30 : 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(innerPadding),
            child: GestureDetector(
              onPanStart: (d) => _onPanStart(d.localPosition, cellSize),
              onPanUpdate: (d) => _onPanUpdate(d.localPosition, cellSize),
              onPanEnd: (_) => _onPanEnd(),
              onPanCancel: _onPanCancel,
              child: Stack(
                children: [
                  for (int r = 0; r < _level.gridSize; r++)
                    for (int c = 0; c < _level.gridSize; c++)
                      Positioned(
                        left: c * cellSize,
                        top: r * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: _buildCell(r, c, cellSize),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color? _colorForPosition(WordPosition pos) {
    for (final entry in _wordColors.entries) {
      if (entry.key.positions.contains(pos)) return entry.value;
    }
    return null;
  }

  Widget _buildCell(int r, int c, double cellSize) {
    final pos = WordPosition(r, c);
    final inCurrentPath = _currentPath.contains(pos);
    final foundColor = _colorForPosition(pos);
    final isFound = foundColor != null;

    Color? bgColor;
    Color textColor = Colors.white;
    List<BoxShadow>? shadows;
    Border? border;

    if (inCurrentPath) {
      bgColor = _isBonus ? _goldAccent : const Color(0xFF4DD0E1);
      textColor = const Color(0xFF0A1929);
      shadows = [
        BoxShadow(
          color: (_isBonus ? _goldAccent : const Color(0xFF4DD0E1))
              .withOpacity(0.75),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ];
    } else if (isFound) {
      bgColor = foundColor;
      textColor = Colors.white;
      shadows = [
        BoxShadow(
          color: foundColor.withOpacity(0.5),
          blurRadius: 8,
          spreadRadius: 0.5,
        ),
      ];
    } else {
      bgColor = _isBonus
          ? _goldAccent.withOpacity(0.05)
          : Colors.white.withOpacity(0.06);
      border = Border.all(
        color: _isBonus
            ? _goldAccent.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
        width: 1,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(1.2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(7),
          border: border,
          boxShadow: shadows,
        ),
        alignment: Alignment.center,
        child: Text(
          _puzzle.grid[r][c],
          style: TextStyle(
            fontSize: cellSize * 0.42,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildWordList() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _puzzle.words.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final w = _puzzle.words[i];
          final found = w.found;
          final color = _wordColors[w] ?? Colors.white;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              gradient: found
                  ? LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    )
                  : null,
              color: found
                  ? null
                  : (_isBonus
                      ? _goldAccent.withOpacity(0.08)
                      : Colors.white.withOpacity(0.06)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: found
                    ? color
                    : (_isBonus
                        ? _goldAccent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.15)),
                width: 1.5,
              ),
              boxShadow: found
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (found) ...[
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                ] else ...[
                  Icon(
                    Icons.circle_outlined,
                    color: _isBonus
                        ? _goldAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.4),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  w.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    decoration: found
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: Colors.white,
                    decorationThickness: 2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHintBar() {
    final remaining = _puzzle.totalWords - _puzzle.foundWords;
    final hasDecay = _level.scoreDecayStep > 0;
    final currentPoints = _level.pointsForWord(_elapsedForScoring);
    final isDiscounted = currentPoints < _level.basePoints;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isBonus
                    ? _goldAccent.withOpacity(0.1)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isBonus
                      ? _goldAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDecay && !_isBonus) ...[
                    Icon(
                      isDiscounted
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: isDiscounted
                          ? const Color(0xFFFF8A80)
                          : const Color(0xFF7BE495),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$currentPoints puan/kelime',
                      style: TextStyle(
                        color: isDiscounted
                            ? const Color(0xFFFF8A80)
                            : const Color(0xFF7BE495),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 1,
                      height: 14,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                    Icons.touch_app_rounded,
                    color: _isBonus ? _goldAccent : const Color(0xFF4DD0E1),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sürükle',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 14,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$remaining kelime kaldı',
                    style: TextStyle(
                      color: _isBonus ? _goldAccent : const Color(0xFF4DD0E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isBonus)
            Positioned(
              right: 0,
              child: TextButton.icon(
                onPressed: _confirmSkipBonus,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 14,
                ),
                label: const Text(
                  'Atla',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD700),
                  backgroundColor: _goldAccent.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bonus bölümde süre dolunca gösterilen altın temalı bilgi diyaloğu
class _BonusTimeoutDialog extends StatefulWidget {
  final int found;
  final int total;
  final int earned;
  final VoidCallback onContinue;

  const _BonusTimeoutDialog({
    required this.found,
    required this.total,
    required this.earned,
    required this.onContinue,
  });

  @override
  State<_BonusTimeoutDialog> createState() => _BonusTimeoutDialogState();
}

class _BonusTimeoutDialogState extends State<_BonusTimeoutDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _entry,
          curve: Curves.elasticOut,
        ),
        child: FadeTransition(
          opacity: _entry,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3D2817),
                  Color(0xFF2A1810),
                  Color(0xFF1A0F08),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFFFF8B0),
                          Color(0xFFFFD700),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '⏰',
                      style: TextStyle(
                        fontSize: 40,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'BONUS SÜRESİ DOLDU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x80FFD700),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ama merak etme, yine de devam ediyorsun!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statBox(
                          label: 'Bulunan',
                          value: '${widget.found}/${widget.total}',
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        _statBox(
                          label: 'Kazanılan',
                          value: '+${widget.earned}',
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onContinue,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFFFFD700).withOpacity(0.5),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFFFA726),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          height: 52,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'DEVAM ET',
                                style: TextStyle(
                                  color: Color(0xFF1A0F08),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF1A0F08),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFFFFD700) : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
