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

  void _home(Canvas canvas, Size size) {
    final c = scenario.colors;
    // window
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.62, size.height * 0.08, size.width * 0.28, size.height * 0.22),
      const Radius.circular(12),
    );
    canvas.drawRRect(win, Paint()..color = c.sun.withValues(alpha: 0.35));
    canvas.drawRRect(
      win,
      Paint()
        ..color = c.accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final midX = win.center.dx;
    final midY = win.center.dy;
    canvas.drawLine(Offset(midX, win.top), Offset(midX, win.bottom), Paint()..color = c.accent.withValues(alpha: 0.4)..strokeWidth = 2);
    canvas.drawLine(Offset(win.left, midY), Offset(win.right, midY), Paint()..color = c.accent.withValues(alpha: 0.4)..strokeWidth = 2);
    // plant
    final pot = Path()
      ..moveTo(size.width * 0.12, size.height * 0.36)
      ..lineTo(size.width * 0.18, size.height * 0.36)
      ..lineTo(size.width * 0.17, size.height * 0.42)
      ..lineTo(size.width * 0.13, size.height * 0.42)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFF8C5340));
    final leaf = Paint()..color = const Color(0xFF3E7A4C).withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.15, size.height * 0.30), width: 28, height: 46), leaf);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.11, size.height * 0.31), width: 22, height: 36), leaf);
  }

  void _walk(Canvas canvas, Size size) {
    final c = scenario.colors;
    // sun
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.10), 28, Paint()..color = c.sun);
    // hills
    final hill = Path()
      ..moveTo(0, size.height * 0.36)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.22, size.width * 0.5, size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.44, size.width, size.height * 0.30)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = c.ground.withValues(alpha: 0.85));
    // trees
    final trunk = Paint()..color = const Color(0xFF4A2E1C);
    final foliage = Paint()..color = const Color(0xFF2E6B3A);
    for (final x in [0.12, 0.28, 0.78, 0.92]) {
      final px = size.width * x;
      canvas.drawRect(Rect.fromCenter(center: Offset(px, size.height * 0.34), width: 8, height: 40), trunk);
      canvas.drawCircle(Offset(px, size.height * 0.26), 22, foliage);
    }
    // path
    final path = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.7, size.width * 0.45, size.height * 0.42);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC9B896).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round,
    );
  }

  void _cafe(Canvas canvas, Size size) {
    final c = scenario.colors;
    // hanging lamps
    for (final x in [0.2, 0.5, 0.8]) {
      final px = size.width * x;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height * 0.10), Paint()..color = c.accent..strokeWidth = 2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, size.height * 0.13), width: 36, height: 22),
        Paint()..color = c.sun.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        Offset(px, size.height * 0.16),
        22,
        Paint()
          ..color = c.sun.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }
    // window
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.18, size.width * 0.28, size.height * 0.18),
      const Radius.circular(8),
    );
    canvas.drawRRect(win, Paint()..color = const Color(0xFF1A2230).withValues(alpha: 0.6));
    canvas.drawRRect(win, Paint()..color = c.accent.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _game(Canvas canvas, Size size) {
    final rnd = math.Random(scenario.id.hashCode);
    final paint = Paint()..color = scenario.colors.accent.withValues(alpha: 0.18);
    for (var i = 0; i < 18; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.45;
      canvas.drawCircle(Offset(x, y), 3 + rnd.nextDouble() * 5, paint);
    }
    // a couple of cards
    final card = Paint()..color = Colors.white.withValues(alpha: 0.12);
    canvas.save();
    canvas.translate(size.width * 0.15, size.height * 0.16);
    canvas.rotate(-0.25);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 40, 56), const Radius.circular(6)), card);
    canvas.restore();
    canvas.save();
    canvas.translate(size.width * 0.78, size.height * 0.12);
    canvas.rotate(0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 40, 56), const Radius.circular(6)), card);
    canvas.restore();
  }

  void _story(Canvas canvas, Size size) {
    final c = scenario.colors;
    // moon
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.10), 26, Paint()..color = c.sun);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.09), 20, Paint()..color = c.top);
    // stars
    final rnd = math.Random(3);
    final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.3), rnd.nextDouble() * 1.8 + 0.6, star);
    }
    // forest silhouette
    final ground = Path()..moveTo(0, size.height * 0.42);
    for (var i = 0; i <= 8; i++) {
      final x = size.width * (i / 8);
      final peak = size.height * (0.22 + (i.isEven ? 0.04 : 0.10));
      ground.lineTo(x - size.width * 0.04, size.height * 0.42);
      ground.lineTo(x, peak);
      ground.lineTo(x + size.width * 0.04, size.height * 0.42);
    }
    ground
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF08061A).withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.scenario.id != scenario.id;
}
