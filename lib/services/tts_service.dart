import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../models/character.dart';
import 'app_store.dart' show VoiceEngine;
import 'neural_tts.dart';
import 'voice_catalog.dart';
import 'voice_store.dart';

/// Speaks replies. Prefers an on-device neural voice (sherpa-onnx + Piper);
/// falls back to the best built-in phone voice when the natural voice isn't
/// downloaded yet or anything fails.
class TtsService extends ChangeNotifier {
  final bool _disabled;
  TtsService() : _disabled = false;

  /// For tests and screenshots: never touches plugins.
  TtsService.noop() : _disabled = true;

  bool enabled = false;
  VoiceEngine engine = VoiceEngine.natural;

  FlutterTts? _device;
  bool _deviceReady = false;
  AudioPlayer? _player;
  NeuralTts? _neural;
  VoiceStore? _store;
  Directory? _tmp;

  String _voiceId = defaultVoiceFor('aria');
  Character? _character;
  int _generation = 0;

  /// Download progress per voice id (0..1) while installing.
  final Map<String, double> downloads = {};
  final Map<String, String> downloadErrors = {};

  bool get speaking => _speaking;
  bool _speaking = false;

  Future<void> init() async {
    if (_disabled) return;
    try {
      final support = await getApplicationSupportDirectory();
      _store = VoiceStore(Directory('${support.path}/voices'));
      _tmp = Directory('${(await getTemporaryDirectory()).path}/tts')
        ..createSync(recursive: true);
    } catch (_) {}
    try {
      final tts = FlutterTts();
      await tts.setVolume(1.0);
      await tts.awaitSpeakCompletion(true);
      _device = tts;
      _deviceReady = true;
    } catch (_) {
      _deviceReady = false;
    }
  }

  bool isInstalled(String voiceId) =>
      _store?.isInstalled(voiceById(voiceId)) ?? false;

  bool get naturalActive =>
      engine == VoiceEngine.natural && isInstalled(_voiceId);

  Future<bool> download(String voiceId) async {
    final store = _store;
    if (store == null || downloads.containsKey(voiceId)) return false;
    downloads[voiceId] = 0;
    downloadErrors.remove(voiceId);
    notifyListeners();
    try {
      await store.install(
        voiceById(voiceId),
        onProgress: (p, _) {
          downloads[voiceId] = p;
          notifyListeners();
        },
      );
      return true;
    } catch (e) {
      downloadErrors[voiceId] = e is SocketException || e is TimeoutException
          ? "Couldn't download — check your connection."
          : "Download failed. Try again.";
      return false;
    } finally {
      downloads.remove(voiceId);
      notifyListeners();
    }
  }

  Future<void> configure(Character character, {String? voiceId}) async {
    _character = character;
    _voiceId = voiceId ?? defaultVoiceFor(character.id);
    if (!_deviceReady) return;
    await _configureDevice(character);
  }

  /// Pick the most natural built-in voice: Google "network"/high-quality
  /// voices, matched to the character's gender where the name tells us.
  Future<void> _configureDevice(Character character) async {
    final tts = _device!;
    try {
      await tts.setLanguage('en-US');
      await tts.setPitch(character.feminineVoice ? 1.04 : 0.9);
      await tts.setSpeechRate(
        0.5,
      ); // Android "normal" pace; slower sounds robotic
      final voices = await tts.getVoices;
      if (voices is! List) return;
      const femaleCodes = ['sfg', 'iob', 'iog', 'tpc', 'tpf', 'cxx', 'female'];
      const maleCodes = ['iol', 'iom', 'tpd', 'gba', 'rjs', 'male'];
      Map? best;
      var bestScore = -1 << 20;
      for (final v in voices) {
        if (v is! Map) continue;
        final name = '${v['name'] ?? ''}'.toLowerCase();
        final locale = '${v['locale'] ?? ''}'.toLowerCase();
        if (!locale.startsWith('en') && !name.startsWith('en')) continue;
        var score = 0;
        if (locale.contains('us')) score += 2;
        if (locale.contains('gb') || locale.contains('uk')) score += 1;
        final quality = int.tryParse('${v['quality'] ?? ''}') ?? 0;
        if (quality >= 400) score += 3;
        if (name.contains('network')) score += 1; // neural, but needs internet
        if (name.contains('local')) score += 2; // works offline too
        final gender = '${v['gender'] ?? ''}'.toLowerCase();
        final want = character.feminineVoice ? femaleCodes : maleCodes;
        final avoid = character.feminineVoice ? maleCodes : femaleCodes;
        bool has(List<String> codes) =>
            codes.any(
              (c) => RegExp('(^|[^a-z])$c([^a-z]|\$)').hasMatch(name),
            ) ||
            codes.contains(gender);
        if (has(want)) {
          score += 6;
        } else if (has(avoid)) {
          score -= 6;
        }
        if (score > bestScore) {
          bestScore = score;
          best = v;
        }
      }
      if (best != null && best['name'] != null) {
        await tts.setVoice({
          'name': best['name'].toString(),
          'locale': (best['locale'] ?? 'en-US').toString(),
        });
      }
    } catch (_) {}
  }

  Future<void> speak(String text, [Character? character]) async {
    if (!enabled) return;
    await say(text, character);
  }

  /// Speak regardless of the on/off switch (used by "Test voice").
  Future<void> say(String text, [Character? character]) async {
    if (_disabled) return;
    final clean = text.replaceAll(RegExp(r'[*_#`~]'), '').trim();
    if (clean.isEmpty) return;
    await stop();
    final gen = ++_generation;
    _speaking = true;
    notifyListeners();
    try {
      if (engine == VoiceEngine.natural && isInstalled(_voiceId)) {
        final ok = await _speakNatural(clean, gen);
        if (ok || gen != _generation) return;
      }
      if (_deviceReady && gen == _generation) {
        await _device!.speak(clean);
      }
    } catch (_) {
    } finally {
      if (gen == _generation) {
        _speaking = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _speakNatural(String text, int gen) async {
    final store = _store, tmp = _tmp;
    if (store == null || tmp == null) return false;
    final v = voiceById(_voiceId);
    final dir = store.dirFor(v).path;
    _neural ??= NeuralTts();
    _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    final parts = splitSentences(text);
    final speed = (_character?.feminineVoice ?? true) ? 1.0 : 0.97;
    Future<String?> make(int i) => _neural!.synth(
      model: '$dir/${v.modelFile}',
      tokens: '$dir/tokens.txt',
      dataDir: store.espeakDir.path,
      text: parts[i],
      outPath: '${tmp.path}/u${gen}_$i.wav',
      speed: speed,
    );
    var next = make(0);
    for (var i = 0; i < parts.length; i++) {
      final path = await next;
      if (gen != _generation) return true;
      if (path == null) return i > 0; // failed before any audio: fall back
      if (i + 1 < parts.length) next = make(i + 1); // synth ahead while playing
      final done = _player!.onPlayerComplete.first;
      await _player!.play(DeviceFileSource(path));
      await done.timeout(const Duration(seconds: 60), onTimeout: () {});
      try {
        File(path).deleteSync();
      } catch (_) {}
      if (gen != _generation) return true;
    }
    return true;
  }

  Future<void> stop() async {
    _generation++;
    _speaking = false;
    try {
      await _player?.stop();
    } catch (_) {}
    if (_deviceReady) {
      try {
        await _device!.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _neural?.dispose();
    await _player?.dispose();
    super.dispose();
  }
}
