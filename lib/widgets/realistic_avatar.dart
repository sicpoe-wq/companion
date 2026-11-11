import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/emotion.dart';

class RealisticAvatar extends StatelessWidget {
  final Character character;
  final Emotion emotion;
  final double breath;
  final double headSway;
  final double blink; // 0 open, 1 closed
  final bool talking;
  final double talkPhase;

  const RealisticAvatar({
    super.key,
    required this.character,
    required this.emotion,
    this.breath = 0,
    this.headSway = 0,
    this.blink = 0,
    this.talking = false,
    this.talkPhase = 0,
  });

  @override
  Widget build(BuildContext context) {
    final openAsset = character.portraitAsset(emotion.name);
    final blinkAsset = character.portraitAsset('blink');
    final jaw = talking ? (math.sin(talkPhase) * 0.012 + 0.004) : 0.0;

    return LayoutBuilder(
      builder: (context, box) {
        final s = math.min(box.maxWidth, box.maxHeight);
        return Transform.translate(
          offset: Offset(headSway * s * 0.015, breath * s * 0.012),
          child: Transform.rotate(
            angle: headSway * 0.03,
            child: Transform.scale(
              scale: 1 + breath * 0.018,
              child: Transform(
                alignment: const Alignment(0, 0.45),
                transform: Matrix4.identity()..scaleByDouble(1.0, 1.0 + jaw, 1.0, 1.0),
                child: ColoredBox(
                  color: const Color(0xFF2A221C),
                  child: _portrait(openAsset, blinkAsset),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _portrait(String openAsset, String blinkAsset) {
    final base = AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Image.asset(
        openAsset,
        key: ValueKey(openAsset),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Image.asset(
          character.portraitAsset('neutral'),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
    if (blink <= 0.04) return base;
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        Opacity(
          opacity: blink.clamp(0.0, 1.0),
          child: Image.asset(
            blinkAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF2A221C),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: 72, color: character.accent.withValues(alpha: 0.7)),
      );
}
