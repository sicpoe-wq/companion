import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/scenarios.dart';
import '../models/character.dart';
import '../models/chat_reply.dart';
import '../models/emotion.dart';
import '../models/message.dart';
import '../models/scenario.dart';
import 'ai_client.dart';
import 'app_store.dart';
import 'tts_service.dart';
import 'voice_catalog.dart';

class ChatController extends ChangeNotifier {
  final AiClient ai;
  final AppStore store;
  final TtsService tts;

  AppState state;
  bool busy = false;
  bool talking = false;
  String? error;
  Duration? retryAfter;
  Emotion displayEmotion = Emotion.neutral;
  String? pendingSuggestion; // scenario id the character just suggested
  String typingBuffer = '';

  ChatController({
    required this.ai,
    required this.store,
    required this.tts,
    required this.state,
  }) {
    displayEmotion = state.lastEmotion ?? _lastEmotion() ?? Emotion.neutral;
    tts.enabled = state.ttsEnabled;
    tts.engine = state.voiceEngine;
  }

  Character get character => state.character;
  Scenario get scenario => state.scenario;
  AvatarStyle get style => state.style;
  List<ChatMessage> get messages => state.messages;

  Emotion? _lastEmotion() {
    for (final m in state.messages.reversed) {
      if (m.role == ChatRole.assistant && m.emotion != null) return m.emotion;
    }
    return null;
  }

  Future<void> _persist() async {
    state = state.copyWith(lastEmotion: displayEmotion);
    await store.save(state);
  }

  Conversation _fresh(Character c) => Conversation(
    scenarioId: 'hangout',
    messages: [
      ChatMessage(
        role: ChatRole.assistant,
        text: c.greeting,
        emotion: Emotion.happy,
        at: DateTime.now(),
      ),
    ],
    lastEmotion: Emotion.happy,
  );

  void _resetTransient() {
    error = null;
    retryAfter = null;
    pendingSuggestion = null;
    typingBuffer = '';
    talking = false;
  }

  /// Make [character] active, resuming its own saved chat if it has one.
  Future<void> _activate(Character character, {AvatarStyle? style}) async {
    await tts.stop();
    // Store the current mood with the outgoing conversation first.
    state = state.copyWith(lastEmotion: displayEmotion);
    state = state.activate(
      character.id,
      fresh: () => _fresh(character),
      style: style,
    );
    displayEmotion = state.lastEmotion ?? _lastEmotion() ?? Emotion.happy;
    _resetTransient();
    await tts.configure(character, voiceId: voiceIdFor(character.id));
    await _persist();
    notifyListeners();
  }

  String voiceIdFor(String characterId) =>
      state.voiceByCharacter[characterId] ?? defaultVoiceFor(characterId);

  Future<void> setVoiceEngine(VoiceEngine e) async {
    state = state.copyWith(voiceEngine: e);
    tts.engine = e;
    await tts.stop();
    await tts.configure(character, voiceId: voiceIdFor(character.id));
    await _persist();
    notifyListeners();
  }

  Future<void> setVoice(String characterId, String voiceId) async {
    state = state.copyWith(
      voiceByCharacter: {...state.voiceByCharacter, characterId: voiceId},
    );
    if (characterId == character.id) {
      await tts.stop();
      await tts.configure(character, voiceId: voiceId);
    }
    await _persist();
    notifyListeners();
  }

  static const _samples = {
    'aria':
        "Hey, it's me. I'm really glad you came back — want to tell me about your day?",
    'julian':
        "Hey. Good to see you again. Grab a seat — what's on your mind today?",
  };

  Future<void> testVoice() async {
    await tts.configure(character, voiceId: voiceIdFor(character.id));
    await tts.say(_samples[character.id] ?? character.greeting, character);
  }

  Future<bool> downloadVoice(String voiceId) async {
    final ok = await tts.download(voiceId);
    if (ok) await tts.configure(character, voiceId: voiceIdFor(character.id));
    notifyListeners();
    return ok;
  }

  /// Erase one character's chat and memory (with the active one reset to a
  /// fresh greeting).
  Future<void> eraseChat(String characterId) async {
    if (characterId == state.characterId) {
      await tts.stop();
      final f = _fresh(character);
      state = state.copyWith(
        scenarioId: f.scenarioId,
        memorySummary: '',
        messages: f.messages,
        lastEmotion: Emotion.happy,
      );
      displayEmotion = Emotion.happy;
      _resetTransient();
    } else {
      state = state.copyWith(saved: Map.of(state.saved)..remove(characterId));
    }
    await _persist();
    notifyListeners();
  }

  Future<void> eraseAllChats() async {
    state = state.copyWith(saved: const {});
    await eraseChat(state.characterId);
  }

  Future<void> completeSetup({
    required Character character,
    required AvatarStyle style,
  }) async {
    await _activate(character, style: style);
  }

  Future<void> setStyle(AvatarStyle style) async {
    if (state.style == style) return;
    state = state.copyWith(style: style);
    await _persist();
    notifyListeners();
  }

  Future<void> setTts(bool on) async {
    state = state.copyWith(ttsEnabled: on);
    tts.enabled = on;
    if (!on) await tts.stop();
    await _persist();
    notifyListeners();
  }

  Future<void> switchCharacter(
    Character character, {
    AvatarStyle? style,
  }) async {
    await _activate(character, style: style);
  }

  Future<void> newConversation() => eraseChat(state.characterId);

  Future<void> setScenario(Scenario scenario, {bool announce = true}) async {
    if (state.scenarioId == scenario.id && announce == false) return;
    pendingSuggestion = null;
    state = state.copyWith(scenarioId: scenario.id);
    if (announce) {
      final line = ChatMessage(
        role: ChatRole.event,
        text: 'You start: ${scenario.name}.',
        at: DateTime.now(),
      );
      final arrival = ChatMessage(
        role: ChatRole.assistant,
        text: scenario.arrivalLine,
        emotion: Emotion.happy,
        at: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, line, arrival]);
      displayEmotion = Emotion.happy;
      if (state.ttsEnabled)
        unawaited(tts.speak(scenario.arrivalLine, character));
    }
    await _persist();
    notifyListeners();
  }

  Future<void> acceptSuggestion() async {
    final id = pendingSuggestion;
    if (id == null) return;
    pendingSuggestion = null;
    await setScenario(scenarioById(id));
  }

  Future<void> dismissSuggestion() async {
    pendingSuggestion = null;
    notifyListeners();
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || busy) return;
    error = null;
    retryAfter = null;
    final user = ChatMessage(
      role: ChatRole.user,
      text: text,
      at: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, user]);
    // Save right away so the message survives the app being closed mid-reply.
    unawaited(_persist());
    busy = true;
    talking = false;
    typingBuffer = '';
    displayEmotion = Emotion.thoughtful;
    notifyListeners();
    await _persist();
    await _complete();
  }

  Future<void> retry() async {
    if (busy) return;
    // Retry the last user message if the last turn failed (no assistant after it).
    if (state.messages.isEmpty) return;
    final lastUser = state.messages.lastWhere(
      (m) => m.role == ChatRole.user,
      orElse: () => state.messages.last,
    );
    if (lastUser.role != ChatRole.user) return;
    error = null;
    busy = true;
    displayEmotion = Emotion.thoughtful;
    notifyListeners();
    await _complete();
  }

  Future<void> _complete() async {
    final prompt = _buildMessages();
    try {
      final raw = await ai.complete(prompt, jsonMode: true);
      final reply = ChatReply.parse(raw);
      await _reveal(reply);
    } on AiException catch (e) {
      error = e.message;
      retryAfter = e.retryAfter;
      displayEmotion = Emotion.worried;
      busy = false;
      talking = false;
      notifyListeners();
      if (e.rateLimited &&
          e.retryAfter != null &&
          e.retryAfter! <= const Duration(seconds: 8)) {
        // Very short wait: auto-retry once.
        await Future<void>.delayed(e.retryAfter!);
        if (!busy && error != null) {
          error = null;
          await retry();
        }
      }
    } catch (e) {
      error = "Something went wrong. Please try again.";
      displayEmotion = Emotion.worried;
      busy = false;
      talking = false;
      notifyListeners();
    }
  }

  Future<void> _reveal(ChatReply reply) async {
    displayEmotion = reply.emotion;
    talking = true;
    typingBuffer = '';
    notifyListeners();

    final suggested = scenarioFromAction(reply.action);
    if (suggested != null && suggested.id != state.scenarioId) {
      pendingSuggestion = suggested.id;
    }

    // Type the line out so the mouth can move with it.
    final full = reply.text;
    const step = Duration(milliseconds: 18);
    for (var i = 1; i <= full.length; i++) {
      typingBuffer = full.substring(0, i);
      if (i == 1 || i == full.length || i % 2 == 0) {
        notifyListeners();
      }
      await Future<void>.delayed(step);
    }

    final msg = ChatMessage(
      role: ChatRole.assistant,
      text: full,
      emotion: reply.emotion,
      action: reply.action,
      at: DateTime.now(),
    );
    var next = [...state.messages, msg];
    var summary = state.memorySummary;
    final compacted = AppStore.compact(summary, next);
    state = state.copyWith(memorySummary: compacted.$1, messages: compacted.$2);
    typingBuffer = '';
    talking = false;
    busy = false;
    await _persist();
    notifyListeners();
    if (state.ttsEnabled) unawaited(tts.speak(full, character));
  }

  List<ChatTurn> _buildMessages() {
    final c = character;
    final s = scenario;
    final system = StringBuffer()
      ..writeln(c.personality)
      ..writeln()
      ..writeln('The current activity/scene is "${s.name}": ${s.prompt}')
      ..writeln()
      ..writeln(
        'Output format (strict): reply with exactly ONE JSON object and nothing else — '
        'no markdown, no code fences, no text before or after, no nested or escaped JSON. '
        'Use double quotes. The "text" value is plain spoken words only (1-3 short sentences), '
        'never containing JSON, braces or field names. Example:',
      )
      ..writeln(
        '{"emotion":"<one of: neutral,happy,laughing,sad,angry,surprised,thoughtful,embarrassed,excited,worried>","text":"<your spoken reply>","action":null}',
      )
      ..writeln(
        'Pick the emotion you are actually feeling as you say the line — this drives your face.',
      )
      ..writeln(
        'If you want to suggest doing something together, set action to one of: '
        'hangout, walk, cafe, twenty_questions, trivia, story. '
        'Otherwise set action to a short stage direction or null.',
      );
    if (state.memorySummary.trim().isNotEmpty) {
      system
        ..writeln()
        ..writeln('Earlier in this conversation (summary):')
        ..writeln(state.memorySummary.trim());
    }
    final turns = <ChatTurn>[ChatTurn('system', system.toString())];
    for (final m in state.messages) {
      switch (m.role) {
        case ChatRole.user:
          turns.add(ChatTurn('user', m.text));
        case ChatRole.assistant:
          // Re-encode as the exact format we ask for, so the model keeps it.
          turns.add(
            ChatTurn(
              'assistant',
              jsonEncode({
                'emotion': (m.emotion ?? Emotion.neutral).name,
                'text': m.text,
                'action': m.action,
              }),
            ),
          );
        case ChatRole.event:
          turns.add(ChatTurn('user', '[Scene change: ${m.text}]'));
      }
    }
    return turns;
  }
}
