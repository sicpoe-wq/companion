import 'dart:convert';

import 'emotion.dart';

/// A parsed model reply: spoken text plus the face/scene hints.
class ChatReply {
  final Emotion emotion;
  final String text;
  final String? action;
  final bool parsedJson;

  const ChatReply({
    required this.emotion,
    required this.text,
    this.action,
    this.parsedJson = false,
  });

  /// Parse a model payload that *should* be JSON but may be messy.
  ///
  /// Accepts raw JSON, fenced ```json blocks, leading/trailing chatter,
  /// trailing commas, and common key aliases (`message`, `reply`, `content`).
  static ChatReply parse(String raw) {
    final cleaned = _stripFences(raw).trim();
    final obj = _extractJsonMap(cleaned);
    if (obj != null) {
      final text = _firstNonEmpty([
        obj['text'],
        obj['message'],
        obj['reply'],
        obj['content'],
        obj['dialogue'],
        obj['line'],
      ]);
      final emotion = EmotionCodec.parse(
        (obj['emotion'] ?? obj['feeling'] ?? obj['mood'] ?? obj['expression'])
            ?.toString(),
        fallback: text.isEmpty ? Emotion.neutral : EmotionCodec.infer(text),
      );
      final action = _cleanAction(
        (obj['action'] ?? obj['activity'] ?? obj['scene'] ?? obj['suggest'])
            ?.toString(),
      );
      if (text.isNotEmpty) {
        return ChatReply(
          emotion: emotion,
          text: text,
          action: action,
          parsedJson: true,
        );
      }
    }
    final fallback = _stripFences(raw).trim();
    return ChatReply(
      emotion: EmotionCodec.infer(fallback),
      text: fallback.isEmpty ? "I'm here — say that again?" : fallback,
      parsedJson: false,
    );
  }

  static String? _cleanAction(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty || t.toLowerCase() == 'null' || t == '-') return null;
    return t;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return '';
  }

  static String _stripFences(String raw) {
    var s = raw.trim();
    // Drop a leading ```json ... ``` fence, or any triple-backtick wrapper.
    final fence = RegExp(r'^```(?:json|javascript|js)?\s*', caseSensitive: false);
    if (s.startsWith('```')) {
      s = s.replaceFirst(fence, '');
      final end = s.lastIndexOf('```');
      if (end >= 0) s = s.substring(0, end);
    }
    return s.trim();
  }

  static Map<String, dynamic>? _extractJsonMap(String raw) {
    final direct = _tryDecodeMap(raw);
    if (direct != null) return direct;

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = raw.substring(start, end + 1);
      final fromSlice = _tryDecodeMap(slice) ?? _tryDecodeMap(_repairJson(slice));
      if (fromSlice != null) return fromSlice;
    }
    return _tryDecodeMap(_repairJson(raw));
  }

  static Map<String, dynamic>? _tryDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  /// Mild repairs: trailing commas, single quotes around keys/values.
  static String _repairJson(String raw) {
    var s = raw.trim();
    s = s.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
    // Only rewrite obviously single-quoted JSON-like objects, not prose.
    if (s.contains("'") && !s.contains('"')) {
      s = s.replaceAll("'", '"');
    }
    return s;
  }
}
