import 'firestore_service.dart';

/// Client tarafında sabit sahte liderlik tablosu.
///
/// - **40 fake kullanıcı** — her birinin puanı sabit
/// - **Firestore'a yazılmaz** — sadece görüntüleme amaçlı
/// - **Puan artışı yok** — fake'ler hep aynı puanda kalır
/// - **Gerçek kullanıcılar zamanla geçebilir** — motivasyon kaynağı
///
/// **Puan dağılımı (en yüksekten en düşüğe):**
///  - 5 kullanıcı: 35.000 - 50.000 (zirve — aylarca oynamak gerekir)
///  - 10 kullanıcı: 20.000 - 33.000 (yüksek)
///  - 15 kullanıcı: 5.000 - 18.000 (orta)
///  - 10 kullanıcı: 500 - 4.500 (düşük)
class FakeLeaderboard {
  FakeLeaderboard._();

  /// 200 puan = 1 seviye (görsel eşleme)
  static const int _pointsPerLevel = 200;

  /// Sabit sahte kullanıcı listesi.
  /// Format: (nickname, totalScore)
  static const List<MapEntry<String, int>> _entries = [
    // ==================== ZİRVE: 35.000 - 50.000 (5 kişi) ====================
    MapEntry('Gül', 48750),
    MapEntry('Erdal', 44200),
    MapEntry('Nurten', 41500),
    MapEntry('Şaban', 38600),
    MapEntry('Songül', 35800),

    // ==================== YÜKSEK: 20.000 - 33.000 (10 kişi) ====================
    MapEntry('Bekir', 32400),
    MapEntry('Filiz', 30150),
    MapEntry('Mahmut', 28600),
    MapEntry('Esra', 26900),
    MapEntry('Salih', 25300),
    MapEntry('Merve', 23800),
    MapEntry('Kemal', 22500),
    MapEntry('Dilek', 21400),
    MapEntry('Kadir', 20600),
    MapEntry('Sevgi', 19800),

    // ==================== ORTA: 5.000 - 18.000 (15 kişi) ====================
    MapEntry('Recep', 18200),
    MapEntry('Havva', 16800),
    MapEntry('İsmail', 15400),
    MapEntry('Yasemin', 14200),
    MapEntry('Süleyman', 13100),
    MapEntry('Halil', 12000),
    MapEntry('Zehra', 11000),
    MapEntry('Ramazan', 10100),
    MapEntry('Şerife', 9200),
    MapEntry('Osman', 8400),
    MapEntry('Meryem', 7600),
    MapEntry('Murat', 6900),
    MapEntry('Hatice', 6200),
    MapEntry('Yusuf', 5600),
    MapEntry('Emine', 5100),

    // ==================== DÜŞÜK: 500 - 4.500 (10 kişi) ====================
    MapEntry('İbrahim', 4500),
    MapEntry('Elif', 3900),
    MapEntry('Hüseyin', 3300),
    MapEntry('Zeynep', 2700),
    MapEntry('Ali', 2200),
    MapEntry('Fatma', 1700),
    MapEntry('Mustafa', 1300),
    MapEntry('Ayşe', 900),
    MapEntry('Mehmet', 650),
    MapEntry('Ahmet', 500),
  ];

  /// Tüm sahte kullanıcıları `LeaderboardEntry` listesi olarak döner.
  static List<LeaderboardEntry> getEntries() {
    return _entries.map((e) {
      final score = e.value;
      final level = (score / _pointsPerLevel).clamp(1, 999).toInt();

      return LeaderboardEntry(
        uid: 'fake_${e.key}',
        email: '${e.key.toLowerCase()}@fake',
        nickname: e.key,
        totalScore: score,
        highestLevel: level,
      );
    }).toList();
  }

  /// Verilen skordan yüksek puanlı fake kullanıcı sayısı.
  static int countAbove(int score) {
    return _entries.where((e) => e.value > score).length;
  }
}
