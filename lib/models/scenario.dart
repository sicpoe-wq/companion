import 'package:flutter/material.dart';

class Scenario {
  final String id;
  final String name;
  final String blurb;
  final String prompt;
  final IconData icon;
  final SceneColors colors;

  /// Opening line the character says when this scene starts mid-chat.
  final String arrivalLine;

  const Scenario({
    required this.id,
    required this.name,
    required this.blurb,
    required this.prompt,
    required this.icon,
    required this.colors,
    required this.arrivalLine,
  });
}

class SceneColors {
  final Color top;
  final Color bottom;
  final Color accent;
  final Color sun;
  final Color ground;

  const SceneColors({
    required this.top,
    required this.bottom,
    required this.accent,
    required this.sun,
    required this.ground,
  });
}
