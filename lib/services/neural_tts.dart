import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

/// Runs sherpa-onnx (Piper VITS) synthesis in a long-lived background isolate
/// so the UI never stalls. Each request writes a WAV file and returns its path.
class NeuralTts {
  final String? libPath; // only for desktop tests; null on Android
  NeuralTts({this.libPath});

  Isolate? _iso;
  SendPort? _send;
  final _pending = <int, Completer<String?>>{};
  int _seq = 0;
  ReceivePort? _rx;

  Future<void> _ensure() async {
    if (_send != null) return;
    final rx = ReceivePort();
    _rx = rx;
    final ready = Completer<SendPort>();
    rx.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is List && msg.length == 2) {
        _pending.remove(msg[0] as int)?.complete(msg[1] as String?);
      }
    });
    _iso = await Isolate.spawn(_worker, [rx.sendPort, libPath]);
    _send = await ready.future;
  }

  /// Synthesize [text] with the model in [modelDir]. Returns a WAV path, or
  /// null on failure.
  Future<String?> synth({
    required String model,
    required String tokens,
    required String dataDir,
    required String text,
    required String outPath,
    double speed = 1.0,
  }) async {
    await _ensure();
    final id = ++_seq;
    final c = Completer<String?>();
    _pending[id] = c;
    _send!.send([id, model, tokens, dataDir, text, outPath, speed]);
    return c.future.timeout(const Duration(seconds: 40), onTimeout: () => null);
  }

  void dispose() {
    _iso?.kill(priority: Isolate.immediate);
    _rx?.close();
    _iso = null;
    _send = null;
  }
}

void _worker(List args) {
  final reply = args[0] as SendPort;
  final libPath = args[1] as String?;
  final rx = ReceivePort();
  reply.send(rx.sendPort);
  var inited = false;
  so.OfflineTts? tts;
  String? loadedModel;
  rx.listen((msg) {
    final m = msg as List;
    final id = m[0] as int;
    try {
      if (!inited) {
        so.initBindings(libPath);
        inited = true;
      }
      final model = m[1] as String;
      if (tts == null || loadedModel != model) {
        tts?.free();
        tts = so.OfflineTts(
          so.OfflineTtsConfig(
            model: so.OfflineTtsModelConfig(
              vits: so.OfflineTtsVitsModelConfig(
                model: model,
                tokens: m[2] as String,
                dataDir: m[3] as String,
                // Slightly more expressive prosody than the defaults.
                noiseScale: 0.7,
                noiseScaleW: 0.85,
              ),
              numThreads: Platform.numberOfProcessors >= 6 ? 4 : 2,
              debug: false,
            ),
          ),
        );
        loadedModel = model;
      }
      final audio = tts!.generate(
        text: m[4] as String,
        sid: 0,
        speed: m[6] as double,
      );
      if (audio.samples.isEmpty) {
        reply.send([id, null]);
        return;
      }
      so.writeWave(
        filename: m[5] as String,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      reply.send([id, m[5] as String]);
    } catch (_) {
      reply.send([id, null]);
    }
  });
}
