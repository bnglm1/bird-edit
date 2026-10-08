import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../widgets/app_snackbar.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  static const String _nicknameKey = 'displayName';

  int _totalScore = 0;
  int _highestLevel = 1;
  int _currentLevel = 1;
  String _nickname = '';
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();

    _authSub = AuthService.instance.authStateChanges.listen((_) async {
      await AccountService.idle;
      if (mounted) await _load();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Dışarıdan (sekme değişince) tazeleme için
  void reload() => _load();

  Future<void> _load() async {
    final p = await AccountService.refresh();
    if (!mounted) return;

    setState(() {
      _totalScore = p.totalScore;
      _highestLevel = p.highestLevel;
      _currentLevel = p.currentLevel;
      _nickname = p.nickname;
    });
  }

  Future<void> _persist({String? nickname}) async {
    await AccountService.save(
      totalScore: _totalScore,
      highestLevel: _highestLevel,
      currentLevel: _currentLevel,
      nickname: nickname ?? _nickname,
    );
  }

  // ================== TAKMA AD DÜZENLE ==================

  Future<void> _editNickname() async {
    SoundService.instance.playTap();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameDialog(initial: _nickname),
    );

    if (result == null || result == _nickname) return;

    // Prefs'e de yaz (misafir modu için)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, result);

    if (!mounted) return;
    setState(() => _nickname = result);

    await _persist(nickname: result);

    if (!mounted) return;
    AppSnackBar.success(context, 'Takma adın güncellendi!');
  }

  // ================== AUTH ==================

  Future<void> _openAuth() async {
    SoundService.instance.playTap();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (ok == true && mounted) {
      AppSnackBar.success(context, 'Giriş başarılı!');
      await _load();
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Çıkış Yap',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
        content: const Text(
          'Hesabından çıkmak istediğine emin misin?\n\n'
          'Hesabındaki puanlar güvende kalır. Çıkış yapınca '
          'misafir olarak kaldığın yerden devam edersin.',
          style: TextStyle(
            color: Colors.white70,
            height: 1.5,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(
                color: Colors.white54,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.instance.signOut();
    await AccountService.idle;
    if (!mounted) return;

    await _load();

    if (!mounted) return;
    AppSnackBar.info(context, 'Çıkış yapıldı');
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isSignedIn) {
      return _buildSignInPrompt();
    }

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _buildSignedInCard(),
                  const SizedBox(height: 26),
                  _buildSectionTitle('İSTATİSTİKLER'),
                  const SizedBox(height: 12),
                  _buildStatsRow(),
                  const SizedBox(height: 26),
                  _buildSectionTitle('AYARLAR'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== GİRİŞ YAPILMAMIŞ EKRANI ==================

  Widget _buildSignInPrompt() {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👤', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'Profil',
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
                  'Puanlarını kaydetmek, liderlik tablosuna girmek\nve tüm cihazlarından erişmek için\nhesap oluşturman veya giriş yapman gerekiyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 6,
                      shadowColor: Colors.amber.withOpacity(0.5),
                    ),
                    child: const Text(
                      'GİRİŞ YAP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
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

  // ================== TOP BAR ==================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'PROFİL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          IconButton(
            onPressed: _signOut,
            tooltip: 'Çıkış Yap',
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.amber,
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

  // ================== GİRİŞ YAPILMIŞ KART ==================

  Widget _buildSignedInCard() {
    final user = AuthService.instance.user;

    // Nickname önceliği:
    //  1. Firestore'daki nickname (AccountService zaten bu değeri getiriyor)
    //  2. Genel "Oyuncu" (e-posta ASLA fallback olmaz)
    final effectiveName =
        _nickname.trim().isNotEmpty ? _nickname.trim() : 'Oyuncu';

    final photoUrl = user?.photoURL;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final avatarLetter =
        effectiveName.isNotEmpty ? effectiveName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ============ AVATAR ============
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFFA726)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.35),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFF1A1A3E),
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      avatarLetter,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ============ KULLANICI ADI + DÜZENLE ============
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  effectiveName,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _editNickname,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.amber,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================== İSTATİSTİKLER ==================

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.stars_rounded,
            label: 'PUAN',
            value: '$_totalScore',
            color: const Color(0xFF4DD0E1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.military_tech_rounded,
            label: 'REKOR',
            value: '$_highestLevel',
            color: const Color(0xFFFF8A80),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.play_arrow_rounded,
            label: 'DEVAM',
            value: '$_currentLevel',
            color: const Color(0xFFFFD54F),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.28),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ================== AYARLAR ==================

  Widget _buildSettingsCard() {
    final soundOn = SoundService.instance.enabled;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    (soundOn ? Colors.amber : Colors.white38).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: soundOn ? Colors.amber : Colors.white38,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ses Efektleri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    soundOn ? 'Açık' : 'Kapalı',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: soundOn,
              activeColor: Colors.amber,
              onChanged: (v) async {
                await SoundService.instance.setEnabled(v);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================== TAKMA AD DİYALOĞU ==================

class _NicknameDialog extends StatefulWidget {
  final String initial;

  const _NicknameDialog({required this.initial});

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _ctrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Takma Adı Düzenle',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Örn: KelimeKralı',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            counterStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.amber, width: 1.5),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Takma ad boş olamaz';
            if (t.length < 3) return 'En az 3 karakter';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Vazgeç',
            style: TextStyle(
              color: Colors.white54,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            'Kaydet',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
