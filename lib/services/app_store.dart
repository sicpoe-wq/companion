import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/characters.dart';
import '../data/scenarios.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../models/scenario.dart';

class AppState {
  final bool setupDone;
  final String characterId;
  final AvatarStyle style;
  final String scenarioId;
  final bool ttsEnabled;
  final String memorySummary;
  final List<ChatMessage> messages;

  const AppState({
    required this.setupDone,
    required this.characterId,
    required this.style,
    required this.scenarioId,
    required this.ttsEnabled,
    required this.memorySummary,
    required this.messages,
  });

  Character get character => characterById(characterId);
  Scenario get scenario => scenarioById(scenarioId);

  AppState copyWith({
    bool? setupDone,
    String? characterId,
    AvatarStyle? style,
    String? scenarioId,
    bool? ttsEnabled,
    String? memorySummary,
    List<ChatMessage>? messages,
  }) {
    return AppState(
      setupDone: setupDone ?? this.setupDone,
      characterId: characterId ?? this.characterId,
      style: style ?? this.style,
      scenarioId: scenarioId ?? this.scenarioId,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      memorySummary: memorySummary ?? this.memorySummary,
      messages: messages ?? this.messages,
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
    'setupDone': setupDone,
    'characterId': characterId,
    'style': style.name,
    'scenarioId': scenarioId,
    'ttsEnabled': ttsEnabled,
    'memorySummary': memorySummary,
    'messages': [for (final m in messages) m.toJson()],
  };

  factory AppState.fromJson(Map<String, dynamic> json) {
    final styleName = (json['style'] ?? 'cartoon').toString();
    return AppState(
      setupDone: json['setupDone'] == true,
      characterId: (json['characterId'] ?? 'aria').toString(),
      style: AvatarStyle.values.firstWhere(
        (s) => s.name == styleName,
        orElse: () => AvatarStyle.cartoon,
      ),
      scenarioId: (json['scenarioId'] ?? 'hangout').toString(),
      ttsEnabled: json['ttsEnabled'] == true,
      memorySummary: (json['memorySummary'] ?? '').toString(),
      messages: [
        for (final m in (json['messages'] as List? ?? const []))
          if (m is Map<String, dynamic>)
            ChatMessage.fromJson(m)
          else if (m is Map)
            ChatMessage.fromJson(m.cast<String, dynamic>()),
      ],
    );
  }
}

class AppStore {
  static const _key = 'companion_state_v1';
  final SharedPreferences prefs;

  AppStore(this.prefs);

  AppState load() {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AppState.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppState.fromJson(decoded);
      if (decoded is Map) {
        return AppState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return AppState.initial();
  }

  Future<void> save(AppState state) async {
    await prefs.setString(_key, jsonEncode(state.toJson()));
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
