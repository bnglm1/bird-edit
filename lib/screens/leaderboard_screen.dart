import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'auth_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends State<LeaderboardScreen> {
  /// 30 dakikada bir otomatik yenile
  static const Duration _refreshInterval = Duration(minutes: 30);

  late Future<List<LeaderboardEntry>> _future;
  int? _myRank;
  Timer? _refreshTimer;
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();

    _authSub = AuthService.instance.authStateChanges.listen((_) {
      if (mounted) _load();
    });

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// Dışarıdan (sekme değişince) tazeleme için
  void reload() {
    if (mounted) _load();
  }

  void _load() {
    if (!AuthService.instance.isSignedIn) {
      setState(() {
        _future = Future.value(const []);
        _myRank = null;
      });
      return;
    }

    setState(() {
      _future = FirestoreService.instance.fetchTop();
    });
    FirestoreService.instance.fetchMyRank().then((r) {
      if (mounted) setState(() => _myRank = r);
    });
  }

  Future<void> _silentRefresh() async {
    if (!AuthService.instance.isSignedIn) return;
    final fresh = await FirestoreService.instance.fetchTop(force: true);
    if (!mounted) return;
    setState(() => _future = Future.value(fresh));
  }

  Future<void> _openAuth() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (ok == true && mounted) _load();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isSignedIn) {
      return _buildSignInPrompt();
    }

    final myUid = AuthService.instance.uid;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<List<LeaderboardEntry>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    );
                  }
                  final list = snap.data ?? const <LeaderboardEntry>[];
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Henüz kimse yok.\nİlk sen ol! 🎯',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 15,
                            height: 1.6,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    );
                  }

                  final hasPodium = list.length >= 3;
                  final rest = hasPodium ? list.skip(3).toList() : list;

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      if (hasPodium) ...[
                        _buildPodium(list, myUid),
                        const SizedBox(height: 18),
                      ],
                      for (int i = 0; i < rest.length; i++)
                        _buildRow(
                          (hasPodium ? 3 : 0) + i + 1,
                          rest[i],
                          myUid,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppGradients.gold,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🏆', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'LİDERLİK TABLOSU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (_myRank != null)
            InfoPill(
              leading: const Icon(Icons.person_rounded,
                  color: AppColors.gold, size: 15),
              text: '#$_myRank',
              color: AppColors.gold,
            ),
        ],
      ),
    );
  }

  // ==================== PODYUM ====================

  Widget _buildPodium(List<LeaderboardEntry> list, String? myUid) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumCol(list[1], 2, myUid)),
        Expanded(child: _podiumCol(list[0], 1, myUid)),
        Expanded(child: _podiumCol(list[2], 3, myUid)),
      ],
    );
  }

  Widget _podiumCol(LeaderboardEntry e, int rank, String? myUid) {
    final isMe = e.uid == myUid;
    const heights = {1: 104.0, 2: 78.0, 3: 60.0};
    const avatars = {1: 66.0, 2: 54.0, 3: 54.0};
    final colors = {
      1: [const Color(0xFFFFE08A), const Color(0xFFFF9F1C)],
      2: [const Color(0xFFE6EBF5), const Color(0xFF8F9BB5)],
      3: [const Color(0xFFEBB083), const Color(0xFFA8643A)],
    }[rank]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          const Text('👑', style: TextStyle(fontSize: 26))
        else
          const SizedBox(height: 4),
        AvatarBubble(
          name: e.displayName,
          size: avatars[rank]!,
          ring: colors[0],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            e.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? AppColors.gold : Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Text(
          '${e.totalScore}',
          style: TextStyle(
            color: colors[0],
            fontSize: 14,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: heights[rank],
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors[0].withOpacity(0.55),
                colors[1].withOpacity(0.15),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: colors[0].withOpacity(0.5)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '$rank',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SATIR ====================

  Widget _buildRow(int rank, LeaderboardEntry e, String? myUid) {
    final isMe = e.uid == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMe
              ? [
                  AppColors.gold.withOpacity(0.22),
                  AppColors.gold.withOpacity(0.06),
                ]
              : [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.025),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? AppColors.gold.withOpacity(0.6)
              : Colors.white.withOpacity(0.10),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isMe ? AppColors.gold : Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AvatarBubble(name: e.displayName, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              e.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${e.totalScore}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'Bölüm ${e.highestLevel}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== GİRİŞ İSTEMİ ====================

  Widget _buildSignInPrompt() {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: GlassCard(
              glow: AppColors.gold,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 62)),
                  const SizedBox(height: 14),
                  const Text(
                    'Liderlik Tablosu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sıralamayı görmek ve puanlarını kaydetmek için\nhesap oluşturman veya giriş yapman gerekiyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'GİRİŞ YAP',
                    icon: Icons.login_rounded,
                    onTap: _openAuth,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
