import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Dokunulunca hafifçe küçülen + titreşim veren sarmalayıcı.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.95,
    this.haptic = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Cam efektli kart.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final Color? borderColor;
  final List<Color>? colors;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.glow,
    this.borderColor,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ??
              [Colors.white.withOpacity(0.11), Colors.white.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.13)),
        boxShadow: [
          if (glow != null)
            BoxShadow(
              color: glow!.withOpacity(0.22),
              blurRadius: 26,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Gradyanlı, parlayan ana buton.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Gradient gradient;
  final Color glow;
  final Color textColor;
  final double height;
  final VoidCallback? onTap;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = AppGradients.gold,
    this.glow = AppColors.goldDeep,
    this.textColor = AppColors.ink,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: glow.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İsmin baş harfinden renkli avatar.
class AvatarBubble extends StatelessWidget {
  final String name;
  final double size;
  final Color? ring;
  final String? photoUrl;

  const AvatarBubble({
    super.key,
    required this.name,
    this.size = 40,
    this.ring,
    this.photoUrl,
  });

  static const _grads = [
    AppGradients.violet,
    AppGradients.cyan,
    AppGradients.coral,
    AppGradients.mint,
    AppGradients.gold,
  ];

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final letter = clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
    final g = _grads[clean.codeUnits.fold<int>(0, (a, b) => a + b) % _grads.length];
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: g,
        border: Border.all(
          color: ring ?? Colors.white.withOpacity(0.3),
          width: ring != null ? 2.5 : 1.5,
        ),
        boxShadow: ring != null
            ? [BoxShadow(color: ring!.withOpacity(0.5), blurRadius: 14)]
            : null,
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.44,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
    );
  }
}

/// Küçük renkli bilgi hapı.
class InfoPill extends StatelessWidget {
  final Widget leading;
  final String text;
  final Color color;

  const InfoPill({
    super.key,
    required this.leading,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yuvarlak cam ikon butonu.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
