import 'package:flutter/material.dart';

enum AvatarStyle { cartoon, realistic }

extension AvatarStyleLabel on AvatarStyle {
  String get label => switch (this) {
    AvatarStyle.cartoon => 'Cartoon',
    AvatarStyle.realistic => 'Semi-realistic',
  };

  String get blurb => switch (this) {
    AvatarStyle.cartoon => 'A drawn, animated face with lively expressions.',
    AvatarStyle.realistic =>
      'A painted portrait of the same person, crossfaded between expressions.',
  };
}

class Character {
  final String id;
  final String name;
  final int age;
  final String tagline;
  final String bio;
  final String personality;
  final String greeting;

  /// Hint for Android TTS (name + short voice description).
  final String voiceHint;
  final bool feminineVoice;
  final Color accent;
  final CartoonPalette cartoon;
  final String portraitPrefix;

  const Character({
    required this.id,
    required this.name,
    required this.age,
    required this.tagline,
    required this.bio,
    required this.personality,
    required this.greeting,
    required this.voiceHint,
    required this.feminineVoice,
    required this.accent,
    required this.cartoon,
    required this.portraitPrefix,
  });

  String portraitAsset(String expression) =>
      'assets/portraits/${portraitPrefix}_$expression.jpg';
}

class CartoonPalette {
  final Color skin;
  final Color skinShadow;
  final Color skinLight;
  final Color hair;
  final Color hairDark;
  final Color hairLight;
  final Color brow;
  final Color iris;
  final Color irisDark;
  final Color lip;
  final Color lipDark;
  final Color blush;
  final Color shirt;
  final Color shirtDark;
  final Color shirtLight;
  final HairStyle hairStyle;
  final double jawWidth;
  final double chinPoint;
  final double eyeSize;
  final double eyeGap;
  final double browThick;
  final double noseSize;
  final double lipFullness;
  final bool longLashes;
  final bool stubble;
  final bool earrings;

  const CartoonPalette({
    required this.skin,
    required this.skinShadow,
    required this.skinLight,
    required this.hair,
    required this.hairDark,
    required this.hairLight,
    required this.brow,
    required this.iris,
    required this.irisDark,
    required this.lip,
    required this.lipDark,
    required this.blush,
    required this.shirt,
    required this.shirtDark,
    required this.shirtLight,
    required this.hairStyle,
    this.jawWidth = 0.78,
    this.chinPoint = 1.08,
    this.eyeSize = 1.0,
    this.eyeGap = 1.0,
    this.browThick = 1.0,
    this.noseSize = 1.0,
    this.lipFullness = 1.0,
    this.longLashes = false,
    this.stubble = false,
    this.earrings = false,
  });
}

enum HairStyle { longWavy, shortTextured }
