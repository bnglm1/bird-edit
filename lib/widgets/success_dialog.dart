import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class SuccessDialog extends StatefulWidget {
  final List<String> words;
  final int basePoints;
  final int bonusPoints;
  final int hintPenalty;
  final int totalPoints;
  final int levelId;
  final String chapter;
  final VoidCallback onNext;

  const SuccessDialog({
    super.key,
    required this.words,
    required this.basePoints,
    required this.bonusPoints,
    required this.hintPenalty,
    required this.totalPoints,
    required this.levelId,
    required this.chapter,
    required this.onNext,
  });

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with TickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _entry;
  late final AnimationController _pulse;
  late final AnimationController _counter;

  String get _title {
    switch (widget.chapter) {
      case 'Çok Kolay':
        return 'HARİKA!';
      case 'Kolay':
        return 'BRAVO!';
      case 'Orta':
        return 'MUHTEŞEM!';
      case 'Zor':
        return 'İNANILMAZ!';
      case 'Çok Zor':
        return 'EFSANE!';
      case 'Bonus':
        return '👑 BONUS TAMAM!';
      default:
        return 'TEBRİKLER!';
    }
  }

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _counter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _entry.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _counter.forward();
    });
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _entry.dispose();
    _pulse.dispose();
    _counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -20,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 24,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                Colors.amber,
                Colors.orangeAccent,
                Colors.pinkAccent,
                Colors.purpleAccent,
                Colors.cyanAccent,
              ],
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _entry,
                curve: Curves.elasticOut,
              ),
              child: FadeTransition(
                opacity: _entry,
                child: _buildCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1B4E), Color(0xFF1A1A2E), Color(0xFF0F3460)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.amber.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.35),
            blurRadius: 36,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrophy(),
            const SizedBox(height: 14),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.amber,
                shadows: [
                  Shadow(
                    color: Colors.amber.withOpacity(0.8),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bölüm ${widget.levelId} tamamlandı',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildWordsList(),
            const SizedBox(height: 18),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildPoints(),
            const SizedBox(height: 14),
            if (widget.bonusPoints > 0 || widget.hintPenalty > 0)
              _buildBreakdown(),
            const SizedBox(height: 18),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophy() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return Transform.scale(
          scale: 1 + t * 0.08,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFA726)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5 + t * 0.3),
                  blurRadius: 24 + t * 12,
                  spreadRadius: 2 + t * 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🏆', style: TextStyle(fontSize: 44)),
          ),
        );
      },
    );
  }

  /// Bölümdeki tüm çözülen kelimeleri altın kutularla göster
  Widget _buildWordsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.words.map((w) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: List.generate(w.length, (i) {
              return _DelayedAppear(
                delay: Duration(milliseconds: 30 * i),
                child: Container(
                  width: 26,
                  height: 32,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFD54F), Color(0xFFFFA726)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    w[i],
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.amber.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('✨', style: TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoints() {
    return AnimatedBuilder(
      animation: _counter,
      builder: (_, __) {
        final shown =
            (widget.totalPoints * Curves.easeOutCubic.transform(_counter.value))
                .round();
        return Column(
          children: [
            const Text(
              'KAZANILAN PUAN',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFFE082),
                  Color(0xFFFFA726),
                  Color(0xFFFFE082),
                ],
              ).createShader(bounds),
              child: Text(
                '+$shown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBreakdown() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (widget.bonusPoints > 0)
          _chip(
            icon: '⚡',
            label: 'Bonus +${widget.bonusPoints}',
            color: Colors.cyanAccent,
          ),
        if (widget.hintPenalty > 0)
          _chip(
            icon: '💡',
            label: 'İpucu -${widget.hintPenalty}',
            color: Colors.orangeAccent,
          ),
      ],
    );
  }

  Widget _chip({
    required String icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onNext,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: Colors.orange.withOpacity(0.6),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB74D), Color(0xFFFF7043)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            height: 52,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SONRAKİ BÖLÜM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Belirli bir gecikme sonrası fade + slide ile görünen yardımcı widget
class _DelayedAppear extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _DelayedAppear({required this.delay, required this.child});

  @override
  State<_DelayedAppear> createState() => _DelayedAppearState();
}

class _DelayedAppearState extends State<_DelayedAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(0, (1 - curved.value) * 20),
          child: Opacity(
            opacity: curved.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
