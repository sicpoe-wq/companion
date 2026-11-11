import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/emotion.dart';

/// Semi-realistic portrait. Only rigid, uniform motion (tiny drift, tilt and
/// breathing zoom) is applied — never a non-uniform scale — so the face is
/// never stretched or warped.
class RealisticAvatar extends StatelessWidget {
  final Character character;
  final Emotion emotion;
  final double breath;
  final double headSway;

  const RealisticAvatar({
    super.key,
    required this.character,
    required this.emotion,
    this.breath = 0,
    this.headSway = 0,
  });

  @override
  Widget build(BuildContext context) {
    final asset = character.portraitAsset(emotion.name);
    return LayoutBuilder(
      builder: (context, box) {
        final s = math.min(box.maxWidth, box.maxHeight);
        return ColoredBox(
          color: const Color(0xFF2A221C),
          child: Transform.translate(
            offset: Offset(headSway * s * 0.008, breath * s * 0.006),
            child: Transform.rotate(
              angle: headSway * 0.012,
              // Base zoom > 1 so drift/tilt never reveals the frame edge.
              child: Transform.scale(
                scale: 1.06 + breath * 0.01,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, if (current != null) current],
                  ),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Image.asset(
                    asset,
                    key: ValueKey(asset),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.1),
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Image.asset(
                      character.portraitAsset('neutral'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF2A221C),
    alignment: Alignment.center,
    child: Icon(
      Icons.person_rounded,
      size: 72,
      color: character.accent.withValues(alpha: 0.7),
    ),
  );
}
