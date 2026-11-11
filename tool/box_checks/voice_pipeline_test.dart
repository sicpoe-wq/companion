// Box-only check of the app's real voice pipeline (download + Dart extraction
// + sherpa-onnx synthesis in the worker isolate). Not part of `flutter test`.
// Run: flutter test tool/box_checks/voice_pipeline_test.dart
import 'dart:io';

import 'package:companion/services/neural_tts.dart';
import 'package:companion/services/voice_catalog.dart';
import 'package:companion/services/voice_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'download, unpack and speak with both default voices',
    () async {
      final root = Directory('/tmp/companion_voice_check');
      if (root.existsSync()) root.deleteSync(recursive: true);
      final store = VoiceStore(root);
      final lib = Directory(
        '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-1.13.8/linux/x64',
      ).path;
      final tts = NeuralTts(libPath: lib);
      final out = Directory('/workspace/companion_dist/voice_samples')
        ..createSync(recursive: true);
      final lines = {
        'aria':
            "Hey, it's me. I'm really glad you came back — want to tell me about your day?",
        'julian':
            "Hey. Good to see you again. Grab a seat — what's on your mind today?",
      };
      for (final ch in ['aria', 'julian']) {
        final v = voiceById(defaultVoiceFor(ch));
        final sw = Stopwatch()..start();
        double last = 0;
        await store.install(v, onProgress: (p, _) => last = p);
        print(
          '${v.id}: installed in ${sw.elapsedMilliseconds} ms (progress $last)',
        );
        expect(store.isInstalled(v), isTrue);
        final dir = store.dirFor(v).path;
        final parts = splitSentences(lines[ch]!);
        var i = 0;
        for (final p in parts) {
          sw.reset();
          final path = await tts.synth(
            model: '$dir/${v.modelFile}',
            tokens: '$dir/tokens.txt',
            dataDir: store.espeakDir.path,
            text: p,
            outPath: '${out.path}/app_${ch}_${v.id}_part$i.wav',
          );
          print('  "$p" -> $path in ${sw.elapsedMilliseconds} ms');
          expect(path, isNotNull);
          expect(File(path!).lengthSync(), greaterThan(20000));
          i++;
        }
      }
      final size = root
          .listSync(recursive: true)
          .whereType<File>()
          .fold<int>(0, (a, f) => a + f.lengthSync());
      print('voices on disk: ${(size / 1048576).toStringAsFixed(1)} MB');
      tts.dispose();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
