import 'package:flutter_tts/flutter_tts.dart';

import '../models/character.dart';

class TtsService {
  FlutterTts? _tts;
  bool _ready = false;
  bool enabled = false;
  final bool _disabled;

  TtsService() : _disabled = false;

  /// For tests and screenshots: never talks to the plugin.
  TtsService.noop() : _disabled = true;

  Future<void> init() async {
    if (_disabled) return;
    try {
      final tts = FlutterTts();
      await tts.setSpeechRate(0.46);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(false);
      _tts = tts;
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> configure(Character character) async {
    if (!_ready) return;
    final tts = _tts!;
    try {
      await tts.setPitch(character.feminineVoice ? 1.08 : 0.92);
      await tts.setSpeechRate(character.feminineVoice ? 0.48 : 0.45);
      final voices = await tts.getVoices;
      if (voices is List) {
        final want = character.feminineVoice ? 'female' : 'male';
        Map? match;
        for (final v in voices) {
          if (v is! Map) continue;
          final gender = '${v['gender'] ?? v['genderName'] ?? ''}'
              .toLowerCase();
          final locale = '${v['locale'] ?? v['localeId'] ?? ''}'.toLowerCase();
          final name = '${v['name'] ?? ''}'.toLowerCase();
          final en = locale.startsWith('en') || name.contains('en-');
          if (en && gender.contains(want)) {
            match = v;
            break;
          }
        }
        match ??= () {
          for (final v in voices) {
            if (v is Map) {
              final locale = '${v['locale'] ?? ''}'.toLowerCase();
              if (locale.startsWith('en')) return v;
            }
          }
          return null;
        }();
        if (match != null) {
          final name = match['name'];
          final locale = match['locale'];
          if (name != null) {
            await tts.setVoice({
              'name': name.toString(),
              if (locale != null) 'locale': locale.toString(),
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (!enabled || !_ready) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      await _tts!.stop();
      await _tts!.speak(clean);
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts!.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }
}
