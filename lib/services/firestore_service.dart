import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'fake_leaderboard.dart';

class LeaderboardEntry {
  final String uid;
  final String email;
  final String? nickname;
  final int totalScore;
  final int highestLevel;

  const LeaderboardEntry({
    required this.uid,
    required this.email,
    required this.nickname,
    required this.totalScore,
    required this.highestLevel,
  });

  String get displayName {
    final n = nickname?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    return email.isEmpty ? 'Anonim' : email;
  }

  factory LeaderboardEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const {};
    return LeaderboardEntry(
      uid: d.id,
      email: (data['email'] as String?) ?? '',
      nickname: data['nickname'] as String?,
      totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
      highestLevel: (data['highestLevel'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Kullanıcının buluttaki ilerleme verisi
class UserProgress {
  final int totalScore;
  final int highestLevel;
  final int currentLevel;
  final String? lastDailyReward;
  final String? nickname; // 👈 YENİ

  const UserProgress({
    required this.totalScore,
    required this.highestLevel,
    required this.currentLevel,
    this.lastDailyReward,
    this.nickname, // 👈 YENİ
  });
}

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const String _collection = 'players';

  // ==================== LİDERLİK TABLOSU CACHE ====================

  static List<LeaderboardEntry>? _cachedTop;
  static DateTime? _cachedTopAt;
  static const Duration _leaderboardTtl = Duration(minutes: 30);

  static bool get isLeaderboardCacheStale {
    if (_cachedTopAt == null) return true;
    return DateTime.now().difference(_cachedTopAt!) >= _leaderboardTtl;
  }

  static Duration? get leaderboardCacheAge {
    if (_cachedTopAt == null) return null;
    return DateTime.now().difference(_cachedTopAt!);
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Top N liderlik tablosu (gerçek + sahte kullanıcılar birleşik).
  Future<List<LeaderboardEntry>> fetchTop({
    int limit = 50,
    bool force = false,
  }) async {
    // Cache geçerliyse hızlı dön
    if (!force &&
        _cachedTop != null &&
        _cachedTopAt != null &&
        DateTime.now().difference(_cachedTopAt!) < _leaderboardTtl) {
      return _cachedTop!;
    }

    try {
      final snap = await _db
          .collection(_collection)
          .orderBy('totalScore', descending: true)
          .limit(100)
          .get();
      final realList = snap.docs.map(LeaderboardEntry.fromDoc).toList();

      final fakeList = FakeLeaderboard.getEntries();

      final combined = <LeaderboardEntry>[...realList, ...fakeList]
        ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

      final result = combined.take(limit).toList();

      _cachedTop = result;
      _cachedTopAt = DateTime.now();
      return result;
    } catch (_) {
      return _cachedTop ?? const [];
    }
  }

  void invalidateLeaderboardCache() {
    _cachedTop = null;
    _cachedTopAt = null;
  }

  // ==================== SKOR KAYDETME ====================

  Future<void> saveScore({
    required int totalScore,
    required int highestLevel,
    required int currentLevel,
    String? nickname,
    String? lastDailyReward,
  }) async {
    final uid = AuthService.instance.uid;
    final email = AuthService.instance.email;
    if (uid == null || email == null) return;

    try {
      final ref = _db.collection(_collection).doc(uid);
      final snap = await ref.get();
      final existing = snap.data();

      final oldTotal = (existing?['totalScore'] as num?)?.toInt() ?? 0;
      final oldLevel = (existing?['highestLevel'] as num?)?.toInt() ?? 1;

      final newTotal = totalScore > oldTotal ? totalScore : oldTotal;
      final newLevel = highestLevel > oldLevel ? highestLevel : oldLevel;

      // Nickname önceliği:
      //  1. Çağrıdan gelen yeni nickname
      //  2. Firestore'daki mevcut nickname
      //  3. E-posta ön eki (son çare)
      final trimmedNick = nickname?.trim();
      final finalNickname = (trimmedNick != null && trimmedNick.isNotEmpty)
          ? trimmedNick
          : (existing?['nickname'] as String?) ??
              (email.contains('@') ? email.split('@').first : email);

      final data = <String, dynamic>{
        'email': email,
        'nickname': finalNickname,
        'totalScore': newTotal,
        'highestLevel': newLevel,
        'currentLevel': currentLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (lastDailyReward != null) {
        data['lastDailyReward'] = lastDailyReward;
      }

      await ref.set(data, SetOptions(merge: true));

      invalidateLeaderboardCache();
    } catch (_) {}
  }

  // ==================== KULLANICI İLERLEMESİ ====================

  Future<UserProgress?> fetchMyProgress() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return null;

    try {
      final snap = await _db.collection(_collection).doc(uid).get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      return UserProgress(
        totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
        highestLevel: (data['highestLevel'] as num?)?.toInt() ?? 1,
        currentLevel: (data['currentLevel'] as num?)?.toInt() ?? 1,
        lastDailyReward: data['lastDailyReward'] as String?,
        nickname: data['nickname'] as String?, // 👈 YENİ
      );
    } catch (_) {
      return null;
    }
  }

  // ==================== SIRALAMA ====================

  Future<int?> fetchMyRank() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return null;

    try {
      final me = await _db.collection(_collection).doc(uid).get();
      final myScore = (me.data()?['totalScore'] as num?)?.toInt() ?? 0;

      final higher = await _db
          .collection(_collection)
          .where('totalScore', isGreaterThan: myScore)
          .count()
          .get();
      final cloudAbove = higher.count ?? 0;

      final fakeAbove = FakeLeaderboard.countAbove(myScore);

      return cloudAbove + fakeAbove + 1;
    } catch (_) {
      return null;
    }
  }
}
