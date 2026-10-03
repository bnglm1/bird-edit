import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_level.dart';
import '../services/account_service.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/ui_kit.dart';
import 'category_screen.dart';
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
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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
    _float.dispose();
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
      MaterialPageRoute(builder: (_) => WordSearchScreen(levelId: _currentLevel)),
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

  Future<void> _toggleSound() async {
    await SoundService.instance.toggle();
    if (!mounted) return;
    setState(() => _soundOn = SoundService.instance.enabled);
    AppSnackBar.info(context, _soundOn ? 'Ses açıldı' : 'Ses kapatıldı');
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            _buildTopBar(),
            const SizedBox(height: 14),
            _buildTitle(),
            const SizedBox(height: 22),
            _buildLevelHero(),
            const SizedBox(height: 24),
            _sectionLabel('OYUN MODLARI'),
            const SizedBox(height: 12),
            _buildModeCard(
              emoji: '🎯',
              title: 'KELİME AVI',
              subtitle: 'Harf ızgarasında gizli kelimeleri bul',
              gradient: AppGradients.violet,
              glow: AppColors.violet,
              onTap: _startWordSearch,
              floating: true,
            ),
            const SizedBox(height: 14),
            _buildModeCard(
              emoji: '🔤',
              title: 'KELİMEYİ BİL',
              subtitle: 'Karışık harflerden kelimeyi oluştur',
              gradient: AppGradients.coral,
              glow: AppColors.coral,
              onTap: _startGuessWord,
            ),
            if (_dailyRewardAvailable) ...[
              const SizedBox(height: 22),
              _buildDailyReward(),
            ],
            const SizedBox(height: 14),
            _buildBottomRow(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            gradient: AppGradients.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  // ==================== ÜST BAR ====================

  Widget _buildTopBar() {
    final name = _nickname.trim().isEmpty ? 'Usta' : _nickname.trim();
    return Row(
      children: [
        AvatarBubble(name: name, size: 44, ring: AppColors.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hoş geldin,',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        GlassIconButton(
          icon: _soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: _soundOn ? AppColors.gold : Colors.white38,
          onTap: _toggleSound,
        ),
      ],
    );
  }

  // ==================== BAŞLIK ====================

  Widget _buildTitle() {
    return Column(
      children: [
        AnimatedBuilder(
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              height: 1.1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kelimeleri fethetmeye hazır mısın?',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  // ==================== BÖLÜM KARTI ====================

  Widget _buildLevelHero() {
    final isBonus = ChapterConfig.isBonusLevel(_currentLevel);
    final cfg = ChapterConfig.configFor(_currentLevel);
    final accent = isBonus ? AppColors.gold : AppColors.chapter(cfg.chapter);
    final pos = (_currentLevel - 1) % ChapterConfig.bonusInterval;
    final progress =
        isBonus ? 1.0 : (pos + 1) / ChapterConfig.bonusInterval;
    final toBonus =
        ChapterConfig.bonusInterval - (_currentLevel % ChapterConfig.bonusInterval);

    return GlassCard(
      glow: accent,
      borderColor: accent.withOpacity(0.35),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
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
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withOpacity(0.10),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBonus ? '👑' : 'BÖLÜM',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: isBonus ? 16 : 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          '$_currentLevel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withOpacity(0.5)),
                      ),
                      child: Text(
                        (isBonus ? 'BONUS' : cfg.chapter).toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBonus
                          ? 'Sıradaki bölüm BONUS!\nYüksek puan seni bekliyor.'
                          : '$toBonus bölüm sonra BONUS 👑',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.35,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  Icons.stars_rounded,
                  'PUAN',
                  '$_totalScore',
                  AppColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat(
                  Icons.local_fire_department_rounded,
                  'REKOR',
                  'Bölüm $_highestLevel',
                  AppColors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    bool floating = false,
  }) {
    final card = Container(
      height: 108,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.40),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -28,
              child: _circle(120, 0.10),
            ),
            Positioned(
              right: 50,
              bottom: -36,
              child: _circle(80, 0.08),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 32,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
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
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: glow, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: floating
          ? AnimatedBuilder(
              animation: _float,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -_float.value * 3),
                child: child,
              ),
              child: card,
            )
          : card,
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  // ==================== GÜNLÜK ÖDÜL ====================

  Widget _buildDailyReward() {
    return Pressable(
      onTap: _claimingReward ? null : _claimDailyReward,
      child: AnimatedBuilder(
        animation: _float,
        builder: (_, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppGradients.gold,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.30 + _float.value * 0.25),
                blurRadius: 18 + _float.value * 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _claimingReward
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.ink,
                      ),
                    )
                  : const Text('🎁', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _claimingReward ? 'REKLAM YÜKLENİYOR...' : 'GÜNLÜK ÖDÜL',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kısa bir reklam izle, puanını al',
                    style: TextStyle(
                      color: AppColors.ink.withOpacity(0.7),
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '+100',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ALT ====================

  Widget _buildBottomRow() {
    return Center(
      child: Pressable(
        onTap: () {
          SoundService.instance.playTap();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_rounded,
                  color: AppColors.violet, size: 18),
              SizedBox(width: 8),
              Text(
                'Kategorileri Gör',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
