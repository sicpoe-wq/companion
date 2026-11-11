import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/characters.dart';
import '../data/scenarios.dart';
import '../models/character.dart';
import '../models/emotion.dart';
import '../models/message.dart';
import '../models/scenario.dart';

/// One character's saved conversation: history, memory, scene and mood.
class Conversation {
  final String scenarioId;
  final String memorySummary;
  final List<ChatMessage> messages;
  final Emotion? lastEmotion;

  const Conversation({
    this.scenarioId = 'hangout',
    this.memorySummary = '',
    this.messages = const [],
    this.lastEmotion,
  });

  bool get isEmpty => messages.isEmpty && memorySummary.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'memorySummary': memorySummary,
    'messages': [for (final m in messages) m.toJson()],
    if (lastEmotion != null) 'lastEmotion': lastEmotion!.name,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    scenarioId: (json['scenarioId'] ?? 'hangout').toString(),
    memorySummary: (json['memorySummary'] ?? '').toString(),
    messages: _decodeMessages(json['messages']),
    lastEmotion: json['lastEmotion'] == null
        ? null
        : EmotionCodec.parse(json['lastEmotion'].toString()),
  );
}

List<ChatMessage> _decodeMessages(dynamic raw) => [
  for (final m in (raw as List? ?? const []))
    if (m is Map) ChatMessage.fromJson(m.cast<String, dynamic>()),
];

enum VoiceEngine { natural, device }

class AppState {
  final bool setupDone;
  final String characterId;
  final AvatarStyle style;
  final bool ttsEnabled;
  final VoiceEngine voiceEngine;

  /// Chosen natural-voice id per character id (falls back to the default).
  final Map<String, String> voiceByCharacter;

  // The ACTIVE character's conversation (kept flat so the rest of the app
  // stays simple). Other characters' chats live in [saved].
  final String scenarioId;
  final String memorySummary;
  final List<ChatMessage> messages;
  final Emotion? lastEmotion;

  /// Conversations of the characters that are not active right now.
  final Map<String, Conversation> saved;

  const AppState({
    required this.setupDone,
    required this.characterId,
    required this.style,
    required this.scenarioId,
    required this.ttsEnabled,
    required this.memorySummary,
    required this.messages,
    this.lastEmotion,
    this.voiceEngine = VoiceEngine.natural,
    this.voiceByCharacter = const {},
    this.saved = const {},
  });

  Character get character => characterById(characterId);
  Scenario get scenario => scenarioById(scenarioId);

  Conversation get activeConversation => Conversation(
    scenarioId: scenarioId,
    memorySummary: memorySummary,
    messages: messages,
    lastEmotion: lastEmotion,
  );

  /// Every character's conversation, including the active one.
  Map<String, Conversation> get allConversations => {
    ...saved,
    characterId: activeConversation,
  };

  bool hasHistory(String id) {
    final c = allConversations[id];
    if (c == null) return false;
    // A lone greeting doesn't count as history.
    return c.memorySummary.trim().isNotEmpty ||
        c.messages.any((m) => m.role == ChatRole.user);
  }

  AppState copyWith({
    bool? setupDone,
    String? characterId,
    AvatarStyle? style,
    String? scenarioId,
    bool? ttsEnabled,
    String? memorySummary,
    List<ChatMessage>? messages,
    Emotion? lastEmotion,
    VoiceEngine? voiceEngine,
    Map<String, String>? voiceByCharacter,
    Map<String, Conversation>? saved,
  }) {
    return AppState(
      setupDone: setupDone ?? this.setupDone,
      characterId: characterId ?? this.characterId,
      style: style ?? this.style,
      scenarioId: scenarioId ?? this.scenarioId,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      memorySummary: memorySummary ?? this.memorySummary,
      messages: messages ?? this.messages,
      lastEmotion: lastEmotion ?? this.lastEmotion,
      voiceEngine: voiceEngine ?? this.voiceEngine,
      voiceByCharacter: voiceByCharacter ?? this.voiceByCharacter,
      saved: saved ?? this.saved,
    );
  }

  /// Make [id] the active character, stashing the current conversation and
  /// restoring [id]'s saved one (or [fresh] if it has none).
  AppState activate(
    String id, {
    required Conversation Function() fresh,
    AvatarStyle? style,
  }) {
    final all = allConversations;
    final next = all[id];
    final conv = (next == null || next.messages.isEmpty) ? fresh() : next;
    final rest = Map<String, Conversation>.from(all)..remove(id);
    return AppState(
      setupDone: true,
      characterId: id,
      style: style ?? this.style,
      ttsEnabled: ttsEnabled,
      voiceEngine: voiceEngine,
      voiceByCharacter: voiceByCharacter,
      scenarioId: conv.scenarioId,
      memorySummary: conv.memorySummary,
      messages: conv.messages,
      lastEmotion: conv.lastEmotion,
      saved: rest,
    );
  }

  static AppState initial() => const AppState(
    setupDone: false,
    characterId: 'aria',
    style: AvatarStyle.cartoon,
    scenarioId: 'hangout',
    ttsEnabled: false,
    memorySummary: '',
    messages: [],
  );

  Map<String, dynamic> toJson() => {
    'version': 2,
    'setupDone': setupDone,
    'characterId': characterId,
    'style': style.name,
    'ttsEnabled': ttsEnabled,
    'voiceEngine': voiceEngine.name,
    'voiceByCharacter': voiceByCharacter,
    'conversations': {
      for (final e in allConversations.entries) e.key: e.value.toJson(),
    },
  };

  static AvatarStyle _style(dynamic v) => AvatarStyle.values.firstWhere(
    (s) => s.name == (v ?? 'cartoon').toString(),
    orElse: () => AvatarStyle.cartoon,
  );

  /// Reads both the v2 format and the flat v1.0/v1.1 format (migration).
  factory AppState.fromJson(Map<String, dynamic> json) {
    final id = (json['characterId'] ?? 'aria').toString();
    final Map<String, Conversation> convs = {};
    final rawConvs = json['conversations'];
    if (rawConvs is Map) {
      rawConvs.forEach((k, v) {
        if (v is Map)
          convs[k.toString()] = Conversation.fromJson(
            v.cast<String, dynamic>(),
          );
      });
    } else {
      // v1: a single flat conversation that belonged to the active character.
      convs[id] = Conversation(
        scenarioId: (json['scenarioId'] ?? 'hangout').toString(),
        memorySummary: (json['memorySummary'] ?? '').toString(),
        messages: _decodeMessages(json['messages']),
      );
    }
    final active = convs.remove(id) ?? const Conversation();
    final voices = <String, String>{};
    final rawVoices = json['voiceByCharacter'];
    if (rawVoices is Map) {
      rawVoices.forEach((k, v) => voices[k.toString()] = v.toString());
    }
    return AppState(
      setupDone: json['setupDone'] == true,
      characterId: id,
      style: _style(json['style']),
      ttsEnabled: json['ttsEnabled'] == true,
      voiceEngine: json['voiceEngine'] == 'device'
          ? VoiceEngine.device
          : VoiceEngine.natural,
      voiceByCharacter: voices,
      scenarioId: active.scenarioId,
      memorySummary: active.memorySummary,
      messages: active.messages,
      lastEmotion: active.lastEmotion,
      saved: convs,
    );
  }
}

class AppStore {
  static const _key = 'companion_state_v2';
  static const _legacyKey = 'companion_state_v1';
  final SharedPreferences prefs;

  AppStore(this.prefs);

  AppState load() {
    final raw = prefs.getString(_key) ?? prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return AppState.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map)
        return AppState.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return AppState.initial();
  }

  /// Saves in the v2 format. Once v2 is written the v1 copy is dropped, so
  /// erased chats can never come back through the migration path.
  Future<void> save(AppState state) async {
    final ok = await prefs.setString(_key, jsonEncode(state.toJson()));
    if (ok && prefs.containsKey(_legacyKey)) await prefs.remove(_legacyKey);
  }

  /// Keep recent turns verbatim; fold older ones into a compact running summary
  /// so the next prompt still fits. No extra network call (rate limits are tight).
  static const keepRecent = 16;
  static const maxSummaryChars = 1800;

  static (String, List<ChatMessage>) compact(
    String existingSummary,
    List<ChatMessage> messages, {
    int keep = keepRecent,
  }) {
    return _compactByIndex(existingSummary, messages, keep);
  }

  static (String, List<ChatMessage>) _compactByIndex(
    String existingSummary,
    List<ChatMessage> messages,
    int keep,
  ) {
    final visibleIdx = <int>[];
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role != ChatRole.event) visibleIdx.add(i);
    }
    if (visibleIdx.length <= keep) return (existingSummary, messages);
    final keepFrom = visibleIdx[visibleIdx.length - keep];
    final old = messages.sublist(0, keepFrom);
    final recent = messages.sublist(keepFrom);
    final buf = StringBuffer(existingSummary.trim());
    for (final m in old) {
      if (m.text.trim().isEmpty) continue;
      final who = switch (m.role) {
        ChatRole.user => 'User',
        ChatRole.assistant => 'Them',
        ChatRole.event => 'Scene',
      };
      final line = '$who: ${_clip(m.text, 180)}';
      if (buf.length + line.length + 1 > maxSummaryChars) {
        // Drop from the front of the summary to make room.
        var s = buf.toString();
        final cut = s.length + line.length + 1 - maxSummaryChars + 16;
        if (cut > 0 && cut < s.length) {
          s = '…${s.substring(cut)}';
        }
        buf
          ..clear()
          ..write(s);
      }
      if (buf.isNotEmpty) buf.writeln();
      buf.write(line);
    }
    var summary = buf.toString().trim();
    if (summary.length > maxSummaryChars) {
      summary = '…${summary.substring(summary.length - maxSummaryChars + 1)}';
    }
    return (summary, recent);
  }

  static String _clip(String s, int n) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= n) return t;
    return '${t.substring(0, n - 1)}…';
  }
}

/// Used by tests that want to assert compacting without going through prefs.
(String, List<ChatMessage>) compactMemory(
  String summary,
  List<ChatMessage> messages, {
  int keep = AppStore.keepRecent,
}) => AppStore.compact(summary, messages, keep: keep);
