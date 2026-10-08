import 'dart:math';

import 'package:flutter/material.dart';

class LetterCircle extends StatefulWidget {
  final List<String> letters;
  final bool Function(String word) onSubmit;
  final Color accentColor;

  const LetterCircle({
    super.key,
    required this.letters,
    required this.onSubmit,
    this.accentColor = const Color(0xFF5BE3F5),
  });

  @override
  State<LetterCircle> createState() => _LetterCircleState();
}

class _LetterCircleState extends State<LetterCircle>
    with SingleTickerProviderStateMixin {
  List<int> _selected = [];
  Offset? _fingerPos;
  late AnimationController _shake;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shake, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(
          width: size,
          height: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d.localPosition, size),
            onPanUpdate: (d) => _onPanUpdate(d.localPosition, size),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: () => setState(() {
              _selected = [];
              _fingerPos = null;
            }),
            child: AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, _) {
                final shakeOffset = _shake.isAnimating
                    ? sin(_shakeAnim.value * pi * 6) *
                        12 *
                        (1 - _shakeAnim.value)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: _CirclePainter(
                      letters: widget.letters,
                      selected: _selected,
                      fingerPos: _fingerPos,
                      accentColor: widget.accentColor,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Offset> _positions(double size) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 42;
    final n = widget.letters.length;
    return List.generate(n, (i) {
      final angle = -pi / 2 + 2 * pi * i / n;
      return Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    });
  }

  int? _hit(Offset pos, List<Offset> positions) {
    for (int i = 0; i < positions.length; i++) {
      if ((positions[i] - pos).distance < 44) return i;
    }
    return null;
  }

  void _onPanStart(Offset pos, double size) {
    final positions = _positions(size);
    final idx = _hit(pos, positions);
    if (idx == null) return;
    setState(() {
      _selected = [idx];
      _fingerPos = pos;
    });
  }

  void _onPanUpdate(Offset pos, double size) {
    final positions = _positions(size);
    final idx = _hit(pos, positions);
    setState(() {
      _fingerPos = pos;
      if (idx == null) return;
      if (_selected.length >= 2 && idx == _selected[_selected.length - 2]) {
        _selected.removeLast();
      } else if (!_selected.contains(idx)) {
        _selected.add(idx);
      }
    });
  }

  void _onPanEnd() {
    final word = _selected.map((i) => widget.letters[i]).join();
    final valid = word.length >= 2 && widget.onSubmit(word);

    setState(() {
      _selected = [];
      _fingerPos = null;
    });

    if (!valid && word.length >= 2) _shake.forward(from: 0);
  }
}

class _CirclePainter extends CustomPainter {
  final List<String> letters;
  final List<int> selected;
  final Offset? fingerPos;
  final Color accentColor;

  _CirclePainter({
    required this.letters,
    required this.selected,
    required this.fingerPos,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 42;
    final n = letters.length;
    final positions = List.generate(n, (i) {
      final angle = -pi / 2 + 2 * pi * i / n;
      return Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    });

    // Arka plan halka
    canvas.drawCircle(
      center,
      radius + 38,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withOpacity(0.18),
            accentColor.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 38)),
    );

    // Seçili harf çizgileri
    if (selected.isNotEmpty) {
      final path = Path()
        ..moveTo(positions[selected[0]].dx, positions[selected[0]].dy);
      for (int i = 1; i < selected.length; i++) {
        path.lineTo(positions[selected[i]].dx, positions[selected[i]].dy);
      }
      if (fingerPos != null) {
        path.lineTo(fingerPos!.dx, fingerPos!.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accentColor.withOpacity(0.75)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Harfler
    for (int i = 0; i < n; i++) {
      final pos = positions[i];
      final isSel = selected.contains(i);

      if (isSel) {
        canvas.drawCircle(
          pos,
          34,
          Paint()
            ..color = accentColor.withOpacity(0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      canvas.drawCircle(
        pos,
        32,
        Paint()..color = isSel ? accentColor : Colors.white.withOpacity(0.92),
      );

      canvas.drawCircle(
        pos,
        32,
        Paint()
          ..color = isSel ? Colors.white : accentColor.withOpacity(0.35)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: TextStyle(
            color: isSel ? Colors.white : const Color(0xFF1A1033),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CirclePainter old) => true;
}
