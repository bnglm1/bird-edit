import 'package:flutter/material.dart';

/// Uygulamanın tüm renk / gradyan tanımları (tek kaynak).
class AppColors {
  AppColors._();

  static const bg0 = Color(0xFF080620);
  static const bg1 = Color(0xFF14103A);
  static const bg2 = Color(0xFF231A58);

  static const gold = Color(0xFFFFC857);
  static const goldDeep = Color(0xFFFF9F1C);
  static const violet = Color(0xFF7C5CFF);
  static const violetDeep = Color(0xFF4B2FD0);
  static const cyan = Color(0xFF35D0E6);
  static const pink = Color(0xFFFF6B9D);
  static const mint = Color(0xFF5EEAA0);
  static const coral = Color(0xFFFF7A59);
  static const ink = Color(0xFF1A1033);

  static const palette = [violet, cyan, pink, mint, coral, gold];

  /// Bölüm zorluğuna göre renk.
  static Color chapter(String chapter) {
    switch (chapter) {
      case 'Çok Kolay':
        return mint;
      case 'Kolay':
        return const Color(0xFF64B5F6);
      case 'Orta':
        return const Color(0xFFFFB74D);
      case 'Zor':
        return const Color(0xFFFF8A80);
      case 'Çok Zor':
        return const Color(0xFFBA68C8);
      case 'Bonus':
        return gold;
      default:
        return cyan;
    }
  }
}

class AppGradients {
  AppGradients._();

  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD670), Color(0xFFFF9F1C)],
  );
  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7BFF), Color(0xFF4B2FD0)],
  );
  static const coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFA05A), Color(0xFFFF4D6D)],
  );
  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5EEAA0), Color(0xFF1FB5A0)],
  );
  static const cyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5BE3F5), Color(0xFF2A8FD6)],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg0,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.violet,
        surface: AppColors.bg1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
      ),
    );
  }
}
