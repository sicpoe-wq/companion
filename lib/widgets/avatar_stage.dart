import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/character.dart';
import '../models/emotion.dart';
import 'cartoon_face.dart';
import 'face_pose.dart';
import 'realistic_avatar.dart';

class AvatarStage extends StatefulWidget {
  final Character character;
  final AvatarStyle style;
  final Emotion emotion;
  final bool talking;
  final Color ring;

  const AvatarStage({
    super.key,
    required this.character,
    required this.style,
    required this.emotion,
    required this.talking,
    required this.ring,
  });

  @override
  State<AvatarStage> createState() => _AvatarStageState();
}

class _AvatarStageState extends State<AvatarStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  FacePose _current = FacePose.forEmotion(Emotion.neutral);
  FacePose _from = FacePose.forEmotion(Emotion.neutral);
  FacePose _to = FacePose.forEmotion(Emotion.neutral);
  double _blend = 1;
  Duration _blendStart = Duration.zero;
  static const _blendFor = Duration(milliseconds: 380);

  double _blink = 0;
  Duration? _nextBlink;
  Duration? _blinkStart;
  bool _doublePending = false;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _current = FacePose.forEmotion(widget.emotion);
    _from = _current;
    _to = _current;
    _scheduleBlink(Duration.zero);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(covariant AvatarStage old) {
    super.didUpdateWidget(old);
    if (old.emotion != widget.emotion) {
      _from = _current;
      _to = FacePose.forEmotion(widget.emotion);
      _blend = 0;
      _blendStart = _elapsed;
    }
  }

  void _scheduleBlink(Duration now) {
    final wait = Duration(milliseconds: 2400 + _rng.nextInt(3200));
    _nextBlink = now + wait;
    _doublePending = _rng.nextDouble() < 0.18;
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;

    if (_blend < 1) {
      final t =
          (elapsed - _blendStart).inMilliseconds / _blendFor.inMilliseconds;
      _blend = t.clamp(0.0, 1.0);
      final curved = Curves.easeInOut.transform(_blend);
      _current = _from.lerp(_to, curved);
    }

    // Blink: 90ms close, 80ms open.
    if (_blinkStart != null) {
      final ms = (elapsed - _blinkStart!).inMilliseconds;
      if (ms < 90) {
        _blink = ms / 90;
      } else if (ms < 170) {
        _blink = 1 - (ms - 90) / 80;
      } else {
        _blink = 0;
        if (_doublePending) {
          _doublePending = false;
          _blinkStart = elapsed + const Duration(milliseconds: 80);
        } else {
          _blinkStart = null;
          _scheduleBlink(elapsed);
        }
      }
    } else if (_nextBlink != null && elapsed >= _nextBlink!) {
      _blinkStart = elapsed;
    }

    // Idle motion is continuous.
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _elapsed.inMilliseconds / 1000.0;
    final breath = (math.sin(t * math.pi * 0.4) + 1) / 2;
    final sway = math.sin(t * 0.55) * 0.7 + math.sin(t * 0.23) * 0.3;
    final talkPhase = t * math.pi * 5.5;

    var pose = _current;
    if (_blink > 0.02) {
      pose = pose.copyWith(eyeOpen: pose.eyeOpen * (1 - _blink));
    }
    if (widget.talking) {
      final flutter = (math.sin(talkPhase) * 0.5 + 0.5) * 0.36 + 0.10;
      pose = pose.copyWith(mouthOpen: math.max(pose.mouthOpen, flutter));
    }

    final ring = widget.ring;
    // Always a true circle: size to the shorter side of whatever box we get,
    // so the portrait is never stretched into an ellipse.
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(
          box.maxWidth.isFinite ? box.maxWidth : 260.0,
          box.maxHeight.isFinite ? box.maxHeight : 260.0,
        );
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: _framed(pose, breath, sway, talkPhase, ring),
          ),
        );
      },
    );
  }

  Widget _framed(
    FacePose pose,
    double breath,
    double sway,
    double talkPhase,
    Color ring,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring.withValues(alpha: 0.9), width: 3),
        ),
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: widget.style == AvatarStyle.cartoon
              ? ColoredBox(
                  color: const Color(0xFF2A221C),
                  child: CartoonFace(
                    palette: widget.character.cartoon,
                    pose: pose,
                    breath: breath,
                    headSway: sway,
                    talking: widget.talking,
                  ),
                )
              : RealisticAvatar(
                  character: widget.character,
                  emotion: widget.emotion,
                  breath: breath,
                  headSway: sway,
                ),
        ),
      ),
    );
  }
}

Color emotionRing(Emotion e, Color fallback) => switch (e) {
  Emotion.happy => const Color(0xFFE8B86D),
  Emotion.laughing => const Color(0xFFF0C36A),
  Emotion.excited => const Color(0xFFFF9B6A),
  Emotion.sad => const Color(0xFF7EA4C8),
  Emotion.angry => const Color(0xFFE07A5F),
  Emotion.surprised => const Color(0xFF8ED0E0),
  Emotion.thoughtful => const Color(0xFFB7A0D9),
  Emotion.embarrassed => const Color(0xFFE8A0B0),
  Emotion.worried => const Color(0xFFC4B07A),
  Emotion.neutral => fallback,
};
