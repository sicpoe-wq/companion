import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scenario.dart';

class SceneBackground extends StatelessWidget {
  final Scenario scenario;
  const SceneBackground({super.key, required this.scenario});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scenario.colors.top, scenario.colors.bottom],
        ),
      ),
      child: CustomPaint(
        painter: _ScenePainter(scenario),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final Scenario scenario;
  _ScenePainter(this.scenario);

  @override
  void paint(Canvas canvas, Size size) {
    switch (scenario.id) {
      case 'walk':
        _walk(canvas, size);
      case 'cafe':
        _cafe(canvas, size);
      case 'twenty_questions':
      case 'trivia':
        _game(canvas, size);
      case 'story':
        _story(canvas, size);
      default:
        _home(canvas, size);
    }
  }

  // All scenes are soft, blurred ambient light only — no hard-edged props
  // that could read as glitches behind the avatar or the app bar.
  Paint _glow(Color color, double blur) => Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  void _bokeh(
    Canvas canvas,
    Size size,
    Color color,
    int seed,
    int count,
    double maxY,
  ) {
    final rnd = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * maxY;
      final r = size.width * (0.025 + rnd.nextDouble() * 0.05);
      canvas.drawCircle(
        Offset(x, y),
        r,
        _glow(color.withValues(alpha: 0.08 + rnd.nextDouble() * 0.10), r * 0.6),
      );
    }
  }

  void _softHorizon(
    Canvas canvas,
    Size size,
    Color color,
    double y,
    double amp,
  ) {
    final hill = Path()
      ..moveTo(0, size.height * y)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * (y - amp),
        size.width * 0.6,
        size.height * y,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * (y + amp * 0.6),
        size.width,
        size.height * (y - amp * 0.4),
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, _glow(color, 18));
  }

  void _home(Canvas canvas, Size size) {
    final c = scenario.colors;
    // Warm lamp glow from one side + gentle bokeh.
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.16),
      size.width * 0.35,
      _glow(c.sun.withValues(alpha: 0.22), 60),
    );
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.40),
      size.width * 0.28,
      _glow(c.accent.withValues(alpha: 0.10), 50),
    );
    _bokeh(canvas, size, c.sun, 7, 9, 0.45);
  }

  void _walk(Canvas canvas, Size size) {
    final c = scenario.colors;
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.10),
      size.width * 0.10,
      _glow(c.sun.withValues(alpha: 0.9), 10),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.10),
      size.width * 0.30,
      _glow(c.sun.withValues(alpha: 0.18), 50),
    );
    _softHorizon(canvas, size, c.ground.withValues(alpha: 0.55), 0.38, 0.06);
    _softHorizon(canvas, size, c.ground.withValues(alpha: 0.75), 0.46, 0.04);
  }

  void _cafe(Canvas canvas, Size size) {
    final c = scenario.colors;
    // Out-of-focus warm lights, like a cafe behind the person.
    for (final x in [0.12, 0.5, 0.88]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * 0.12),
        size.width * 0.12,
        _glow(c.sun.withValues(alpha: 0.22), 30),
      );
    }
    _bokeh(canvas, size, c.sun, 11, 12, 0.45);
  }

  void _game(Canvas canvas, Size size) {
    final c = scenario.colors;
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.12),
      size.width * 0.3,
      _glow(c.accent.withValues(alpha: 0.14), 60),
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.3),
      size.width * 0.25,
      _glow(c.sun.withValues(alpha: 0.10), 50),
    );
    _bokeh(canvas, size, c.accent, scenario.id.length, 10, 0.45);
  }

  void _story(Canvas canvas, Size size) {
    final c = scenario.colors;
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.10),
      size.width * 0.06,
      _glow(c.sun.withValues(alpha: 0.85), 4),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.10),
      size.width * 0.22,
      _glow(c.sun.withValues(alpha: 0.12), 40),
    );
    final rnd = math.Random(3);
    final star = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 22; i++) {
      canvas.drawCircle(
        Offset(
          rnd.nextDouble() * size.width,
          rnd.nextDouble() * size.height * 0.3,
        ),
        rnd.nextDouble() * 1.4 + 0.5,
        star,
      );
    }
    _softHorizon(
      canvas,
      size,
      const Color(0xFF08061A).withValues(alpha: 0.7),
      0.42,
      0.05,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.scenario.id != scenario.id;
}
