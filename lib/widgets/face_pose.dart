import 'dart:ui';

import '../models/emotion.dart';

/// Numeric knobs that describe a cartoon face. Interpolated between emotions.
class FacePose {
  final double eyeOpen; // 0 closed, 1 open
  final double eyeWide; // extra scale
  final double lidDrop; // sleepy / embarrassed upper lid
  final double browY;
  final double browAngle; // + = inner up (sad), - = inner down (angry)
  final double browInnerTogether;
  final double mouthCurve; // + smile, - frown
  final double mouthOpen;
  final double mouthWidth;
  final double blush;
  final double lookX;
  final double lookY;
  final double browLift; // overall
  final double teeth;
  final double sadEye; // inner corner lift
  final double squint;

  const FacePose({
    this.eyeOpen = 1,
    this.eyeWide = 1,
    this.lidDrop = 0,
    this.browY = 0,
    this.browAngle = 0,
    this.browInnerTogether = 0,
    this.mouthCurve = 0.15,
    this.mouthOpen = 0,
    this.mouthWidth = 0.55,
    this.blush = 0.15,
    this.lookX = 0,
    this.lookY = 0,
    this.browLift = 0,
    this.teeth = 0,
    this.sadEye = 0,
    this.squint = 0,
  });

  FacePose lerp(FacePose o, double t) => FacePose(
        eyeOpen: lerpDouble(eyeOpen, o.eyeOpen, t)!,
        eyeWide: lerpDouble(eyeWide, o.eyeWide, t)!,
        lidDrop: lerpDouble(lidDrop, o.lidDrop, t)!,
        browY: lerpDouble(browY, o.browY, t)!,
        browAngle: lerpDouble(browAngle, o.browAngle, t)!,
        browInnerTogether: lerpDouble(browInnerTogether, o.browInnerTogether, t)!,
        mouthCurve: lerpDouble(mouthCurve, o.mouthCurve, t)!,
        mouthOpen: lerpDouble(mouthOpen, o.mouthOpen, t)!,
        mouthWidth: lerpDouble(mouthWidth, o.mouthWidth, t)!,
        blush: lerpDouble(blush, o.blush, t)!,
        lookX: lerpDouble(lookX, o.lookX, t)!,
        lookY: lerpDouble(lookY, o.lookY, t)!,
        browLift: lerpDouble(browLift, o.browLift, t)!,
        teeth: lerpDouble(teeth, o.teeth, t)!,
        sadEye: lerpDouble(sadEye, o.sadEye, t)!,
        squint: lerpDouble(squint, o.squint, t)!,
      );

  FacePose copyWith({
    double? eyeOpen,
    double? eyeWide,
    double? lidDrop,
    double? browY,
    double? browAngle,
    double? browInnerTogether,
    double? mouthCurve,
    double? mouthOpen,
    double? mouthWidth,
    double? blush,
    double? lookX,
    double? lookY,
    double? browLift,
    double? teeth,
    double? sadEye,
    double? squint,
  }) {
    return FacePose(
      eyeOpen: eyeOpen ?? this.eyeOpen,
      eyeWide: eyeWide ?? this.eyeWide,
      lidDrop: lidDrop ?? this.lidDrop,
      browY: browY ?? this.browY,
      browAngle: browAngle ?? this.browAngle,
      browInnerTogether: browInnerTogether ?? this.browInnerTogether,
      mouthCurve: mouthCurve ?? this.mouthCurve,
      mouthOpen: mouthOpen ?? this.mouthOpen,
      mouthWidth: mouthWidth ?? this.mouthWidth,
      blush: blush ?? this.blush,
      lookX: lookX ?? this.lookX,
      lookY: lookY ?? this.lookY,
      browLift: browLift ?? this.browLift,
      teeth: teeth ?? this.teeth,
      sadEye: sadEye ?? this.sadEye,
      squint: squint ?? this.squint,
    );
  }

  static FacePose forEmotion(Emotion e) => switch (e) {
        Emotion.neutral => const FacePose(),
        Emotion.happy => const FacePose(
            mouthCurve: 0.72,
            mouthWidth: 0.68,
            blush: 0.28,
            eyeOpen: 0.92,
            squint: 0.15,
          ),
        Emotion.laughing => const FacePose(
            mouthCurve: 0.85,
            mouthOpen: 0.55,
            mouthWidth: 0.78,
            teeth: 1,
            blush: 0.4,
            eyeOpen: 0.55,
            squint: 0.7,
            browLift: 0.1,
          ),
        Emotion.sad => const FacePose(
            mouthCurve: -0.55,
            mouthWidth: 0.42,
            browAngle: 0.55,
            browY: 0.08,
            sadEye: 0.8,
            eyeOpen: 0.9,
            lookY: 0.12,
            blush: 0.1,
          ),
        Emotion.angry => const FacePose(
            mouthCurve: -0.4,
            mouthWidth: 0.4,
            mouthOpen: 0.04,
            browAngle: -0.7,
            browInnerTogether: 0.7,
            browY: -0.08,
            squint: 0.35,
            eyeOpen: 0.88,
          ),
        Emotion.surprised => const FacePose(
            eyeOpen: 1.15,
            eyeWide: 1.18,
            mouthOpen: 0.55,
            mouthWidth: 0.32,
            mouthCurve: 0.05,
            browLift: 0.45,
            browY: 0.18,
            teeth: 0.15,
          ),
        Emotion.thoughtful => const FacePose(
            mouthCurve: 0.02,
            mouthWidth: 0.36,
            browY: 0.06,
            browAngle: 0.18,
            lookX: 0.35,
            lookY: -0.08,
            lidDrop: 0.18,
            eyeOpen: 0.92,
          ),
        Emotion.embarrassed => const FacePose(
            mouthCurve: 0.35,
            mouthWidth: 0.4,
            blush: 0.95,
            lookX: 0.28,
            lookY: 0.22,
            lidDrop: 0.28,
            eyeOpen: 0.8,
            browY: 0.05,
          ),
        Emotion.excited => const FacePose(
            mouthCurve: 0.8,
            mouthOpen: 0.28,
            mouthWidth: 0.7,
            teeth: 0.7,
            eyeOpen: 1.08,
            eyeWide: 1.1,
            browLift: 0.28,
            blush: 0.35,
          ),
        Emotion.worried => const FacePose(
            mouthCurve: -0.2,
            mouthWidth: 0.38,
            mouthOpen: 0.08,
            browAngle: 0.45,
            browInnerTogether: 0.25,
            browY: 0.12,
            eyeOpen: 1.05,
            lookY: 0.05,
            sadEye: 0.35,
          ),
      };
}
