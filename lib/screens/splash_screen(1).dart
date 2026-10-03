import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/word_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'main_shell.dart';

/// Uygulama açılışında gösterilen splash ekranı.
///
/// **Ne yapar:**
///  - Logo + shimmer animasyonu gösterir
///  - Bu sırada `WordRepository.load()` çağrılır (GitHub → cache → assets)
///  - En az 1.8 saniye gösterilir (çok hızlı açılışta bile göze hoş gelsin)
///  - Yükleme biter + min süre geçince MainShell'e geçer
///  - Alt kısımda `pubspec.yaml`'daki sürüm numarasını gösterir
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Splash'in minimum gösterim süresi
  static const Duration _minShowDuration = Duration(milliseconds: 1800);

  late final AnimationController _shimmer;
  late final AnimationController _pulse;
  late final AnimationController _logoEntry;
  late final AnimationController _dots;

  /// pubspec.yaml'dan okunan sürüm bilgisi (varsayılan fallback)
  String _version = '';

  @override
  void initState() {
    super.initState();

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _logoEntry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _loadVersion();
    _bootstrap();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _pulse.dispose();
    _logoEntry.dispose();
    _dots.dispose();
    super.dispose();
  }

  /// pubspec.yaml'daki version'ı yükler.
  /// Örn: "1.2.3 (build 45)" → ekranda "v1.2.3"
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version; // "1.2.3"
        // info.buildNumber → "45" (build numarası)
        // info.appName → "Kelime Ustası"
        // info.packageName → "com.bintech.wordmaster"
      });
    } catch (_) {
      // Bilgi alınamazsa boş kalır, sadece "v" görünmez
    }
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    // 1) Kelimeleri yükle (GitHub → cache → assets)
    try {
      await WordRepository.load();
    } catch (_) {
      // Hata olsa bile devam et — assets fallback çalışır
    }

    // 2) Minimum süre geçmediyse bekle
    final elapsed = stopwatch.elapsed;
    if (elapsed < _minShowDuration) {
      await Future.delayed(_minShowDuration - elapsed);
    }

    if (!mounted) return;

    // 3) MainShell'e geç
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildLogo(),
              const SizedBox(height: 18),
              _buildTitle(),
              const SizedBox(height: 12),
              _buildSubtitle(),
              const Spacer(flex: 3),
              _buildLoadingIndicator(),
              const Spacer(flex: 1),
              _buildVersion(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LOGO: harf karoları ====================

  Widget _buildLogo() {
    const letters = ['K', 'E', 'L', 'İ', 'M', 'E'];
    return AnimatedBuilder(
      animation: Listenable.merge([_logoEntry, _pulse]),
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.18 + _pulse.value * 0.14),
                blurRadius: 50 + _pulse.value * 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(letters.length, (i) {
              final v = Curves.easeOutBack.transform(
                Interval(i * 0.1, 0.4 + i * 0.1).transform(_logoEntry.value),
              );
              return Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -60),
                  child: Transform.rotate(
                    angle: (1 - v) * (i.isEven ? -0.5 : 0.5),
                    child: Container(
                      width: 48,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        gradient: AppGradients.gold,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFB36B00),
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 12,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        letters[i],
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ==================== BAŞLIK ====================

  Widget _buildTitle() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _logoEntry,
        curve: const Interval(0.6, 1.0),
      ),
      child: AnimatedBuilder(
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
          'USTASI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 12,
            height: 1.1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _logoEntry,
        curve: const Interval(0.7, 1.0),
      ),
      child: const Text(
        'Kelimeleri fethetmeye hazır mısın?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white38,
          fontSize: 13,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // ==================== LOADING ====================

  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _logoEntry,
      child: Column(
        children: [
          // 3 nokta animasyonu
          SizedBox(
            height: 24,
            child: AnimatedBuilder(
              animation: _dots,
              builder: (_, __) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = (_dots.value + i * 0.33) % 1.0;
                    final scale = phase < 0.5
                        ? 0.6 + (phase * 2) * 0.5
                        : 1.1 - ((phase - 0.5) * 2) * 0.5;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.withOpacity(
                              0.4 + scale * 0.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Yükleniyor',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SÜRÜM ====================

  Widget _buildVersion() {
    if (_version.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _logoEntry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          'v$_version',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
