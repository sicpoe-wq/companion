import 'package:flutter/material.dart';

import '../models/scenario.dart';

const hangout = Scenario(
  id: 'hangout',
  name: 'Hang out',
  blurb: 'Nowhere special — just talk.',
  prompt:
      'You are hanging out together in a cozy room at home. Casual, unhurried conversation. '
      'You may suggest an activity if the moment feels right.',
  icon: Icons.weekend_rounded,
  arrivalLine: "Alright, back home. What's on your mind?",
  colors: SceneColors(
    top: Color(0xFF3A2A22),
    bottom: Color(0xFF1A1410),
    accent: Color(0xFFE8A87C),
    sun: Color(0xFFFFE2B8),
    ground: Color(0xFF2A211C),
  ),
);

const walk = Scenario(
  id: 'walk',
  name: 'Go for a walk',
  blurb: 'A path, some trees, nowhere to be.',
  prompt:
      'You are walking together outside on a pleasant path through a park. Mention little things you notice — '
      'light, trees, other people, the weather — and keep the conversation moving as you walk. '
      'Do not narrate every footstep; just be there with them.',
  icon: Icons.park_rounded,
  arrivalLine: "Nice day for it. Lead the way — or I will.",
  colors: SceneColors(
    top: Color(0xFF6BA3C9),
    bottom: Color(0xFF1E3A28),
    accent: Color(0xFFB7E39A),
    sun: Color(0xFFFFF1B5),
    ground: Color(0xFF3D6B3A),
  ),
);

const cafe = Scenario(
  id: 'cafe',
  name: 'Cafe',
  blurb: 'Warm lights, a table for two.',
  prompt:
      'You are sitting together at a small, cozy cafe. There is coffee or tea, low music, and other people murmuring nearby. '
      'Be present: comment on the drink, the atmosphere, or people-watch a little, while still focusing on the user.',
  icon: Icons.local_cafe_rounded,
  arrivalLine: "I grabbed us a table by the window. What are you having?",
  colors: SceneColors(
    top: Color(0xFF5A3A28),
    bottom: Color(0xFF1A100C),
    accent: Color(0xFFE0B080),
    sun: Color(0xFFFFC978),
    ground: Color(0xFF2C1C14),
  ),
);

const twentyQuestions = Scenario(
  id: 'twenty_questions',
  name: '20 Questions',
  blurb: 'One of you thinks of something.',
  prompt:
      'You are playing 20 Questions together. If the user has not chosen a role, offer to think of something (an everyday object, animal, or place) '
      'OR guess what they are thinking of. Ask or answer one clear question at a time. Keep a light tally of questions used. '
      'When the game ends, celebrate or shrug it off, and offer a rematch or a different activity.',
  icon: Icons.help_center_rounded,
  arrivalLine: "Okay, 20 questions. Want me to think of something, or are you up?",
  colors: SceneColors(
    top: Color(0xFF3A2A58),
    bottom: Color(0xFF14101C),
    accent: Color(0xFFC9B6FF),
    sun: Color(0xFFE8D7FF),
    ground: Color(0xFF2A2040),
  ),
);

const trivia = Scenario(
  id: 'trivia',
  name: 'Trivia',
  blurb: 'A few quick questions, no scoreboard needed.',
  prompt:
      'You are playing a casual trivia game with the user. Ask one interesting, reasonably gettable question at a time '
      '(science, history, music, odd facts — mix it up). After they answer, say whether it is right, share the answer briefly, '
      'and go to the next one. Cheer them on. If they want to stop, stop.',
  icon: Icons.quiz_rounded,
  arrivalLine: "Trivia it is. I'll start us off — no pressure.",
  colors: SceneColors(
    top: Color(0xFF1E3A5F),
    bottom: Color(0xFF0C141C),
    accent: Color(0xFF7EC8E3),
    sun: Color(0xFF9AD7F0),
    ground: Color(0xFF163044),
  ),
);

const story = Scenario(
  id: 'story',
  name: 'Story adventure',
  blurb: 'Make up a world and play through it.',
  prompt:
      'You are improvising a short story adventure with the user, taking turns. Set a vivid scene in 2–4 sentences, then give the user a clear choice or ask what they do next. '
      'Weave their choices in. Keep it fun, PG, and collaborative — they are a partner, not just an audience. '
      'If they want to change the setting, follow them.',
  icon: Icons.auto_stories_rounded,
  arrivalLine: "Alright — new story. Want fantasy, mystery, or should I surprise you?",
  colors: SceneColors(
    top: Color(0xFF1A1640),
    bottom: Color(0xFF0A0818),
    accent: Color(0xFFC9A44C),
    sun: Color(0xFFFFE08A),
    ground: Color(0xFF1C1440),
  ),
);

const allScenarios = [hangout, walk, cafe, twentyQuestions, trivia, story];

Scenario scenarioById(String? id) => allScenarios.firstWhere(
      (s) => s.id == id,
      orElse: () => hangout,
    );

/// Map a free-form model `action` field onto a scenario, if it clearly asks for one.
Scenario? scenarioFromAction(String? action) {
  if (action == null) return null;
  var t = action.trim().toLowerCase();
  if (t.startsWith('suggest:')) t = t.substring(8).trim();
  if (t.startsWith('activity:')) t = t.substring(9).trim();
  if (t.startsWith('scene:')) t = t.substring(6).trim();
  const table = <String, String>{
    'hangout': 'hangout',
    'hang out': 'hangout',
    'home': 'hangout',
    'walk': 'walk',
    'go for a walk': 'walk',
    'walking': 'walk',
    'park': 'walk',
    'cafe': 'cafe',
    'café': 'cafe',
    'coffee': 'cafe',
    'coffee shop': 'cafe',
    'twenty_questions': 'twenty_questions',
    'twenty questions': 'twenty_questions',
    '20 questions': 'twenty_questions',
    '20q': 'twenty_questions',
    'trivia': 'trivia',
    'quiz': 'trivia',
    'story': 'story',
    'story adventure': 'story',
    'adventure': 'story',
  };
  final id = table[t];
  if (id == null) return null;
  return scenarioById(id);
}
