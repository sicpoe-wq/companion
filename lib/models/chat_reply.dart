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

  static const fallbackLine = "I'm here — say that again?";

  /// Parse a model payload that *should* be JSON but is frequently messy.
  ///
  /// Handles: clean JSON, ```json fences, chatter around the object, junk
  /// prefixes like `{"{"emotion":…}`, double-encoded JSON strings, escaped
  /// quotes, trailing commas, single quotes, truncated output, and key
  /// aliases. The returned [text] never contains JSON syntax.
  static ChatReply parse(String raw) {
    final stripped = _stripFences(raw).trim();

    // 1. Structured decode (direct, unwrapped, sliced, repaired).
    final obj = _extractJsonMap(stripped);
    if (obj != null) {
      final reply = _fromMap(obj);
      if (reply != null) return reply;
    }

    // 2. Regex extraction of the fields from anything JSON-ish.
    final rx = _regexExtract(stripped);
    if (rx != null) return rx;

    // 3. Plain text: scrub any JSON-looking residue.
    final plain = _scrub(stripped);
    return ChatReply(
      emotion: Emotion.neutral,
      text: plain.isEmpty ? fallbackLine : plain,
      parsedJson: false,
    );
  }

  static const _textKeys = [
    'text',
    'message',
    'reply',
    'content',
    'dialogue',
    'line',
    'response',
  ];
  static const _emotionKeys = ['emotion', 'feeling', 'mood', 'expression'];
  static const _actionKeys = ['action', 'activity', 'scene', 'suggest'];

  static ChatReply? _fromMap(Map<String, dynamic> obj, [int depth = 0]) {
    var text = _firstNonEmpty(_textKeys.map((k) => obj[k]).toList());
    // Nested / double-encoded: text itself is a JSON object string.
    if (depth < 3 && text.startsWith('{')) {
      final inner = _extractJsonMap(text);
      if (inner != null) {
        final r = _fromMap(inner, depth + 1);
        if (r != null) return r;
      }
      final rx = _regexExtract(text);
      if (rx != null) return rx;
    }
    // A nested map under a wrapper key, e.g. {"reply": {...}} or {"data": {...}}.
    if (text.isEmpty && depth < 3) {
      for (final v in obj.values) {
        if (v is Map) {
          final r = _fromMap(v.cast<String, dynamic>(), depth + 1);
          if (r != null) return r;
        }
      }
      return null;
    }
    text = _scrub(text);
    if (text.isEmpty) return null;
    final emotion = EmotionCodec.parse(
      _firstNonEmpty(_emotionKeys.map((k) => obj[k]).toList()),
      fallback: EmotionCodec.infer(text),
    );
    final action = _cleanAction(
      _firstNonEmpty(_actionKeys.map((k) => obj[k]).toList()),
    );
    return ChatReply(
      emotion: emotion,
      text: text,
      action: action,
      parsedJson: true,
    );
  }

  /// Pull `"key": "value"` pairs out of broken JSON with regexes.
  static ChatReply? _regexExtract(String raw) {
    // Undo one level of escaping if the payload was double-encoded.
    var s = raw;
    if (s.contains(r'\"')) s = s.replaceAll(r'\"', '"');

    String? field(List<String> keys, {bool allowTruncated = false}) {
      for (final k in keys) {
        final quoted = RegExp(
          '["\']?$k["\']?\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"',
          caseSensitive: false,
        ).firstMatch(s);
        if (quoted != null) return _unescape(quoted.group(1)!);
        final single = RegExp(
          '["\']?$k["\']?\\s*:\\s*\'((?:[^\'\\\\]|\\\\.)*)\'',
          caseSensitive: false,
        ).firstMatch(s);
        if (single != null) return _unescape(single.group(1)!);
        if (allowTruncated) {
          // Truncated string value: "text": "Hello there and the output stops
          final open = RegExp(
            '["\']?$k["\']?\\s*:\\s*"(.*)\$',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(s);
          if (open != null) return _unescape(open.group(1)!);
        }
        final bare = RegExp(
          '["\']?$k["\']?\\s*:\\s*([A-Za-z_]+)',
          caseSensitive: false,
        ).firstMatch(s);
        if (bare != null) return bare.group(1);
      }
      return null;
    }

    final textRaw = field(_textKeys, allowTruncated: true);
    if (textRaw == null) return null;
    final text = _scrub(textRaw);
    if (text.isEmpty) return null;
    final emo = field(_emotionKeys);
    return ChatReply(
      emotion: EmotionCodec.parse(emo, fallback: EmotionCodec.infer(text)),
      text: text,
      action: _cleanAction(field(_actionKeys)),
      parsedJson: true,
    );
  }

  static String _unescape(String v) {
    try {
      return jsonDecode('"$v"') as String;
    } catch (_) {
      return v
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
    }
  }

  /// Make sure nothing JSON-looking ever reaches a chat bubble.
  static String _scrub(String input) {
    var s = input.trim();
    // Drop "key": prefixes and JSON punctuation fragments.
    s = s.replaceAll(
      RegExp(
        r'''["']?(emotion|feeling|mood|expression|action|activity|scene|suggest|text|message|reply|content)["']?\s*:\s*("[^"]*"|null|true|false|[A-Za-z_]+)?\s*,?''',
        caseSensitive: false,
      ),
      ' ',
    );
    s = s.replaceAll(RegExp(r'[{}\[\]]'), ' ');
    s = s.replaceAll(RegExp(r'\\[nrt]'), ' ').replaceAll(r'\"', '"');
    // Strip stray quote/comma runs at the edges, e.g. `", "` or `"`.
    s = s.replaceAll(RegExp(r'''^[\s"',:]+|[\s"',:]+$'''), '');
    s = s.replaceAll(RegExp(r'\s*"\s*,\s*"\s*'), ' ');
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
    return s;
  }

  static String? _cleanAction(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty ||
        t.toLowerCase() == 'null' ||
        t == '-' ||
        t.toLowerCase() == 'none')
      return null;
    return t;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v == null || v is Map || v is List) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return '';
  }

  static String _stripFences(String raw) {
    var s = raw.trim();
    final m = RegExp(
      r'```(?:json|javascript|js)?\s*([\s\S]*?)(?:```|$)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null && m.group(1)!.contains('{')) return m.group(1)!.trim();
    return s.replaceAll('```', '').trim();
  }

  static Map<String, dynamic>? _extractJsonMap(String raw) {
    final candidates = <String>[raw];
    // Double-encoded: the whole payload is a JSON string containing JSON.
    final asString = _tryDecode(raw);
    if (asString is String) candidates.add(asString.trim());

    for (final c in List<String>.from(candidates)) {
      // Every `{` start (handles junk prefixes like `{"{"emotion"`), to the last `}`.
      final end = c.lastIndexOf('}');
      if (end < 0) continue;
      for (
        var i = c.indexOf('{');
        i >= 0 && i < end;
        i = c.indexOf('{', i + 1)
      ) {
        candidates.add(c.substring(i, end + 1));
      }
    }
    for (final c in candidates) {
      final m = _asMap(_tryDecode(c)) ?? _asMap(_tryDecode(_repairJson(c)));
      if (m != null) return m;
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic d) {
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.cast<String, dynamic>();
    if (d is String && d.trim().startsWith('{'))
      return _asMap(_tryDecode(d.trim()));
    return null;
  }

  static dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Mild repairs: trailing commas, single-quoted objects.
  static String _repairJson(String raw) {
    var s = raw.trim();
    s = s.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
    if (s.contains("'") && !s.contains('"')) s = s.replaceAll("'", '"');
    return s;
  }
}
