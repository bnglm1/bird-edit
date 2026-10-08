import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'sound_service.dart';

/// Reklam hizmeti — interstitial (geçiş) ve rewarded (ödüllü) reklamları yönetir.
///
/// **Müzik entegrasyonu:**
///  - Reklam açılmadan önce arka plan müziği duraklatılır
///  - Reklam kapandığında (veya hata olursa) müzik devam ettirilir
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ==================== INTERSTITIAL ====================

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoaded = false;
  bool _isInterstitialLoading = false;
  int _interstitialRetryCount = 0;
  int _completedLevelsSinceAd = 0;

  /// Kaç bölümde bir interstitial gösterilecek
  static const int _showInterstitialEvery = 3;

  // ==================== REWARDED ====================

  RewardedAd? _rewardedAd;
  bool _isRewardedLoaded = false;
  int _rewardedRetryCount = 0;
  static const int _rewardedRetryLimit = 3;

  // ==================== AD UNIT ID'LERİ ====================

  // ⚠️ TEST REKLAM ID'LERİ
  // Yayına alırken kendi AdMob panelinden aldığın ID'lerle değiştir!

  static String get _interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712' // Google test ID
          : 'ca-app-pub-7690250755006392/4539875145';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  static String get _rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/5224354917' // Google test ID
          : 'ca-app-pub-7690250755006392/5211713004';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }

  // ==================== INIT ====================

  /// Uygulama başında bir kez çağır
  Future<void> init() async {
    if (kIsWeb) return;

    await MobileAds.instance.initialize();

    // 🧪 Test cihazları — yayına alırken bu listeyi boşalt!
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: [
          // 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', // ← kendi cihaz ID'ni buraya
        ],
      ),
    );

    _loadInterstitial();
    _loadRewarded();
  }

  // ==================== INTERSTITIAL ====================

  void _loadInterstitial() {
    if (kIsWeb) return;
    if (_isInterstitialLoading || _isInterstitialLoaded) return;
    final unitId = _interstitialAdUnitId;
    if (unitId.isEmpty) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          _interstitialRetryCount = 0;
          if (kDebugMode) debugPrint('✅ Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          _interstitialAd = null;
          if (kDebugMode) {
            debugPrint('❌ Interstitial ad failed: $error');
          }
          // Otomatik retry — 30 sn sonra (en fazla 3 kez)
          if (_interstitialRetryCount < 3) {
            _interstitialRetryCount++;
            Future.delayed(const Duration(seconds: 30), _loadInterstitial);
          }
        },
      ),
    );
  }

  /// Bölüm tamamlandığında çağır. Reklam gösterilmesi gerekiyorsa `true` döner.
  /// **Sayaç SIFIRLANMAZ** — sadece `markInterstitialShown()` çağrılınca sıfırlanır.
  bool registerLevelComplete() {
    _completedLevelsSinceAd++;
    return _completedLevelsSinceAd >= _showInterstitialEvery;
  }

  /// Reklam gerçekten gösterildikten sonra sayacı sıfırlar.
  void markInterstitialShown() {
    _completedLevelsSinceAd = 0;
  }

  /// Eğer hazırsa interstitial gösterir.
  /// `true` → reklam gösterildi, `false` → hazır değildi veya hata oldu.
  ///
  /// **Müzik davranışı:**
  ///  - Reklam açılmadan önce müzik duraklatılır
  ///  - Reklam kapandığında veya hata olduğunda müzik devam ettirilir
  Future<bool> showInterstitialIfAvailable() async {
    if (!_isInterstitialLoaded || _interstitialAd == null) {
      _interstitialRetryCount = 0;
      _loadInterstitial();
      return false;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _isInterstitialLoaded = false;

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) async {
        a.dispose();
        _loadInterstitial();
        // 🎵 Reklam kapandı — müziği devam ettir
        await SoundService.instance.resumeBackgroundMusic();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, err) async {
        a.dispose();
        _loadInterstitial();
        // 🎵 Reklam açılamadı — müziği devam ettir
        await SoundService.instance.resumeBackgroundMusic();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    // 🎵 Reklam açılmadan önce müziği duraklat
    await SoundService.instance.pauseBackgroundMusic();

    try {
      await ad.show();
    } catch (e) {
      if (!completer.isCompleted) completer.complete(false);
      // Hata olsa bile müziği geri başlat
      await SoundService.instance.resumeBackgroundMusic();
    }

    return completer.future;
  }

  // ==================== REWARDED ====================

  void _loadRewarded() {
    if (kIsWeb) return;
    final unitId = _rewardedAdUnitId;
    if (unitId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ Rewarded ad unit ID boş — reklam yüklenemez');
      }
      return;
    }
    // Placeholder ID kontrolü
    if (unitId.contains('XXXXXXXXXX')) {
      if (kDebugMode) {
        debugPrint('⚠️ Rewarded ad unit ID henüz ayarlanmadı (placeholder)');
      }
      return;
    }

    _rewardedAd?.dispose();
    _rewardedAd = null;

    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
          _rewardedRetryCount = 0;
          if (kDebugMode) debugPrint('✅ Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoaded = false;
          if (kDebugMode) {
            debugPrint('❌ Rewarded ad failed: $error');
          }

          // Otomatik retry — 30 sn sonra
          if (_rewardedRetryCount < _rewardedRetryLimit) {
            _rewardedRetryCount++;
            Future.delayed(const Duration(seconds: 30), () {
              _loadRewarded();
            });
          }
        },
      ),
    );
  }

  /// Ödüllü reklamı gösterir.
  ///
  /// **Dönüş:**
  /// - `true` → kullanıcı reklamı sonuna kadar izledi, ödül kazanıldı
  /// - `false` → reklam yok, yüklenemedi veya kullanıcı iptal etti
  ///
  /// **Müzik davranışı:**
  ///  - Reklam açılmadan önce müzik duraklatılır
  ///  - Reklam kapandığında veya hata olduğunda müzik devam ettirilir
  Future<bool> showRewardedIfAvailable() async {
    // Yüklü değilse hemen yüklemeye başla ve false dön
    if (!_isRewardedLoaded || _rewardedAd == null) {
      _loadRewarded();
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    _isRewardedLoaded = false;

    final completer = Completer<bool>();
    bool earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) async {
        a.dispose();
        _loadRewarded(); // sonraki kullanım için yeniden yükle
        // 🎵 Reklam kapandı — müziği devam ettir
        await SoundService.instance.resumeBackgroundMusic();
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (a, err) async {
        a.dispose();
        _loadRewarded();
        // 🎵 Reklam açılamadı — müziği devam ettir
        await SoundService.instance.resumeBackgroundMusic();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    // 🎵 Reklam açılmadan önce müziği duraklat
    await SoundService.instance.pauseBackgroundMusic();

    try {
      await ad.show(onUserEarnedReward: (_, reward) {
        earnedReward = true;
        if (kDebugMode) {
          debugPrint('💰 Reward earned: ${reward.amount} ${reward.type}');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Rewarded show error: $e');
      if (!completer.isCompleted) completer.complete(false);
      // Hata olsa bile müziği geri başlat
      await SoundService.instance.resumeBackgroundMusic();
    }

    return completer.future;
  }

  // ==================== DISPOSE ====================

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
