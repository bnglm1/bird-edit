import 'package:flutter/material.dart';

/// SnackBar tipleri
enum SnackType {
  /// Bilgi mesajı (mavi-gri)
  info,

  /// Başarılı işlem (yeşil)
  success,

  /// Uyarı (turuncu)
  warning,

  /// Hata (kırmızı)
  error,

  /// İpucu (mor)
  hint,

  /// Ödül / kazanç (altın)
  reward,
}

/// Uygulamanın her yerinde kullanılan merkezi SnackBar yardımcısı.
///
/// Kullanım:
/// ```dart
/// AppSnackBar.success(context, 'Kaydedildi!');
/// AppSnackBar.error(context, 'Bir hata oluştu');
/// AppSnackBar.hint(context, 'Ünlü harfleri dene');
/// AppSnackBar.reward(context, 'Günlük ödül: +100 puan!');
/// ```
class AppSnackBar {
  AppSnackBar._();

  /// Varsayılan gösterim süresi — kısa ve öz
  static const Duration defaultDuration = Duration(milliseconds: 1500);

  // ==================== KISAYOLLAR ====================

  static void info(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message,
          type: SnackType.info,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  static void success(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message,
          type: SnackType.success,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  static void warning(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message,
          type: SnackType.warning,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  static void error(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message,
          type: SnackType.error,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  static void hint(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message,
          type: SnackType.hint,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  static void reward(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message,
          type: SnackType.reward,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction);

  // ==================== ANA METOD ====================

  static void _show(
    BuildContext context,
    String message, {
    required SnackType type,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;

    // Aynı anda birden fazla SnackBar birikmesin
    ScaffoldMessenger.of(context).clearSnackBars();

    final config = _configFor(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                config.emoji,
                style: const TextStyle(
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.background,
        duration: duration ?? defaultDuration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: config.border,
            width: 1.2,
          ),
        ),
        elevation: 8,
        dismissDirection: DismissDirection.horizontal,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: config.accent,
              )
            : null,
      ),
    );
  }

  static _SnackConfig _configFor(SnackType type) {
    switch (type) {
      case SnackType.success:
        return const _SnackConfig(
          emoji: '✅',
          background: Color(0xFF1B5E20),
          border: Color(0xFF66BB6A),
          accent: Color(0xFFA5D6A7),
        );
      case SnackType.error:
        return const _SnackConfig(
          emoji: '❌',
          background: Color(0xFF8E0000),
          border: Color(0xFFEF5350),
          accent: Color(0xFFFFCDD2),
        );
      case SnackType.warning:
        return const _SnackConfig(
          emoji: '⚠️',
          background: Color(0xFF8A4B00),
          border: Color(0xFFFFB74D),
          accent: Color(0xFFFFE0B2),
        );
      case SnackType.hint:
        return const _SnackConfig(
          emoji: '💡',
          background: Color(0xFF3D1A6E),
          border: Color(0xFFBA68C8),
          accent: Color(0xFFE1BEE7),
        );
      case SnackType.reward:
        return const _SnackConfig(
          emoji: '🎁',
          background: Color(0xFF5C3A1F),
          border: Color(0xFFFFD700),
          accent: Color(0xFFFFF8B0),
        );
      case SnackType.info:
      default:
        return const _SnackConfig(
          emoji: 'ℹ️',
          background: Color(0xFF1E3A5F),
          border: Color(0xFF4DD0E1),
          accent: Color(0xFFB2EBF2),
        );
    }
  }
}

class _SnackConfig {
  final String emoji;
  final Color background;
  final Color border;
  final Color accent;

  const _SnackConfig({
    required this.emoji,
    required this.background,
    required this.border,
    required this.accent,
  });
}
