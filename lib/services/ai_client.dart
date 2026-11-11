import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Free, no-key text backends (Pollinations Classic).
///
/// Primary: POST https://text.pollinations.ai/openai  (OpenAI-compatible)
/// Fallback A: POST https://text.pollinations.ai/v1/chat/completions
/// Fallback B: POST https://text.pollinations.ai/      (plain-text body)
/// Fallback C: GET  https://text.pollinations.ai/{prompt}?system=&json=true
///
/// Anonymous text is limited to one in-flight request per IP, at least 30s
/// apart. Over the limit the API returns HTTP 402 with Retry-After.
class AiException implements Exception {
  final String message;
  final bool offline;
  final bool rateLimited;
  final Duration? retryAfter;
  final int? status;

  const AiException(
    this.message, {
    this.offline = false,
    this.rateLimited = false,
    this.retryAfter,
    this.status,
  });

  @override
  String toString() => message;
}

class ChatTurn {
  final String role; // system | user | assistant
  final String content;
  const ChatTurn(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiClient {
  static const primary = 'https://text.pollinations.ai/openai';
  static const fallbackOpenAi = 'https://text.pollinations.ai/v1/chat/completions';
  static const fallbackPlain = 'https://text.pollinations.ai/';
  static const getBase = 'https://text.pollinations.ai/';
  static const minGap = Duration(seconds: 30);
  static const defaultTimeout = Duration(seconds: 45);

  final http.Client _http;
  final Duration timeout;
  DateTime? _lastRequestAt;
  DateTime? _blockedUntil;

  AiClient({http.Client? httpClient, this.timeout = defaultTimeout})
      : _http = httpClient ?? http.Client();

  Duration cooldownRemaining({DateTime? now}) {
    final n = now ?? DateTime.now();
    var left = Duration.zero;
    if (_lastRequestAt != null) {
      final d = _lastRequestAt!.add(minGap).difference(n);
      if (d > left) left = d;
    }
    if (_blockedUntil != null) {
      final d = _blockedUntil!.difference(n);
      if (d > left) left = d;
    }
    return left < Duration.zero ? Duration.zero : left;
  }

  Future<String> complete(
    List<ChatTurn> messages, {
    bool jsonMode = true,
    int? seed,
  }) async {
    Object? lastError;
    final endpoints = [
      () => _postOpenAi(Uri.parse(primary), messages, jsonMode: jsonMode, seed: seed),
      () => _postOpenAi(Uri.parse(fallbackOpenAi), messages, jsonMode: jsonMode, seed: seed),
      () => _postPlain(messages, seed: seed),
      () => _getPrompt(messages, seed: seed),
    ];
    for (var i = 0; i < endpoints.length; i++) {
      try {
        final text = await endpoints[i]();
        if (text.trim().isNotEmpty) return text.trim();
        lastError = AiException('Empty reply from the chat service.');
      } on AiException catch (e) {
        lastError = e;
        // A hard offline / 4xx (except rate limit) shouldn't cycle forever.
        if (e.offline) rethrow;
        if (e.rateLimited && i == endpoints.length - 1) rethrow;
        if (e.rateLimited) continue;
        if (e.status != null && e.status! >= 400 && e.status! < 500 && e.status != 402) {
          // try the next fallback anyway for 404-style misses
          continue;
        }
      } on TimeoutException {
        lastError = const AiException(
          "They're taking too long to answer. Try again in a moment.",
        );
      } on SocketException {
        lastError = const AiException(
          "I can't reach the chat service. Check your connection and try again.",
          offline: true,
        );
        // Keep going — a later endpoint won't help if we're offline, so break.
        break;
      } on http.ClientException {
        lastError = const AiException(
          "I can't reach the chat service. Check your connection and try again.",
          offline: true,
        );
        break;
      } catch (e) {
        lastError = AiException('Something went wrong: $e');
      }
    }
    if (lastError is AiException) throw lastError;
    throw AiException(lastError?.toString() ?? 'The chat service is unavailable.');
  }

  Future<String> _postOpenAi(
    Uri uri,
    List<ChatTurn> messages, {
    required bool jsonMode,
    int? seed,
  }) async {
    final body = <String, dynamic>{
      'model': 'openai',
      'messages': [for (final m in messages) m.toJson()],
      'seed': seed ?? Random().nextInt(1 << 30),
    };
    // Some Pollinations builds accept this; unknown fields are ignored.
    if (jsonMode) body['response_format'] = {'type': 'json_object'};
    final res = await _send('POST', uri, json: body);
    return _parseOpenAi(res.body, res.statusCode);
  }

  Future<String> _postPlain(List<ChatTurn> messages, {int? seed}) async {
    final res = await _send(
      'POST',
      Uri.parse(fallbackPlain),
      json: {
        'messages': [for (final m in messages) m.toJson()],
        'seed': seed ?? Random().nextInt(1 << 30),
        'json': true,
      },
    );
    if (res.statusCode == 200) {
      // Plain endpoint may return raw text or a JSON wrapper.
      return _maybeUnwrap(res.body);
    }
    throw _statusException(res);
  }

  Future<String> _getPrompt(List<ChatTurn> messages, {int? seed}) async {
    final system = messages
        .where((m) => m.role == 'system')
        .map((m) => m.content)
        .join('\n');
    final rest = messages
        .where((m) => m.role != 'system')
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');
    final prompt = rest.isEmpty ? 'Hello' : rest;
    final uri = Uri.parse('$getBase${Uri.encodeComponent(prompt)}').replace(
      queryParameters: {
        'system': system,
        'json': 'true',
        'seed': '${seed ?? Random().nextInt(1 << 30)}',
      },
    );
    final res = await _send('GET', uri);
    if (res.statusCode == 200) return _maybeUnwrap(res.body);
    throw _statusException(res);
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? json,
  }) async {
    final wait = cooldownRemaining();
    if (wait > const Duration(seconds: 1)) {
      throw AiException(
        "Give them a few seconds to catch their breath.",
        rateLimited: true,
        retryAfter: wait,
      );
    }
    _lastRequestAt = DateTime.now();
    late http.Response res;
    try {
      if (method == 'GET') {
        res = await _http
            .get(uri, headers: const {'Accept': 'application/json, text/plain'})
            .timeout(timeout);
      } else {
        res = await _http
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json, text/plain',
              },
              body: jsonEncode(json ?? {}),
            )
            .timeout(timeout);
      }
    } on TimeoutException {
      rethrow;
    } finally {
      _lastRequestAt = DateTime.now();
    }
    if (res.statusCode == 402 || res.statusCode == 429 || res.statusCode == 503) {
      final ra = _retryAfter(res) ?? minGap;
      _blockedUntil = DateTime.now().add(ra);
      throw AiException(
        "They're catching their breath. Try again in ${ra.inSeconds}s.",
        rateLimited: true,
        retryAfter: ra,
        status: res.statusCode,
      );
    }
    return res;
  }

  String _parseOpenAi(String body, int status) {
    if (status != 200) {
      throw AiException(
        'The chat service returned HTTP $status.',
        status: status,
      );
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['choices'] is List && (decoded['choices'] as List).isNotEmpty) {
        final choice = decoded['choices'][0];
        if (choice is Map) {
          final msg = choice['message'];
          if (msg is Map && msg['content'] != null) {
            return msg['content'].toString();
          }
          if (choice['text'] != null) return choice['text'].toString();
        }
      }
      if (decoded is Map && decoded['content'] != null) {
        return decoded['content'].toString();
      }
    } catch (_) {
      // Not JSON — maybe the body already is the assistant text.
    }
    return _maybeUnwrap(body);
  }

  String _maybeUnwrap(String body) {
    final t = body.trim();
    if (t.isEmpty) return t;
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map) {
        for (final key in ['text', 'content', 'reply', 'message', 'response']) {
          if (decoded[key] is String && (decoded[key] as String).trim().isNotEmpty) {
            // If it looks like our emotion JSON already, keep the whole object.
            if (decoded.containsKey('emotion') && decoded.containsKey('text')) {
              return t;
            }
            // Avoid unwrapping OpenAI-style {message: {content}}
            if (decoded[key] is String && key != 'message') return decoded[key] as String;
          }
        }
        if (decoded['message'] is Map && (decoded['message'] as Map)['content'] != null) {
          return (decoded['message'] as Map)['content'].toString();
        }
        if (decoded.containsKey('emotion')) return t;
      }
    } catch (_) {}
    return t;
  }

  AiException _statusException(http.Response res) => AiException(
        'The chat service returned HTTP ${res.statusCode}.',
        status: res.statusCode,
      );

  Duration? _retryAfter(http.Response res) {
    final raw = res.headers['retry-after'];
    if (raw == null) return null;
    final secs = int.tryParse(raw.trim()) ?? double.tryParse(raw.trim())?.ceil();
    if (secs != null && secs >= 0) return Duration(seconds: secs);
    final when = DateTime.tryParse(raw);
    if (when != null) {
      final d = when.difference(DateTime.now());
      if (d > Duration.zero) return d;
    }
    return null;
  }
}
