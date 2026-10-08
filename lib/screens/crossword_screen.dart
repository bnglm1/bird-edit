import 'dart:math';

import 'package:flutter/material.dart';

import '../models/crossword_puzzle.dart';
import '../services/crossword_progress.dart';
import '../services/crossword_repository.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/letter_circle.dart';

class CrosswordScreen extends StatefulWidget {
  final int levelId;
  const CrosswordScreen({super.key, required this.levelId});

  @override
  State<CrosswordScreen> createState() => _CrosswordScreenState();
}

class _CrosswordScreenState extends State<CrosswordScreen> {
  late int _levelId;
  late CrosswordPuzzle _puzzle;
  int _levelScore = 0;
  int _sessionScore = 0;
  bool _completeHandling = false;

  @override
  void initState() {
    super.initState();
    _levelId = widget.levelId;
    _setupLevel();
  }

  void _setupLevel() {
    final puzzle = CrosswordRepository.puzzleForLevel(_levelId);
    if (puzzle == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Bulmaca bulunamadı.');
        Navigator.pop(context);
      });
      return;
    }
    _puzzle = puzzle;
    _levelScore = 0;
    _completeHandling = false;
  }

  bool _onWordSubmit(String word) {
    for (final w in _puzzle.words) {
      if (w.found) continue;
      if (w.text == word) {
        SoundService.instance.playCorrect();
        setState(() {
          w.found = true;
          _levelScore += word.length * 10;
        });
        if (_puzzle.isComplete) {
          Future.delayed(const Duration(milliseconds: 400), _onComplete);
        }
        return true;
      }
    }
    SoundService.instance.playWrong();
    return false;
  }

  Future<void> _onComplete() async {
    if (_completeHandling) return;
    _completeHandling = true;
    SoundService.instance.playLevelComplete();

    final bonus = 100;
    final total = _levelScore + bonus;
    _sessionScore += total;

    final currentScore = await CrosswordProgress.getScore();
    await CrosswordProgress.save(
      level: _levelId + 1,
      score: currentScore + total,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _SuccessDialog(
        levelId: _levelId,
        total: total,
        wordCount: _puzzle.totalWords,
        onNext: () async {
          Navigator.pop(context);
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          setState(() {
            _levelId++;
            _setupLevel();
          });
        },
      ),
    );
  }

  Future<void> _exit() async {
    if (!mounted) return;
    Navigator.pop(context, _sessionScore);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exit();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                        child: _buildTopBar(),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildGrid(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTitlePill(),
                      const SizedBox(height: 8),
                      _buildProgressBar(),
                      const SizedBox(height: 10),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: Center(
                            child: LetterCircle(
                              letters: _puzzle.circle,
                              onSubmit: _onWordSubmit,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _exit,
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BULMACA $_levelId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_puzzle.foundWords}/${_puzzle.totalWords} kelime',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 5),
              Text(
                '+$_levelScore',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = min(
          constraints.maxWidth / _puzzle.cols,
          constraints.maxHeight / _puzzle.rows,
        );
        final gridW = cellSize * _puzzle.cols;
        final gridH = cellSize * _puzzle.rows;

        return Center(
          child: SizedBox(
            width: gridW,
            height: gridH,
            child: Stack(
              children: [
                for (int r = 0; r < _puzzle.rows; r++)
                  for (int c = 0; c < _puzzle.cols; c++)
                    if (_puzzle.isActive(r, c))
                      Positioned(
                        left: c * cellSize,
                        top: r * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: _buildCell(r, c),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int r, int c) {
    final revealed = _puzzle.isRevealed(r, c);
    final letter = _puzzle.letterAt(r, c) ?? '';

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: revealed
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5BE3F5), Color(0xFF2A8FD6)],
                )
              : null,
          color: revealed ? null : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: revealed
              ? [
                  BoxShadow(
                    color: const Color(0xFF2A8FD6).withOpacity(0.55),
                    blurRadius: 8,
                    spreadRadius: -1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: revealed
            ? Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTitlePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5BE3F5), Color(0xFF2A8FD6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A8FD6).withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _puzzle.title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress =
        _puzzle.totalWords == 0 ? 0.0 : _puzzle.foundWords / _puzzle.totalWords;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 400),
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF5BE3F5)),
          ),
        ),
      ),
    );
  }
}

// ==================== BAŞARI DİYALOĞU ====================

class _SuccessDialog extends StatefulWidget {
  final int levelId;
  final int total;
  final int wordCount;
  final VoidCallback onNext;

  const _SuccessDialog({
    required this.levelId,
    required this.total,
    required this.wordCount,
    required this.onNext,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
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
        scale: CurvedAnimation(parent: _entry, curve: Curves.elasticOut),
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
                  Color(0xFF0B1E3F),
                  Color(0xFF1E3A5F),
                  Color(0xFF0A1929),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF5BE3F5).withOpacity(0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5BE3F5).withOpacity(0.4),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'BULMACA TAMAM!',
                  style: TextStyle(
                    color: Color(0xFF5BE3F5),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bulmaca ${widget.levelId} • ${widget.wordCount} kelime',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF5BE3F5).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KAZANILAN',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${widget.total}',
                        style: const TextStyle(
                          color: Color(0xFF5BE3F5),
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF5BE3F5).withOpacity(0.6),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5BE3F5), Color(0xFF2A8FD6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'SONRAKİ BULMACA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            decoration: TextDecoration.none,
                          ),
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
    );
  }
}
