import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 3D "tuş" görünümlü harf karosu.
class LetterTile extends StatefulWidget {
  final String letter;
  final bool selected;
  final bool used;
  final bool correct;
  final VoidCallback? onTap;

  const LetterTile({
    super.key,
    required this.letter,
    this.selected = false,
    this.used = false,
    this.correct = false,
    this.onTap,
  });

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final used = widget.used;
    final pressed = _down && !used;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: used ? null : (_) => setState(() => _down = true),
      onTapUp: used ? null : (_) => setState(() => _down = false),
      onTapCancel: used ? null : () => setState(() => _down = false),
      onTap: used
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        width: 50,
        height: 54,
        margin: const EdgeInsets.all(4),
        transform: Matrix4.translationValues(0, pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: used
                ? const [Color(0xFF2A2740), Color(0xFF211F36)]
                : const [Color(0xFF7468FF), Color(0xFF4F42DB)],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(used ? 0.05 : 0.22),
          ),
          boxShadow: used
              ? const []
              : [
                  // 3D alt kenar
                  BoxShadow(
                    color: const Color(0xFF2A2290),
                    offset: Offset(0, pressed ? 1 : 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 10,
                    offset: Offset(0, pressed ? 3 : 7),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: used ? 0.22 : 1,
          child: Text(
            widget.letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
              shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}
