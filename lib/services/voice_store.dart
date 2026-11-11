import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import 'voice_catalog.dart';

/// Downloads and unpacks natural voices into [root]:
///   root/espeak-ng-data/...   (shared by every voice, extracted once)
///   root/<voice id>/<id>.onnx, tokens.txt
class VoiceStore {
  final Directory root;
  VoiceStore(this.root);

  Directory dirFor(NaturalVoice v) => Directory('${root.path}/${v.id}');
  Directory get espeakDir => Directory('${root.path}/espeak-ng-data');

  bool isInstalled(NaturalVoice v) =>
      File('${dirFor(v).path}/${v.modelFile}').existsSync() &&
      File('${dirFor(v).path}/tokens.txt').existsSync() &&
      File('${espeakDir.path}/phontab').existsSync();

  /// Download with progress (0..1), then extract in a background isolate.
  Future<void> install(
    NaturalVoice v, {
    void Function(double progress, String stage)? onProgress,
    http.Client? client,
  }) async {
    if (isInstalled(v)) return;
    root.createSync(recursive: true);
    final c = client ?? http.Client();
    final tmp = File('${root.path}/${v.archiveName}.tar.bz2.part');
    try {
      final req = http.Request('GET', v.url);
      final res = await c.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('Download failed (${res.statusCode})');
      }
      final total = res.contentLength ?? v.approxMb * 1024 * 1024;
      var got = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 45),
      )) {
        sink.add(chunk);
        got += chunk.length;
        onProgress?.call((got / total).clamp(0.0, 1.0) * 0.85, 'Downloading');
      }
      await sink.close();
      onProgress?.call(0.88, 'Unpacking');
      await Isolate.run(() => _extract(tmp.path, root.path, v.id, v.modelFile));
      onProgress?.call(1.0, 'Ready');
    } finally {
      if (client == null) c.close();
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }

  Future<void> remove(NaturalVoice v) async {
    final d = dirFor(v);
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
}

/// Runs in a background isolate.
void _extract(
  String archivePath,
  String rootPath,
  String id,
  String modelFile,
) {
  final bytes = File(archivePath).readAsBytesSync();
  final tarBytes = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tarBytes);
  final voiceDir = Directory('$rootPath/$id')..createSync(recursive: true);
  final espeakDone = File('$rootPath/espeak-ng-data/phontab').existsSync();
  for (final f in archive.files) {
    if (!f.isFile) continue;
    // Strip the top-level folder: vits-piper-.../<rest>
    final parts = f.name.split('/');
    if (parts.length < 2) continue;
    final rel = parts.sublist(1).join('/');
    String? dest;
    if (rel.startsWith('espeak-ng-data/')) {
      if (espeakDone) continue;
      dest = '$rootPath/$rel';
    } else if (rel == modelFile || rel == 'tokens.txt' || rel == 'MODEL_CARD') {
      dest = '${voiceDir.path}/$rel';
    }
    if (dest == null) continue;
    final out = File(dest)..parent.createSync(recursive: true);
    out.writeAsBytesSync(f.content as List<int>);
  }
}
