import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/word_repository.dart';
import '../models/game_level.dart';
import '../models/word.dart';
import '../services/account_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/ui_kit.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/letter_tile.dart';
import '../widgets/success_dialog.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  const GameScreen({super.key, required this.levelId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int _wordsPerLevel = 3;
  static const int _hintLimit = 3;
  static const int _hintCost = 5;
  static const int _retryGraceSeconds = 30;

  late int _levelId;
  late GameLevel _level;
  late List<Word> _levelWords;

  late List<List<String>> _wordLetters;
  late List<List<int?>> _placements;
  late List<Set<int>> _usedTiles;
  late List<bool> _solved;

  /// Her kelime için baştan kaç harf kilitli (hazır verilmiş).
  /// Başlangıçta 1 (ilk harf). İpucu kullanıldıkça artar.
  late List<int> _locked;

  int _selectedWordIndex = 0;

  Timer? _timer;
  int _remainingTime = 0;
  int _hintsUsed = 0;
  int _levelEarned = 0;
  int _totalBonusThisLevel = 0;
  int _totalHintPenaltyThisLevel = 0;
  int _sessionEarned = 0;
  bool _levelCompleteHandling = false;
  int _lastSavedSession = 0;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _levelId = widget.levelId;
    _setupLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setupLevel() {
    _level = ChapterConfig.configFor(_levelId);
    _levelWords = _pickLevelWords(_level);

    if (_levelWords.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Bu bölüm için kelime bulunamadı.');
        Navigator.pop(context);
      });
      _wordLetters = [];
      _placements = [];
      _usedTiles = [];
      _solved = [];
      _locked = [];
      return;
    }

    _wordLetters = [];
    _placements = [];
    _usedTiles = [];
    _locked = [];
    _solved = List<bool>.filled(_levelWords.length, false);

    for (final w in _levelWords) {
      final letters = _scramble(w.text);
      final placement = List<int?>.filled(letters.length, null);
      final used = <int>{};

      // İlk harf hazır gelir ve kilitlidir
      final firstTile = letters.indexOf(w.text[0]);
      if (firstTile != -1) {
        placement[0] = firstTile;
        used.add(firstTile);
      }

      _wordLetters.add(letters);
      _placements.add(placement);
      _usedTiles.add(used);
      _locked.add(firstTile != -1 ? 1 : 0);
    }

    _selectedWordIndex = 0;
    _hintsUsed = 0;
    _levelEarned = 0;
    _totalBonusThisLevel = 0;
    _totalHintPenaltyThisLevel = 0;
    _levelCompleteHandling = false;

    _startLevelTimer();
  }

  /// Harfleri karıştırır; mümkünse sonuç doğru kelimeyle aynı çıkmaz.
  List<String> _scramble(String text) {
    final letters = text.split('');
    if (letters.toSet().length <= 1) return letters;
    final rnd = Random();
    List<String> result;
    int guard = 0;
    do {
      result = [...letters]..shuffle(rnd);
      guard++;
    } while (result.join() == text && guard < 20);
    return result;
  }

  List<Word> _pickLevelWords(GameLevel level) {
    final pool = WordRepository.forChapter(level.chapter);

    var source = pool
        .where((w) =>
            w.text.length >= level.minLength &&
            w.text.length <= level.maxLength)
        .toList();

    if (source.isEmpty) {
      source = WordRepository.all
          .where((w) =>
              w.text.length >= level.minLength &&
              w.text.length <= level.maxLength)
          .toList();
    }
    if (source.isEmpty) {
      source = WordRepository.all.toList();
    }
    if (source.isEmpty) return const [];

    final rnd = Random();
    final shuffled = [...source]..shuffle(rnd);

    final unique = <String>{};
    final picked = <Word>[];
    for (final w in shuffled) {
      if (unique.add(w.text)) {
        picked.add(w);
        if (picked.length >= _wordsPerLevel) break;
      }
    }
    while (picked.length < _wordsPerLevel) {
      picked.add(source[rnd.nextInt(source.length)]);
    }
    return picked;
  }

  void _startLevelTimer({int? startFrom}) {
    _timer?.cancel();
    if (_level.timeLimit <= 0) {
      // Süre sınırı yok → kronometre (puan azalması için)
      _elapsedSeconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsedSeconds++);
      });
      return;
    }
    _remainingTime = startFrom ?? _level.timeLimit;
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
  }

  void _onTimeOut() {
    _timer?.cancel();
    final wIdx = _selectedWordIndex;
    if (_solved.isEmpty || _solved[wIdx]) return;
    final correct = _levelWords[wIdx].text;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '⏰ Süre Doldu!',
          style: TextStyle(
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Doğru cevap:',
              style: TextStyle(
                color: Colors.white60,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              correct,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _retryCurrentWord();
            },
            child: const Text(
              'Tekrar Dene',
              style: TextStyle(
                color: Colors.amber,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _exitToMenu();
            },
            child: const Text(
              'Çık',
              style: TextStyle(
                color: Colors.white54,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kilitli olmayan tüm harfleri geri alır.
  void _clearUnlocked(int wIdx) {
    final row = _placements[wIdx];
    for (int i = _locked[wIdx]; i < row.length; i++) {
      if (row[i] != null) {
        _usedTiles[wIdx].remove(row[i]);
        row[i] = null;
      }
    }
  }

  void _retryCurrentWord() {
    final wIdx = _selectedWordIndex;
    if (_solved.isEmpty || _solved[wIdx]) return;
    setState(() => _clearUnlocked(wIdx));
    _startLevelTimer(startFrom: _retryGraceSeconds);
  }

  void _selectWord(int wIdx) {
    if (_solved[wIdx]) return;
    if (_selectedWordIndex == wIdx) return;
    SoundService.instance.playTap();
    setState(() => _selectedWordIndex = wIdx);
  }

  void _onLetterTap(int tileIndex) {
    final wIdx = _selectedWordIndex;
    if (_solved[wIdx]) return;
    if (_usedTiles[wIdx].contains(tileIndex)) return;

    final row = _placements[wIdx];
    final emptyPos = row.indexOf(null);
    if (emptyPos == -1) return;

    SoundService.instance.playTap();

    setState(() {
      row[emptyPos] = tileIndex;
      _usedTiles[wIdx].add(tileIndex);
    });

    if (!row.contains(null)) {
      _checkActiveWord(wIdx);
    }
  }

  void _checkActiveWord(int wIdx) {
    final row = _placements[wIdx];
    final guess = row.map((i) => i == null ? '' : _wordLetters[wIdx][i]).join();

    if (guess == _levelWords[wIdx].text) {
      _onWordSolved(wIdx);
    } else {
      SoundService.instance.playWrong();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (wIdx >= _placements.length || _solved[wIdx]) return;
        setState(() => _clearUnlocked(wIdx));
      });
    }
  }

  void _onWordSolved(int wIdx) {
    SoundService.instance.playCorrect();

    final elapsed = _level.timeLimit > 0
        ? _level.timeLimit - _remainingTime
        : _elapsedSeconds;
    final wordPoints = _level.pointsForWord(elapsed);
    _levelEarned += wordPoints;

    setState(() {
      _solved[wIdx] = true;
      final next = _solved.indexWhere((s) => !s);
      if (next != -1) _selectedWordIndex = next;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_solved.every((s) => s)) {
        _onLevelComplete();
      }
    });
  }

  void _onLevelComplete() async {
    if (_levelCompleteHandling) return;
    _levelCompleteHandling = true;
    _timer?.cancel();
    // ⚠️ Level up sesi buradan kaldırıldı — dialog ile senkronize edilecek

    final total = _levelEarned.clamp(1, 999999);

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
        words: _levelWords.map((w) => w.text).toList(),
        basePoints: total,
        bonusPoints: 0,
        hintPenalty: _totalHintPenaltyThisLevel,
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

    // 🎵 Tebrik kartı açılırken level up sesi çalsın
    SoundService.instance.playLevelComplete();
  }

  /// Havuzda, henüz kullanılmamış ve verilen harfe sahip karoyu bulur.
  int? _findFreeTile(int wIdx, String letter) {
    final pool = _wordLetters[wIdx];
    for (int i = 0; i < pool.length; i++) {
      if (pool[i] == letter && !_usedTiles[wIdx].contains(i)) return i;
    }
    return null;
  }

  /// İpucu: sıradaki doğru harfi açar ve kilitler.
  /// (Kategori artık her zaman görünür olduğu için ipucu harf açar.)
  void _useHint() {
    if (!_level.hasHint) return;
    if (_hintsUsed >= _hintLimit) return;
    final wIdx = _selectedWordIndex;
    if (_solved[wIdx]) return;

    final target = _levelWords[wIdx].text;
    final locked = _locked[wIdx];
    if (locked >= target.length) return;

    SoundService.instance.playHint();

    final actualPenalty = _levelEarned >= _hintCost ? _hintCost : _levelEarned;

    setState(() {
      _hintsUsed++;
      _totalHintPenaltyThisLevel += actualPenalty;
      _levelEarned -= actualPenalty;

      // Kilitsiz harfleri temizle, sıradaki doğru harfi yerleştir
      _clearUnlocked(wIdx);
      final tile = _findFreeTile(wIdx, target[locked]);
      if (tile != null) {
        _placements[wIdx][locked] = tile;
        _usedTiles[wIdx].add(tile);
        _locked[wIdx] = locked + 1;
      }
    });

    AppSnackBar.hint(context, 'Bir harf açıldı');

    if (!_placements[wIdx].contains(null)) {
      _checkActiveWord(wIdx);
    }
  }

  void _shuffleLetters() {
    final wIdx = _selectedWordIndex;
    if (_solved[wIdx]) return;

    final pool = _wordLetters[wIdx];
    final n = pool.length;
    if (n <= 1) return;

    SoundService.instance.playShuffle();

    final rnd = Random();
    final newPool = [...pool];
    final mapping = List<int>.generate(n, (i) => i);

    for (int i = n - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      if (i == j) continue;
      final tmpL = newPool[i];
      newPool[i] = newPool[j];
      newPool[j] = tmpL;
      final tmpM = mapping[i];
      mapping[i] = mapping[j];
      mapping[j] = tmpM;
    }

    final reverse = List<int>.generate(n, (i) => 0);
    for (int i = 0; i < n; i++) {
      reverse[mapping[i]] = i;
    }

    setState(() {
      final row = _placements[wIdx];
      for (int k = 0; k < row.length; k++) {
        final old = row[k];
        if (old != null) row[k] = reverse[old];
      }
      _usedTiles[wIdx] = _usedTiles[wIdx].map((old) => reverse[old]).toSet();
      _wordLetters[wIdx] = newPool;
    });
  }

  void _clearActiveWord() {
    final wIdx = _selectedWordIndex;
    if (_solved[wIdx]) return;
    SoundService.instance.playTap();
    setState(() => _clearUnlocked(wIdx));
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
    if (_levelWords.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
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
          bonus: _level.isBonus,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: _buildTopRow(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                        child: _buildProgress(),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildWordSlots(),
                        ),
                      ),
                      _buildBottomPanel(),
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

  // ==================== ÜST BAR ====================

  Widget _buildTopRow() {
    final chapterColor = AppColors.chapter(_level.chapter);
    final decayPoints = _level.pointsForWord(_elapsedSeconds);
    final discounted = decayPoints < _level.basePoints;

    return Row(
      children: [
        GlassIconButton(icon: Icons.close_rounded, onTap: _exitToMenu),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BÖLÜM $_levelId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: chapterColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chapterColor.withOpacity(0.5)),
                ),
                child: Text(
                  _level.chapter.toUpperCase(),
                  style: TextStyle(
                    color: chapterColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        InfoPill(
          leading: const Text('💰', style: TextStyle(fontSize: 13)),
          text: '+$_levelEarned',
          color: AppColors.gold,
        ),
        if (_level.timeLimit > 0) ...[
          const SizedBox(width: 8),
          InfoPill(
            leading: Icon(
              Icons.timer_rounded,
              size: 15,
              color: _remainingTime <= 10 ? Colors.redAccent : AppColors.cyan,
            ),
            text: '$_remainingTime sn',
            color: _remainingTime <= 10 ? Colors.redAccent : AppColors.cyan,
          ),
        ] else if (_level.scoreDecayStep > 0) ...[
          const SizedBox(width: 8),
          InfoPill(
            leading: Icon(
              discounted
                  ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded,
              size: 15,
              color: discounted ? const Color(0xFFFF8A80) : AppColors.mint,
            ),
            text: '$decayPoints',
            color: discounted ? const Color(0xFFFF8A80) : AppColors.mint,
          ),
        ],
      ],
    );
  }

  Widget _buildProgress() {
    final done = _solved.where((s) => s).length;
    final total = _solved.length;
    final frac = total == 0 ? 0.0 : done / total;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: frac),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: const AlwaysStoppedAnimation(AppColors.mint),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$done/$total',
          style: const TextStyle(
            color: AppColors.mint,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  // ==================== KELİME KUTULARI ====================

  Widget _buildWordSlots() {
    return Column(
      children: List.generate(_levelWords.length, (wIdx) {
        final word = _levelWords[wIdx];
        final isSolved = _solved[wIdx];
        final isActive = _selectedWordIndex == wIdx;
        final row = _placements[wIdx];
        final lockedCount = _locked[wIdx];

        final accent = isSolved
            ? AppColors.mint
            : isActive
                ? AppColors.gold
                : Colors.white24;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: GestureDetector(
            onTap: () => _selectWord(wIdx),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(isSolved || isActive ? 0.16 : 0.07),
                    accent.withOpacity(isSolved || isActive ? 0.04 : 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSolved || isActive
                      ? accent.withOpacity(0.75)
                      : Colors.white.withOpacity(0.10),
                  width: isActive ? 2 : 1.2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withOpacity(0.22),
                          blurRadius: 18,
                          spreadRadius: -1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${wIdx + 1}. KELİME',
                        style: TextStyle(
                          color: isSolved || isActive ? accent : Colors.white38,
                          fontSize: 10.5,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _categoryChip(word.category, isSolved, isActive),
                      const SizedBox(width: 6),
                      if (isSolved)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.mint, size: 15)
                      else if (isActive)
                        const Icon(Icons.touch_app_rounded,
                            color: AppColors.gold, size: 15),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: List.generate(word.text.length, (i) {
                      final tileIdx = row[i];
                      final letter =
                          tileIdx != null ? _wordLetters[wIdx][tileIdx] : '';
                      return _buildSlot(
                        letter,
                        isSolved,
                        isActive,
                        locked: i < lockedCount,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Kelimenin kategorisini gösteren küçük etiket (her zaman görünür).
  Widget _categoryChip(String category, bool isSolved, bool isActive) {
    final color = isSolved
        ? AppColors.mint
        : isActive
            ? AppColors.cyan
            : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildSlot(
    String letter,
    bool isSolved,
    bool isActive, {
    bool locked = false,
  }) {
    final filled = letter.isNotEmpty;
    final isLockedHint = locked && !isSolved && filled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 34,
      height: 44,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: isSolved
            ? AppGradients.mint
            : isLockedHint
                ? AppGradients.cyan
                : filled
                    ? AppGradients.gold
                    : null,
        color: (!isSolved && !filled)
            ? Colors.white.withOpacity(isActive ? 0.09 : 0.04)
            : null,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isSolved
              ? Colors.white.withOpacity(0.5)
              : filled
                  ? Colors.white.withOpacity(0.5)
                  : isActive
                      ? AppColors.gold.withOpacity(0.6)
                      : Colors.white.withOpacity(0.14),
          width: filled || isSolved ? 1.4 : 1.2,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: (isSolved
                          ? AppColors.mint
                          : isLockedHint
                              ? AppColors.cyan
                              : AppColors.gold)
                      .withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: filled ? AppColors.ink : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // ==================== ALT PANEL ====================

  Widget _buildBottomPanel() {
    final wIdx = _selectedWordIndex;
    final pool = _wordLetters[wIdx];
    final used = _usedTiles[wIdx];
    final isSolved = _solved[wIdx];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${wIdx + 1}. KELİMENİN HARFLERİ',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          if (isSolved)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '✓ Bu kelime çözüldü',
                style: TextStyle(
                  color: AppColors.mint,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(pool.length, (i) {
                final isUsed = used.contains(i);
                return LetterTile(
                  letter: pool[i],
                  selected: isUsed,
                  used: isUsed,
                  onTap: isUsed ? null : () => _onLetterTap(i),
                );
              }),
            ),
          const SizedBox(height: 10),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final hintEnabled = _level.hasHint && _hintsUsed < _hintLimit;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(
          icon: Icons.lightbulb_rounded,
          label: 'İpucu ($_hintsUsed/$_hintLimit)',
          gradient: AppGradients.gold,
          glow: AppColors.goldDeep,
          badge: hintEnabled ? '-$_hintCost' : null,
          onTap: hintEnabled ? _useHint : null,
        ),
        _actionButton(
          icon: Icons.shuffle_rounded,
          label: 'Karıştır',
          gradient: AppGradients.violet,
          glow: AppColors.violet,
          onTap: _shuffleLetters,
        ),
        _actionButton(
          icon: Icons.backspace_rounded,
          label: 'Sil',
          gradient: AppGradients.coral,
          glow: AppColors.coral,
          onTap: _clearActiveWord,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required Color glow,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap != null ? 1 : 0.35,
      child: Pressable(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: gradient == AppGradients.gold
                        ? AppColors.ink
                        : Colors.white,
                    size: 26,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
