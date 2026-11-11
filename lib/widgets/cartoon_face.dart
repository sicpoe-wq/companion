import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/character.dart';
import 'face_pose.dart';

class CartoonFace extends StatelessWidget {
  final CartoonPalette palette;
  final FacePose pose;
  final double breath; // 0..1
  final double headSway; // -1..1
  final bool talking;

  const CartoonFace({
    super.key,
    required this.palette,
    required this.pose,
    this.breath = 0,
    this.headSway = 0,
    this.talking = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CartoonFacePainter(
        palette: palette,
        pose: pose,
        breath: breath,
        headSway: headSway,
        talking: talking,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class CartoonFacePainter extends CustomPainter {
  final CartoonPalette palette;
  final FacePose pose;
  final double breath;
  final double headSway;
  final bool talking;

  CartoonFacePainter({
    required this.palette,
    required this.pose,
    required this.breath,
    required this.headSway,
    required this.talking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.47;
    final s = math.min(size.width, size.height);
    final headR = s * 0.36;

    canvas.save();
    canvas.translate(cx + headSway * headR * 0.04, cy + breath * headR * 0.015);
    canvas.rotate(headSway * 0.045);
    canvas.scale(1 + breath * 0.012, 1 + breath * 0.02);

    _shoulders(canvas, headR);
    _neck(canvas, headR);
    _hairBack(canvas, headR);
    _ears(canvas, headR);
    _head(canvas, headR);
    _blush(canvas, headR);
    _eyes(canvas, headR);
    _brows(canvas, headR);
    _nose(canvas, headR);
    _mouth(canvas, headR);
    if (palette.stubble) _stubble(canvas, headR);
    _hairFront(canvas, headR);
    if (palette.earrings) _earrings(canvas, headR);

    canvas.restore();
  }

  void _shoulders(Canvas canvas, double r) {
    final path = Path()
      ..moveTo(-r * 1.85, r * 2.55)
      ..quadraticBezierTo(-r * 1.7, r * 1.15, -r * 0.55, r * 1.15)
      ..lineTo(r * 0.55, r * 1.15)
      ..quadraticBezierTo(r * 1.7, r * 1.15, r * 1.85, r * 2.55)
      ..close();
    final shirt = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.shirtLight, palette.shirt, palette.shirtDark],
      ).createShader(Rect.fromLTWH(-r * 2, r * 1.0, r * 4, r * 1.8));
    canvas.drawPath(path, shirt);
    // Collar / neckline
    final neckline = Path()
      ..moveTo(-r * 0.42, r * 1.15)
      ..quadraticBezierTo(0, r * 1.42, r * 0.42, r * 1.15);
    canvas.drawPath(
      neckline,
      Paint()
        ..color = palette.shirtDark.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  void _neck(Canvas canvas, double r) {
    final path = Path()
      ..moveTo(-r * 0.28, r * 0.7)
      ..lineTo(-r * 0.32, r * 1.22)
      ..quadraticBezierTo(0, r * 1.38, r * 0.32, r * 1.22)
      ..lineTo(r * 0.28, r * 0.7);
    canvas.drawPath(path, Paint()..color = palette.skin);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.skinShadow.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // neck shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 1.08), width: r * 0.42, height: r * 0.18),
      Paint()..color = palette.skinShadow.withValues(alpha: 0.22),
    );
  }

  void _head(Canvas canvas, double r) {
    final jw = palette.jawWidth;
    final ch = palette.chinPoint;
    final path = Path()
      ..moveTo(0, -r * 1.05)
      ..cubicTo(r * 0.78, -r * 1.05, r * 0.98, -r * 0.35, r * 0.92, r * 0.15)
      ..cubicTo(r * 0.86, r * 0.62, r * jw * 0.9, r * 0.88, 0, r * ch)
      ..cubicTo(-r * jw * 0.9, r * 0.88, -r * 0.86, r * 0.62, -r * 0.92, r * 0.15)
      ..cubicTo(-r * 0.98, -r * 0.35, -r * 0.78, -r * 1.05, 0, -r * 1.05)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.skinLight, palette.skin, palette.skinShadow],
          stops: const [0.15, 0.55, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.2)),
    );
    // soft highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.28, -r * 0.35), width: r * 0.55, height: r * 0.35),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  void _ears(Canvas canvas, double r) {
    final paint = Paint()..color = palette.skin;
    final shadow = Paint()..color = palette.skinShadow.withValues(alpha: 0.35);
    for (final sign in [-1.0, 1.0]) {
      final c = Offset(sign * r * 0.95, r * 0.05);
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 0.28, height: r * 0.42), paint);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 0.14, height: r * 0.22),
        shadow,
      );
    }
  }

  void _blush(Canvas canvas, double r) {
    final a = pose.blush.clamp(0, 1);
    if (a <= 0) return;
    final paint = Paint()
      ..color = palette.blush.withValues(alpha: 0.18 + 0.45 * a)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08);
    for (final sign in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * r * 0.52, r * 0.32),
          width: r * 0.42,
          height: r * 0.22,
        ),
        paint,
      );
    }
  }

  void _eyes(Canvas canvas, double r) {
    final eyeH = r * 0.28 * palette.eyeSize * pose.eyeWide;
    final eyeW = r * 0.30 * palette.eyeSize * pose.eyeWide;
    final gap = r * 0.38 * palette.eyeGap;
    final open = pose.eyeOpen.clamp(0.0, 1.2);
    final visH = eyeH * open.clamp(0.0, 1.0);
    final y = -r * 0.08;
    // talking doesn't change eyes much
    for (final sign in [-1.0, 1.0]) {
      final c = Offset(sign * gap, y);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      // sad inner-corner tilt
      canvas.rotate(-sign * pose.sadEye * 0.12);

      if (open < 0.12) {
        // closed lid line
        final p = Path()
          ..moveTo(-eyeW * 0.55, 0)
          ..quadraticBezierTo(0, eyeH * 0.12, eyeW * 0.55, 0);
        canvas.drawPath(
          p,
          Paint()
            ..color = palette.brow
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.025
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final socket = Path()
          ..addOval(Rect.fromCenter(center: Offset.zero, width: eyeW * 1.05, height: visH * 1.15));
        canvas.save();
        canvas.clipPath(socket);
        canvas.drawPath(socket, Paint()..color = const Color(0xFFF8F6F2));
        // iris
        final look = Offset(pose.lookX * eyeW * 0.18, pose.lookY * visH * 0.2);
        final irisR = eyeW * 0.36;
        canvas.drawCircle(
          look,
          irisR,
          Paint()
            ..shader = RadialGradient(
              colors: [palette.iris, palette.irisDark],
              center: const Alignment(-0.3, -0.3),
            ).createShader(Rect.fromCircle(center: look, radius: irisR)),
        );
        canvas.drawCircle(look, irisR * 0.45, Paint()..color = const Color(0xFF1A100C));
        // highlights
        canvas.drawCircle(
          look + Offset(-irisR * 0.28, -irisR * 0.3),
          irisR * 0.18,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          look + Offset(irisR * 0.22, irisR * 0.18),
          irisR * 0.08,
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
        canvas.restore();

        // upper lid + squint
        final lidClose = (1 - open.clamp(0.0, 1.0)) + pose.lidDrop + pose.squint * 0.35;
        if (lidClose > 0) {
          final lidH = visH * lidClose.clamp(0.0, 0.85);
          final lid = Path()
            ..addRect(Rect.fromLTWH(-eyeW * 0.6, -visH * 0.65, eyeW * 1.2, lidH + visH * 0.15));
          canvas.save();
          canvas.clipPath(socket);
          canvas.drawPath(lid, Paint()..color = palette.skin);
          canvas.restore();
        }
        // outline
        canvas.drawPath(
          socket,
          Paint()
            ..color = palette.brow.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.018,
        );
        // lower lash line
        canvas.drawArc(
          Rect.fromCenter(center: Offset.zero, width: eyeW, height: visH),
          0.15,
          math.pi - 0.3,
          false,
          Paint()
            ..color = palette.brow.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.012,
        );
        if (palette.longLashes) {
          final lash = Paint()
            ..color = palette.brow
            ..strokeWidth = r * 0.02
            ..strokeCap = StrokeCap.round;
          for (final t in [-0.35, 0.0, 0.35]) {
            final x = t * eyeW;
            canvas.drawLine(
              Offset(x, -visH * 0.42),
              Offset(x + (sign > 0 ? 1 : -1) * r * 0.02, -visH * 0.42 - r * 0.07),
              lash,
            );
          }
        }
      }
      canvas.restore();
    }
  }

  void _brows(Canvas canvas, double r) {
    final gap = r * 0.38 * palette.eyeGap;
    final y0 = -r * 0.36 + pose.browY * r * 0.2 - pose.browLift * r * 0.12;
    final thick = r * 0.045 * palette.browThick;
    final paint = Paint()
      ..color = palette.brow
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;
    for (final sign in [-1.0, 1.0]) {
      final together = pose.browInnerTogether * r * 0.08;
      final inner = Offset(sign * (gap - r * 0.22 + together), y0 - sign * 0 * r + -sign * 0);
      // angle: positive = inner up
      final innerY = y0 - pose.browAngle * r * 0.10;
      final outerY = y0 + pose.browAngle * r * 0.08;
      final path = Path()
        ..moveTo(sign * (gap - r * 0.22 + together), innerY)
        ..quadraticBezierTo(
          sign * gap,
          y0 - r * 0.04,
          sign * (gap + r * 0.22),
          outerY,
        );
      canvas.drawPath(path, paint);
      // avoid unused warning
      // ignore: unused_local_variable
      final _ = inner;
    }
  }

  void _nose(Canvas canvas, double r) {
    final y = r * 0.22 * palette.noseSize;
    final w = r * 0.09 * palette.noseSize;
    final path = Path()
      ..moveTo(0, -r * 0.02)
      ..lineTo(-w, y)
      ..quadraticBezierTo(0, y + r * 0.04, w * 0.7, y);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.skinShadow.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.028
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(w * 0.35, y + r * 0.01),
      r * 0.025,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _mouth(Canvas canvas, double r) {
    var open = pose.mouthOpen;
    if (talking) {
      // Approximate visemes with a gentle oscillation from breath-like phase
      // (the parent widget feeds a changing breath/headSway; talking itself is a flag).
      // We piggy-back on headSway as a time proxy is not available, so the
      // AvatarLife widget should bake talking openness into the pose. If not,
      // give a modest open mouth.
      open = math.max(open, 0.22);
    }
    final y = r * 0.52;
    final w = r * pose.mouthWidth * 0.55;
    final curve = pose.mouthCurve * r * 0.18;
    final lips = palette.lip;
    final dark = palette.lipDark;

    if (open < 0.08) {
      final path = Path()
        ..moveTo(-w, y)
        ..quadraticBezierTo(0, y + curve, w, y);
      canvas.drawPath(
        path,
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.038 * palette.lipFullness
          ..strokeCap = StrokeCap.round,
      );
      // upper lip highlight
      canvas.drawPath(
        Path()
          ..moveTo(-w * 0.7, y - r * 0.01)
          ..quadraticBezierTo(0, y - r * 0.02 + curve * 0.3, w * 0.7, y - r * 0.01),
        Paint()
          ..color = lips.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final h = r * 0.22 * open + r * 0.06;
      final path = Path()
        ..moveTo(-w, y)
        ..quadraticBezierTo(0, y + curve - h * 0.15, w, y)
        ..quadraticBezierTo(0, y + curve + h, -w, y)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF4A1820));
      if (pose.teeth > 0.05) {
        final teethRect = Rect.fromCenter(
          center: Offset(0, y + curve * 0.3 + h * 0.15),
          width: w * 1.5,
          height: h * 0.4 * pose.teeth,
        );
        canvas.save();
        canvas.clipPath(path);
        canvas.drawRRect(
          RRect.fromRectAndRadius(teethRect, Radius.circular(r * 0.02)),
          Paint()..color = const Color(0xFFFFF6EC),
        );
        canvas.restore();
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.028
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _stubble(Canvas canvas, double r) {
    final paint = Paint()
      ..color = palette.hairDark.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final rnd = math.Random(7);
    for (var i = 0; i < 90; i++) {
      final x = (rnd.nextDouble() - 0.5) * r * 1.2;
      final y = r * 0.45 + rnd.nextDouble() * r * 0.5;
      // stay on jaw
      if (x.abs() > r * 0.7 && y < r * 0.7) continue;
      canvas.drawLine(Offset(x, y), Offset(x + 0.6, y + r * 0.03), paint);
    }
  }

  void _hairBack(Canvas canvas, double r) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.hair, palette.hairDark],
      ).createShader(Rect.fromLTWH(-r * 2, -r * 1.5, r * 4, r * 3.8));
    if (palette.hairStyle == HairStyle.longWavy) {
      // One continuous mass behind the head, down past the shoulders.
      final mass = Path()
        ..moveTo(-r * 0.15, -r * 1.15)
        ..cubicTo(-r * 1.05, -r * 1.25, -r * 1.45, -r * 0.15, -r * 1.28, r * 2.05)
        ..cubicTo(-r * 1.05, r * 2.2, -r * 0.7, r * 1.85, -r * 0.42, r * 1.15)
        ..lineTo(-r * 0.55, r * 0.2)
        ..lineTo(r * 0.55, r * 0.2)
        ..lineTo(r * 0.42, r * 1.15)
        ..cubicTo(r * 0.7, r * 1.9, r * 1.1, r * 2.25, r * 1.22, r * 2.1)
        ..cubicTo(r * 1.5, -r * 0.1, r * 1.05, -r * 1.25, r * 0.15, -r * 1.15)
        ..close();
      canvas.drawPath(mass, fill);
    } else {
      final cap = Path()
        ..moveTo(-r * 1.0, r * 0.16)
        ..cubicTo(-r * 1.18, -r * 0.25, -r * 0.85, -r * 1.28, 0, -r * 1.28)
        ..cubicTo(r * 0.85, -r * 1.28, r * 1.18, -r * 0.25, r * 1.0, r * 0.16)
        ..quadraticBezierTo(r * 0.72, -r * 0.15, 0, -r * 0.08)
        ..quadraticBezierTo(-r * 0.72, -r * 0.15, -r * 1.0, r * 0.16)
        ..close();
      canvas.drawPath(cap, fill);
    }
  }

  void _hairFront(Canvas canvas, double r) {
    final fill = Paint()..color = palette.hair;
    final dark = Paint()..color = palette.hairDark;
    final light = Paint()
      ..color = palette.hairLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.028
      ..strokeCap = StrokeCap.round;
    if (palette.hairStyle == HairStyle.longWavy) {
      // Full cap over the skull so no scalp shows, with a thin side part.
      final cap = Path()
        ..moveTo(-r * 0.95, r * 0.02)
        ..cubicTo(-r * 1.05, -r * 0.45, -r * 0.7, -r * 1.22, 0, -r * 1.22)
        ..cubicTo(r * 0.7, -r * 1.22, r * 1.05, -r * 0.45, r * 0.95, r * 0.02)
        ..cubicTo(r * 0.55, -r * 0.55, r * 0.2, -r * 0.62, 0.0, -r * 0.58)
        ..cubicTo(-r * 0.25, -r * 0.7, -r * 0.6, -r * 0.55, -r * 0.95, r * 0.02)
        ..close();
      canvas.drawPath(cap, fill);
      // Soft bangs along the forehead, no bald stripe.
      final bangs = Path()
        ..moveTo(-r * 0.72, -r * 0.55)
        ..cubicTo(-r * 0.15, -r * 1.08, r * 0.55, -r * 1.0, r * 0.88, -r * 0.28)
        ..cubicTo(r * 0.5, -r * 0.42, r * 0.15, -r * 0.22, -r * 0.05, -r * 0.48)
        ..cubicTo(-r * 0.28, -r * 0.72, -r * 0.52, -r * 0.62, -r * 0.72, -r * 0.55)
        ..close();
      canvas.drawPath(bangs, fill);
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.35, -r * 0.95)
          ..cubicTo(-r * 0.05, -r * 1.05, r * 0.25, -r * 0.9, r * 0.5, -r * 0.6),
        light,
      );
    } else {
      final tufts = Path()
        ..moveTo(-r * 0.95, r * 0.05)
        ..cubicTo(-r * 0.8, -r * 1.15, -r * 0.15, -r * 1.35, 0, -r * 1.2)
        ..cubicTo(r * 0.2, -r * 1.4, r * 0.85, -r * 1.2, r * 0.95, r * 0.05)
        ..cubicTo(r * 0.4, -r * 0.55, -r * 0.4, -r * 0.55, -r * 0.95, r * 0.05)
        ..close();
      canvas.drawPath(tufts, fill);
      for (final sign in [-1.0, 1.0]) {
        final sb = Path()
          ..moveTo(sign * r * 0.92, -r * 0.02)
          ..cubicTo(sign * r * 1.05, r * 0.18, sign * r * 0.95, r * 0.42, sign * r * 0.8, r * 0.52)
          ..cubicTo(sign * r * 0.84, r * 0.22, sign * r * 0.84, r * 0.06, sign * r * 0.92, -r * 0.02)
          ..close();
        canvas.drawPath(sb, dark);
      }
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.15, -r * 1.15)
          ..cubicTo(0, -r * 1.25, r * 0.28, -r * 1.15, r * 0.42, -r * 0.9),
        light,
      );
    }
  }

  void _earrings(Canvas canvas, double r) {
    final paint = Paint()
      ..color = const Color(0xFFE8C56B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.028;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(sign * r * 0.98, r * 0.28), r * 0.07, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CartoonFacePainter old) =>
      old.pose != pose ||
      old.palette != palette ||
      old.breath != breath ||
      old.headSway != headSway ||
      old.talking != talking;
}
