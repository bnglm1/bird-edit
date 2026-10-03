import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Alt banner reklamı.
///
/// Release modda platform view boyut kısıtlamasını yok sayma sorununa karşı
/// çok katmanlı koruma uygular:
///  1. `SizedBox` — verilen boyutu sabitler
///  2. `ClipRect` — taşan pikselleri kırpar
///  3. `OverflowBox` — child'ı zorla boyutlandırır
///  4. `AspectRatio` — banner oranını korur
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  Timer? _retryTimer;
  int _retryCount = 0;

  static const Duration _retryDelay = Duration(seconds: 30);
  static const int _maxRetries = 5;

  static String get _adUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111' // Google test ID
          : 'ca-app-pub-7690250755006392/6104238252';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    if (kIsWeb) return;

    final unitId = _adUnitId;
    if (unitId.isEmpty) return;

    _bannerAd?.dispose();
    _bannerAd = null;

    _bannerAd = BannerAd(
      adUnitId: unitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _retryCount = 0;
          setState(() => _isLoaded = true);
          if (kDebugMode) debugPrint('✅ Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
          if (kDebugMode) debugPrint('❌ Banner ad failed: $error');
          _scheduleRetry();
        },
      ),
    );

    _bannerAd!.load();
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (!mounted) return;
      _retryCount++;
      _loadAd();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final adW = _bannerAd!.size.width.toDouble();
    final adH = _bannerAd!.size.height.toDouble();

    // Çok katmanlı sınırlama:
    // 1) ClipRect → taşan pikselleri kırp
    // 2) SizedBox → kesin boyut
    // 3) OverflowBox → child'ı bu boyuta zorla (Release modda şart!)
    // 4) AdWidget → platform view
    return ClipRect(
      child: SizedBox(
        width: adW,
        height: adH,
        child: OverflowBox(
          minWidth: adW,
          maxWidth: adW,
          minHeight: adH,
          maxHeight: adH,
          alignment: Alignment.center,
          child: SizedBox(
            width: adW,
            height: adH,
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}
