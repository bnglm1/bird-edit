import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tüm ekranların ortak arka planı:
/// gradyan + yavaşça süzülen renkli ışık küreleri + yükselen silik harfler.
class AppBackground extends StatefulWidget {
  final Widget child;

  /// Bonus bölümler için altın tema
  final bool bonus;

  const AppBackground({super.key, required this.child, this.bonus = false});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _Floater {
  final double x, speed, phase, rot;
  final TextPainter tp;
  _Floater(this.x, this.speed, this.phase, this.rot, this.tp);
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Floater> _floaters;

  static const _letters = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))
      ..repeat();

    final rnd = Random(7);
    _floaters = List.generate(16, (i) {
      final size = 22 + rnd.nextDouble() * 26;
      final tp = TextPainter(
        text: TextSpan(
          text: _letters[rnd.nextInt(_letters.length)],
          style: TextStyle(
            color: Colors.white.withOpacity(0.05 + rnd.nextDouble() * 0.05),
            fontSize: size,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return _Floater(
        rnd.nextDouble(),
        (1 + rnd.nextInt(3)).toDouble(),
        rnd.nextDouble(),
        (rnd.nextDouble() - 0.5) * 0.8,
        tp,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bonus = widget.bonus;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bonus
                  ? const [
                      Color(0xFF1A0F08),
                      Color(0xFF2A1810),
                      Color(0xFF3D2817),
                    ]
                  : const [AppColors.bg0, AppColors.bg1, AppColors.bg2],
            ),
          ),
        ),
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BgPainter(_c, _floaters, bonus),
              size: Size.infinite,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Orb {
  final double x, y, r, k, p;
  final Color color;
  const _Orb(this.x, this.y, this.r, this.k, this.p, this.color);
}

class _BgPainter extends CustomPainter {
  final Animation<double> anim;
  final List<_Floater> floaters;
  final bool bonus;
  late final List<_Orb> _orbs;

  _BgPainter(this.anim, this.floaters, this.bonus) : super(repaint: anim) {
    _orbs = bonus
        ? const [
            _Orb(0.15, 0.15, 0.60, 1, 0.0, Color(0xFFFFB300)),
            _Orb(0.90, 0.55, 0.55, 2, 0.3, Color(0xFFFF6F00)),
            _Orb(0.30, 0.95, 0.60, 1, 0.6, Color(0xFFFFD54F)),
          ]
        : const [
            _Orb(0.10, 0.12, 0.65, 1, 0.0, AppColors.violet),
            _Orb(0.95, 0.50, 0.55, 2, 0.3, AppColors.cyan),
            _Orb(0.25, 0.95, 0.65, 1, 0.6, AppColors.pink),
          ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;

    for (final o in _orbs) {
      final cx = size.width * (o.x + 0.08 * sin(2 * pi * (t * o.k + o.p)));
      final cy = size.height * (o.y + 0.05 * cos(2 * pi * (t * o.k + o.p)));
      final r = size.shortestSide * o.r;
      final center = Offset(cx, cy);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [o.color.withOpacity(0.30), o.color.withOpacity(0)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    for (final f in floaters) {
      final prog = (t * f.speed + f.phase) % 1.0;
      final y = size.height * (1.1 - prog * 1.3);
      final x = size.width * f.x + sin(2 * pi * (prog * 2 + f.phase)) * 14;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(f.rot + sin(2 * pi * prog) * 0.25);
      f.tp.paint(canvas, Offset(-f.tp.width / 2, -f.tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.bonus != bonus;
}
