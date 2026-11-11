import 'dart:convert';

import 'package:companion/data/characters.dart';
import 'package:companion/models/character.dart';
import 'package:companion/models/emotion.dart';
import 'package:companion/models/message.dart';
import 'package:companion/services/ai_client.dart';
import 'package:companion/services/app_store.dart';
import 'package:companion/services/chat_controller.dart';
import 'package:companion/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

AiClient _offline() => AiClient(
  httpClient: MockClient((_) async => throw http.ClientException('offline')),
);

ChatMessage _u(String t) =>
    ChatMessage(role: ChatRole.user, text: t, at: DateTime(2026, 11, 11));
ChatMessage _a(String t, Emotion e) => ChatMessage(
  role: ChatRole.assistant,
  text: t,
  emotion: e,
  at: DateTime(2026, 11, 11),
);

Future<(SharedPreferences, ChatController)> _boot([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  final c = ChatController(
    ai: _offline(),
    store: store,
    tts: TtsService.noop(),
    state: store.load(),
  );
  return (prefs, c);
}

/// Simulates killing and relaunching the app: a brand-new controller reading
/// whatever was persisted.
ChatController _relaunch(SharedPreferences prefs) {
  final store = AppStore(prefs);
  return ChatController(
    ai: _offline(),
    store: store,
    tts: TtsService.noop(),
    state: store.load(),
  );
}

void main() {
  test('v1.0/v1.1 history migrates to its character without loss', () async {
    final v1 = {
      'setupDone': true,
      'characterId': 'julian',
      'style': 'realistic',
      'scenarioId': 'cafe',
      'ttsEnabled': true,
      'memorySummary': 'User: likes jazz',
      'messages': [
        _a('Hey.', Emotion.happy).toJson(),
        _u('Coffee?').toJson(),
        {
          'role': 'assistant',
          'text': '{"{"emotion":"happy","text":"Always.","action":null}',
          'emotion': 'excited',
          'at': DateTime(2026, 11, 11).toIso8601String(),
        },
      ],
    };
    final (prefs, c) = await _boot({'companion_state_v1': jsonEncode(v1)});
    expect(c.character.id, 'julian');
    expect(c.style, AvatarStyle.realistic);
    expect(c.scenario.id, 'cafe');
    expect(c.messages.length, 3);
    expect(c.messages.last.text, 'Always.');
    expect(c.state.memorySummary, 'User: likes jazz');
    expect(c.displayEmotion, Emotion.excited);
    expect(c.state.ttsEnabled, isTrue);

    // First save writes v2 and drops the v1 copy.
    await c.setStyle(AvatarStyle.cartoon);
    expect(prefs.getString('companion_state_v2'), isNotNull);
    expect(prefs.containsKey('companion_state_v1'), isFalse);
    final again = _relaunch(prefs);
    expect(again.messages.length, 3);
    expect(again.character.id, 'julian');
  });

  test(
    'each character keeps its own chat, scene and mood across switches and restarts',
    () async {
      final (prefs, c) = await _boot();
      await c.completeSetup(character: aria, style: AvatarStyle.realistic);
      c.state = c.state.copyWith(
        scenarioId: 'walk',
        messages: [
          ...c.messages,
          _u('Nice day'),
          _a('It really is!', Emotion.laughing),
        ],
      );
      c.displayEmotion = Emotion.laughing;
      await c.setStyle(AvatarStyle.realistic); // triggers a persist

      await c.switchCharacter(julian);
      expect(c.character.id, 'julian');
      expect(c.messages.length, 1, reason: 'Julian starts with his greeting');
      expect(c.scenario.id, 'hangout');
      c.state = c.state.copyWith(
        messages: [
          ...c.messages,
          _u('Hi Julian'),
          _a('Hey you.', Emotion.embarrassed),
        ],
      );
      c.displayEmotion = Emotion.embarrassed;
      await c.setStyle(AvatarStyle.cartoon);

      // Kill + relaunch while on Julian.
      var r = _relaunch(prefs);
      expect(r.character.id, 'julian');
      expect(r.messages.map((m) => m.text), contains('Hey you.'));
      expect(r.displayEmotion, Emotion.embarrassed);

      // Back to Aria: exactly where we left off.
      await r.switchCharacter(aria);
      expect(r.messages.map((m) => m.text).toList(), [
        aria.greeting,
        'Nice day',
        'It really is!',
      ]);
      expect(r.scenario.id, 'walk');
      expect(r.displayEmotion, Emotion.laughing);

      r = _relaunch(prefs);
      expect(r.character.id, 'aria');
      expect(r.messages.length, 3);
      await r.switchCharacter(julian);
      expect(r.messages.map((m) => m.text), contains('Hi Julian'));
    },
  );

  test('user message is saved before the reply arrives', () async {
    final (prefs, c) = await _boot();
    await c.completeSetup(character: aria, style: AvatarStyle.cartoon);
    // No network in tests: the reply fails, but the user line must persist.
    await c.send('Remember this');
    final r = _relaunch(prefs);
    expect(r.messages.map((m) => m.text), contains('Remember this'));
  });

  test('erase one chat and erase all', () async {
    final (prefs, c) = await _boot();
    await c.completeSetup(character: aria, style: AvatarStyle.cartoon);
    c.state = c.state.copyWith(messages: [...c.messages, _u('aria secret')]);
    await c.switchCharacter(julian);
    c.state = c.state.copyWith(messages: [...c.messages, _u('julian secret')]);
    await c.setStyle(AvatarStyle.realistic);
    expect(c.state.hasHistory('aria'), isTrue);
    expect(c.state.hasHistory('julian'), isTrue);

    await c.eraseChat('aria'); // not the active one
    expect(c.state.hasHistory('aria'), isFalse);
    expect(c.state.hasHistory('julian'), isTrue);
    expect(_relaunch(prefs).state.hasHistory('aria'), isFalse);

    c.state = c.state.copyWith(memorySummary: 'User: something');
    await c.eraseAllChats();
    expect(c.state.hasHistory('julian'), isFalse);
    expect(c.messages.single.text, julian.greeting);
    final r = _relaunch(prefs);
    expect(r.state.hasHistory('aria'), isFalse);
    expect(r.state.hasHistory('julian'), isFalse);
    expect(prefs.getString('companion_state_v2'), isNot(contains('secret')));
  });
}
