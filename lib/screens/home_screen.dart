import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_level.dart';
import '../services/account_service.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/crossword_progress.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/ui_kit.dart';
import 'category_screen.dart';
import 'crossword_screen.dart';
import 'game_screen.dart';
import 'word_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentLevel = 1;
  int _totalScore = 0;
  int _highestLevel = 1;
  String _nickname = '';
  bool _dailyRewardAvailable = false;
  bool _soundOn = true;
  bool _claimingReward = false;
  StreamSubscription<dynamic>? _authSub;

  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadProgress();

    _authSub = AuthService.instance.authStateChanges.listen((_) async {
      await AccountService.idle;
      if (mounted) await _loadProgress();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final p = await AccountService.refresh();
    if (!mounted) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    setState(() {
      _totalScore = p.totalScore;
      _highestLevel = p.highestLevel;
      _currentLevel = p.currentLevel;
      _nickname = p.nickname;
      _dailyRewardAvailable = p.lastDailyReward != today;
      _soundOn = SoundService.instance.enabled;
    });
  }

  Future<void> _claimDailyReward() async {
    if (_claimingReward) return;
    setState(() => _claimingReward = true);

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      SoundService.instance.playTap();

      final earned = await AdService.instance.showRewardedIfAvailable();
      if (!mounted) return;

      if (!earned) {
        AppSnackBar.warning(
          context,
          'Ödül alınamadı. Reklam yüklenemedi veya tamamlanmadı.',
        );
        return;
      }

      SoundService.instance.playCorrect();
      final newTotal = _totalScore + 100;

      await AccountService.save(
        totalScore: newTotal,
        highestLevel: _highestLevel,
        currentLevel: _currentLevel,
        lastDailyReward: today,
      );

      if (!mounted) return;
      setState(() {
        _totalScore = newTotal;
        _dailyRewardAvailable = false;
      });

      AppSnackBar.reward(context, 'Günlük ödül: +100 puan!');
    } finally {
      if (mounted) setState(() => _claimingReward = false);
    }
  }

  Future<void> _startWordSearch() async {
    SoundService.instance.playTap();
    await Navigator.push<int>(
      context,
      MaterialPageRoute(
          builder: (_) => WordSearchScreen(levelId: _currentLevel)),
    );
    await _loadProgress();
  }

  Future<void> _startGuessWord() async {
    SoundService.instance.playTap();
    await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(levelId: _currentLevel)),
    );
    await _loadProgress();
  }

  Future<void> _startCrossword() async {
    SoundService.instance.playTap();
    final level = await CrosswordProgress.getLevel();
    if (!mounted) return;
    await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => CrosswordScreen(levelId: level)),
    );
    await _loadProgress();
  }

  Future<void> _toggleSound() async {
    await SoundService.instance.toggle();
    if (!mounted) return;
    setState(() => _soundOn = SoundService.instance.enabled);
    AppSnackBar.info(context, _soundOn ? 'Ses açıldı' : 'Ses kapatıldı');
  }

  void _openCategories() {
    SoundService.instance.playTap();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryScreen()),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          children: [
            _buildTopBar(),
            const SizedBox(height: 18),
            _buildTitle(),
            const SizedBox(height: 20),
            _buildLevelCard(),
            if (_dailyRewardAvailable) ...[
              const SizedBox(height: 12),
              _buildDailyReward(),
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildModeCard(
                    emoji: '🎯',
                    title: 'KELİME AVI',
                    subtitle: 'Izgarada kelimeleri bul',
                    gradient: AppGradients.violet,
                    glow: AppColors.violet,
                    onTap: _startWordSearch,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildModeCard(
                    emoji: '🔤',
                    title: 'KELİMEYİ BİL',
                    subtitle: 'Harfleri sıraya diz',
                    gradient: AppGradients.coral,
                    glow: AppColors.coral,
                    onTap: _startGuessWord,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildCrosswordCard(),
          ],
        ),
      ),
    );
  }

  // ==================== ÜST BAR ====================

  Widget _buildTopBar() {
    final name = _nickname.trim().isEmpty ? 'Usta' : _nickname.trim();
    return Row(
      children: [
        AvatarBubble(name: name, size: 38, ring: AppColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        GlassIconButton(
          icon: Icons.auto_stories_rounded,
          color: Colors.white70,
          size: 38,
          onTap: _openCategories,
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: _soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: _soundOn ? AppColors.gold : Colors.white38,
          size: 38,
          onTap: _toggleSound,
        ),
      ],
    );
  }

  // ==================== BAŞLIK ====================

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: const [
            Color(0xFFFFC857),
            Color(0xFFFFF3C4),
            Color(0xFFFF9F1C),
          ],
          stops: [0.0, _shimmer.value.clamp(0.0, 1.0), 1.0],
        ).createShader(bounds),
        child: child,
      ),
      child: const Text(
        'KELİME USTASI',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          height: 1.1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // ==================== BÖLÜM KARTI ====================

  Widget _buildLevelCard() {
    final isBonus = ChapterConfig.isBonusLevel(_currentLevel);
    final cfg = ChapterConfig.configFor(_currentLevel);
    final accent = isBonus ? AppColors.gold : AppColors.chapter(cfg.chapter);
    final pos = (_currentLevel - 1) % ChapterConfig.bonusInterval;
    final progress = isBonus ? 1.0 : (pos + 1) / ChapterConfig.bonusInterval;
    final toBonus = ChapterConfig.bonusInterval -
        (_currentLevel % ChapterConfig.bonusInterval);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withOpacity(0.10),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                    Text(
                      '$_currentLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (isBonus ? 'BONUS' : cfg.chapter).toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isBonus
                          ? 'Sıradaki bölüm BONUS! 👑'
                          : '$toBonus bölüm sonra BONUS 👑',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _inlineStat(
                  Icons.stars_rounded,
                  '$_totalScore puan',
                  AppColors.cyan,
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: Colors.white.withOpacity(0.12),
              ),
              Expanded(
                child: _inlineStat(
                  Icons.local_fire_department_rounded,
                  'Rekor $_highestLevel',
                  AppColors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inlineStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== GÜNLÜK ÖDÜL ====================

  Widget _buildDailyReward() {
    return Pressable(
      onTap: _claimingReward ? null : _claimDailyReward,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppGradients.gold,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _claimingReward
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.ink,
                    ),
                  )
                : const Text('🎁', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _claimingReward
                    ? 'Reklam yükleniyor...'
                    : 'Günlük ödül: reklam izle',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const Text(
              '+100',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MOD KARTLARI ====================

  Widget _buildModeCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 34,
                    decoration: TextDecoration.none,
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: glow, size: 24),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11.5,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== KELİME GEZMECE KARTI ====================

  Widget _buildCrosswordCard() {
    return Pressable(
      onTap: _startCrossword,
      pressedScale: 0.97,
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5BE3F5), Color(0xFF2A8FD6)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              alignment: Alignment.center,
              child: const Text('🧩', style: TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KELİME GEZMECE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Harfleri birleştir, bulmacayı çöz',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF2A8FD6),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
