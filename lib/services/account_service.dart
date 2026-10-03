import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firestore_service.dart';

/// Aktif moddaki ilerleme verisini temsil eder.
class ActiveProgress {
  final int totalScore;
  final int highestLevel;
  final int currentLevel;
  final String nickname;
  final bool isAccount;
  final String? lastDailyReward; // "2026-10-02"

  const ActiveProgress({
    required this.totalScore,
    required this.highestLevel,
    required this.currentLevel,
    required this.nickname,
    required this.isAccount,
    this.lastDailyReward,
  });
}

/// Hangi modun aktif olduğunu yönetir.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  static StreamSubscription<User?>? _sub;
  static bool _started = false;
  static Future<void> _chain = Future.value();

  static Future<void> get idle => _chain;

  static ActiveProgress _current = const ActiveProgress(
    totalScore: 0,
    highestLevel: 1,
    currentLevel: 1,
    nickname: '',
    isAccount: false,
  );
  static ActiveProgress get current => _current;

  static void start() {
    if (_started) return;
    _started = true;

    _sub = AuthService.instance.authStateChanges.listen((user) {
      _chain = _chain.then((_) => _refresh(user)).catchError((_) {});
    });

    _chain = _chain
        .then((_) => _refresh(AuthService.instance.user))
        .catchError((_) {});
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  static Future<ActiveProgress> refresh() async {
    await _chain;
    await _refresh(AuthService.instance.user);
    return _current;
  }

  static Future<void> _refresh(User? user) async {
    if (user == null) {
      // 🟡 MİSAFİR MODU
      final prefs = await SharedPreferences.getInstance();
      _current = ActiveProgress(
        totalScore: prefs.getInt('totalScore') ?? 0,
        highestLevel: prefs.getInt('highestLevel') ?? 1,
        currentLevel: prefs.getInt('currentLevel') ?? 1,
        nickname: prefs.getString('displayName') ?? '',
        isAccount: false,
        lastDailyReward: prefs.getString('lastDailyReward'),
      );
      return;
    }

    // 🟢 HESAP MODU
    var cloud = await FirestoreService.instance.fetchMyProgress();

    // Hesapta henüz kayıt yoksa misafir ilerlemesini hesaba taşı
    // (ilk kez giriş/kayıt yapan oyuncu puanlarını kaybetmesin).
    if (cloud == null) {
      final prefs = await SharedPreferences.getInstance();
      final gScore = prefs.getInt('totalScore') ?? 0;
      final gHigh = prefs.getInt('highestLevel') ?? 1;
      final gCur = prefs.getInt('currentLevel') ?? 1;
      if (gScore > 0 || gHigh > 1 || gCur > 1) {
        await FirestoreService.instance.saveScore(
          totalScore: gScore,
          highestLevel: gHigh,
          currentLevel: gCur,
        );
        cloud = await FirestoreService.instance.fetchMyProgress();
      }
    }
    _current = ActiveProgress(
      totalScore: cloud?.totalScore ?? 0,
      highestLevel: cloud?.highestLevel ?? 1,
      currentLevel: cloud?.currentLevel ?? 1,
      nickname: (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : '',
      isAccount: true,
      lastDailyReward: cloud?.lastDailyReward,
    );
  }

  /// Aktif moda kaydeder.
  static Future<void> save({
    required int totalScore,
    required int highestLevel,
    required int currentLevel,
    String? nickname,
    String? lastDailyReward,
  }) async {
    final isAccount = AuthService.instance.isSignedIn;

    if (isAccount) {
      await FirestoreService.instance.saveScore(
        totalScore: totalScore,
        highestLevel: highestLevel,
        currentLevel: currentLevel,
        nickname: nickname,
        lastDailyReward: lastDailyReward,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalScore', totalScore);
      await prefs.setInt('highestLevel', highestLevel);
      await prefs.setInt('currentLevel', currentLevel);
      if (nickname != null) {
        await prefs.setString('displayName', nickname);
      }
      if (lastDailyReward != null) {
        await prefs.setString('lastDailyReward', lastDailyReward);
      }
    }

    _current = ActiveProgress(
      totalScore: totalScore,
      highestLevel: highestLevel,
      currentLevel: currentLevel,
      nickname: nickname ?? _current.nickname,
      isAccount: isAccount,
      lastDailyReward: lastDailyReward ?? _current.lastDailyReward,
    );
  }
}
